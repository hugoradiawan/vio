import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grpc/grpc.dart';
import 'package:vio_core/vio_core.dart';

import '../../../core/core.dart';
import '../../../gen/vio/v1/branch.pb.dart' as branch_pb;
import '../../../gen/vio/v1/branch.pbgrpc.dart';
import '../../../gen/vio/v1/commit.pb.dart' as commit_pb;
import '../../../gen/vio/v1/commit.pbgrpc.dart';
import '../../../gen/vio/v1/common.pb.dart' as common_pb;
import '../../../gen/vio/v1/pullrequest.pb.dart' as pr_pb;
import '../../../gen/vio/v1/pullrequest.pbgrpc.dart' hide PullRequestStatus;

part 'version_control_event.dart';
part 'version_control_state.dart';

/// Polling interval for checking updates (30 seconds as per user preference)
const _pollingInterval = Duration(seconds: 30);

/// Manages version control state including:
/// - Branches (list, switch, create, delete)
/// - Commits (list, create, checkout, revert)
/// - Pull Requests (list, create, merge, close, resolve conflicts)
class VersionControlBloc
    extends Bloc<VersionControlEvent, VersionControlState> {
  VersionControlBloc() : super(const VersionControlState()) {
    on<VersionControlInitialized>(_onInitialized);
    on<VersionControlPollingStarted>(_onPollingStarted);
    on<VersionControlPollingStopped>(_onPollingStopped);
    on<BranchesRefreshRequested>(_onBranchesRefresh);
    on<BranchSwitchRequested>(_onBranchSwitch);
    on<BranchSwitchConfirmed>(_onBranchSwitchConfirmed);
    on<BranchSwitchCanceled>(_onBranchSwitchCanceled);
    on<BranchCreateRequested>(_onBranchCreate);
    on<BranchDeleteRequested>(_onBranchDelete);
    on<BranchDeleteConfirmed>(_onBranchDeleteConfirmed);
    on<BranchDeleteCanceled>(_onBranchDeleteCanceled);
    on<CommitsRefreshRequested>(_onCommitsRefresh);
    on<CommitCreateRequested>(_onCommitCreate);
    on<CommitCheckoutRequested>(_onCommitCheckout);
    on<CommitRevertRequested>(_onCommitRevert);
    on<PullRequestsRefreshRequested>(_onPullRequestsRefresh);
    on<PullRequestCreateRequested>(_onPullRequestCreate);
    on<PullRequestSelected>(_onPullRequestSelected);
    on<PullRequestMergeRequested>(_onPullRequestMerge);
    on<PullRequestCloseRequested>(_onPullRequestClose);
    on<ConflictsResolveRequested>(_onConflictsResolve);
    on<BranchCompareRequested>(_onBranchCompare);
    on<ShapesStagedForCommit>(_onShapesStaged);
    on<StagedShapesCleared>(_onStagedCleared);
    on<CanvasShapesChanged>(_onCanvasShapesChanged);
    on<BaseShapesLoaded>(_onBaseShapesLoaded);
    on<ShapeChangeDiscarded>(_onShapeChangeDiscarded);
    on<AllChangesDiscarded>(_onAllChangesDiscarded);
    on<CommitAndSwitchRequested>(_onCommitAndSwitch);
    on<BranchUpdateRequested>(_onBranchUpdate);
  }

  Timer? _pollingTimer;

  BranchServiceClient get _branchClient =>
      ServiceLocator.instance.branchService;
  CommitServiceClient get _commitClient =>
      ServiceLocator.instance.commitService;
  PullRequestServiceClient get _prClient =>
      ServiceLocator.instance.pullRequestService;
  PreferencesService get _prefsService =>
      ServiceLocator.instance.preferencesService;

  /// Convert proto Timestamp to DateTime
  DateTime _timestampToDateTime(common_pb.Timestamp ts) {
    return DateTime.fromMillisecondsSinceEpoch(ts.millis.toInt());
  }

  /// Convert proto Timestamp to nullable DateTime
  DateTime? _timestampToDateTimeOrNull(common_pb.Timestamp? ts) {
    if (ts == null || !ts.hasMillis()) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts.millis.toInt());
  }

  Future<void> _onInitialized(
    VersionControlInitialized event,
    Emitter<VersionControlState> emit,
  ) async {
    emit(
      state.copyWith(
        status: VersionControlStatus.loading,
        projectId: event.projectId,
        userId: event.userId,
        clearError: true,
      ),
    );

    try {
      // Load branches
      final branchesResponse = await _branchClient.listBranches(
        branch_pb.ListBranchesRequest()..projectId = event.projectId,
      );

      final branches = branchesResponse.branches
          .map(
            (b) => BranchDto(
              id: b.id,
              name: b.name,
              projectId: b.projectId,
              description: b.description.isEmpty ? null : b.description,
              headCommitId: b.headCommitId.isEmpty ? null : b.headCommitId,
              isDefault: b.isDefault,
              isProtected: b.isProtected,
              createdById: b.createdById,
              createdAt: _timestampToDateTimeOrNull(b.createdAt),
              updatedAt: _timestampToDateTimeOrNull(b.updatedAt),
            ),
          )
          .toList();

      // Try to restore last selected branch, fallback to default branch
      final lastBranchId = _prefsService.getLastBranchId(event.projectId);
      BranchDto? initialBranch;

      if (lastBranchId != null) {
        // Try to find the last selected branch
        initialBranch = branches.cast<BranchDto?>().firstWhere(
              (b) => b?.id == lastBranchId,
              orElse: () => null,
            );
      }

      // Fallback to default branch if last branch not found
      initialBranch ??= branches.firstWhere(
        (b) => b.isDefault,
        orElse: () => branches.first,
      );

      VioLogger.info(
        'VersionControlBloc: Initializing with branch "${initialBranch.name}" '
        '(restored: ${lastBranchId != null && lastBranchId == initialBranch.id})',
      );

      // Load commits for the initial branch
      final commitsResponse = await _commitClient.listCommits(
        commit_pb.ListCommitsRequest()
          ..projectId = event.projectId
          ..branchId = initialBranch.id,
      );

      final commits = commitsResponse.commits
          .map(
            (c) => CommitDto(
              id: c.id,
              projectId: c.projectId,
              branchId: c.branchId,
              message: c.message,
              authorId: c.authorId,
              snapshotId: c.snapshotId,
              createdAt: _timestampToDateTime(c.createdAt),
              parentId: c.parentId.isEmpty ? null : c.parentId,
            ),
          )
          .toList();

      // Load base shapes from HEAD commit's snapshot (if any commits exist)
      final Map<String, Shape> baseShapes = {};
      if (initialBranch.headCommitId != null &&
          initialBranch.headCommitId!.isNotEmpty) {
        try {
          final commitResponse = await _commitClient.getCommit(
            commit_pb.GetCommitRequest()
              ..projectId = event.projectId
              ..commitId = initialBranch.headCommitId!,
          );

          if (commitResponse.hasSnapshot()) {
            final snapshotData = commitResponse.snapshot;
            if (snapshotData.data.isNotEmpty) {
              final jsonData = jsonDecode(utf8.decode(snapshotData.data))
                  as Map<String, dynamic>;
              final shapesJson = jsonData['shapes'] as List<dynamic>? ?? [];
              for (final shapeJson in shapesJson) {
                try {
                  final shape =
                      ShapeFactory.fromJson(shapeJson as Map<String, dynamic>);
                  baseShapes[shape.id] = shape;
                } catch (e) {
                  VioLogger.warning(
                    'VersionControlBloc: Failed to parse shape from snapshot: $e',
                  );
                }
              }
              VioLogger.info(
                'VersionControlBloc: Loaded ${baseShapes.length} base shapes from HEAD commit',
              );
            }
          }
        } catch (e) {
          VioLogger.warning(
            'VersionControlBloc: Failed to load HEAD commit snapshot: $e',
          );
        }
      }

      // CRITICAL: Initialize the canvas repository with project/branch context
      // This loads the working copy from the server (shapes table) which
      // includes uncommitted changes that were synced before the last restart.
      final repository = ServiceLocator.instance.canvasRepository;
      await repository.initialize(
        projectId: event.projectId,
        branchId: initialBranch.id,
      );

      // Build currentShapes from the working copy (repository state)
      // This preserves uncommitted changes across app restarts
      final Map<String, Shape> currentShapes = {
        for (final shape in repository.shapes) shape.id: shape,
      };

      // Compute uncommitted changes between snapshot and working copy
      final uncommittedChanges = _computeChanges(baseShapes, currentShapes);

      // Save the selected branch for next app startup
      await _prefsService.setLastBranchId(event.projectId, initialBranch.id);

      emit(
        state.copyWith(
          status: VersionControlStatus.ready,
          branches: branches,
          currentBranchId: initialBranch.id,
          commits: commits,
          baseShapes: baseShapes,
          currentShapes: currentShapes,
          uncommittedChanges: uncommittedChanges,
          clearError: true,
        ),
      );

      VioLogger.info(
        'VersionControlBloc: Loaded ${branches.length} branches, '
        '${commits.length} commits, ${baseShapes.length} base shapes, '
        '${uncommittedChanges.length} uncommitted changes',
      );
    } on GrpcError catch (e) {
      VioLogger.error(
        'VersionControlBloc: Failed to initialize - ${e.message}',
      );
      emit(
        state.copyWith(
          status: VersionControlStatus.error,
          error: e.message ?? 'Failed to load version control data',
        ),
      );
    }
  }

  void _onPollingStarted(
    VersionControlPollingStarted event,
    Emitter<VersionControlState> emit,
  ) {
    if (_pollingTimer != null) return;

    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      add(const BranchesRefreshRequested());
      add(const CommitsRefreshRequested());
    });
    emit(state.copyWith(isPolling: true));
    VioLogger.debug('VersionControlBloc: Polling started');
  }

  void _onPollingStopped(
    VersionControlPollingStopped event,
    Emitter<VersionControlState> emit,
  ) {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    emit(state.copyWith(isPolling: false));
  }

  // ============================================================================
  // Branch Operations
  // ============================================================================

  Future<void> _onBranchesRefresh(
    BranchesRefreshRequested event,
    Emitter<VersionControlState> emit,
  ) async {
    if (state.projectId == null) return;

    try {
      final response = await _branchClient.listBranches(
        branch_pb.ListBranchesRequest()..projectId = state.projectId!,
      );

      final branches = response.branches
          .map(
            (b) => BranchDto(
              id: b.id,
              name: b.name,
              projectId: b.projectId,
              description: b.description.isEmpty ? null : b.description,
              headCommitId: b.headCommitId.isEmpty ? null : b.headCommitId,
              isDefault: b.isDefault,
              isProtected: b.isProtected,
              createdById: b.createdById,
              createdAt: _timestampToDateTimeOrNull(b.createdAt),
              updatedAt: _timestampToDateTimeOrNull(b.updatedAt),
            ),
          )
          .toList();

      emit(state.copyWith(branches: branches));
    } on GrpcError catch (e) {
      VioLogger.error(
        'VersionControlBloc: Failed to refresh branches - ${e.message}',
      );
    }
  }

  Future<void> _onBranchSwitch(
    BranchSwitchRequested event,
    Emitter<VersionControlState> emit,
  ) async {
    // Skip if already on this branch
    if (event.branchId == state.currentBranchId) return;

    // Check for uncommitted changes (unless forcing discard)
    if (!event.forceDiscard && state.hasUncommittedChanges) {
      // Set pending switch - UI will show confirmation dialog
      emit(state.copyWith(pendingSwitchBranchId: event.branchId));
      return;
    }

    // Proceed with branch switch
    await _executeBranchSwitch(event.branchId, emit);
  }

  /// Confirm branch switch after user acknowledges discarding changes
  Future<void> _onBranchSwitchConfirmed(
    BranchSwitchConfirmed event,
    Emitter<VersionControlState> emit,
  ) async {
    final pendingBranchId = state.pendingSwitchBranchId;
    if (pendingBranchId == null) return;

    // Clear pending state first
    emit(state.copyWith(clearPendingSwitchBranchId: true));

    // Execute the switch
    await _executeBranchSwitch(pendingBranchId, emit);
  }

  /// Cancel pending branch switch
  void _onBranchSwitchCanceled(
    BranchSwitchCanceled event,
    Emitter<VersionControlState> emit,
  ) {
    emit(state.copyWith(clearPendingSwitchBranchId: true));
  }

  /// Execute the actual branch switch - loads shapes from the new branch
  Future<void> _executeBranchSwitch(
    String branchId,
    Emitter<VersionControlState> emit,
  ) async {
    // Signal repository to pause auto-sync during branch switch
    // This prevents race conditions where auto-sync overwrites shapes
    final repository = ServiceLocator.instance.canvasRepository;
    repository.beginBranchSwitch();

    emit(
      state.copyWith(
        status: VersionControlStatus.switching,
        currentBranchId: branchId,
        clearPendingSwitchBranchId: true,
      ),
    );

    // Save the selected branch for next app startup
    if (state.projectId != null) {
      await _prefsService.setLastBranchId(state.projectId!, branchId);
    }

    try {
      // Get the new branch info to find its head commit
      final branchResponse = await _branchClient.getBranch(
        branch_pb.GetBranchRequest()
          ..projectId = state.projectId!
          ..branchId = branchId,
      );

      final headCommitId = branchResponse.branch.headCommitId;
      VioLogger.info(
        'VersionControlBloc: Branch $branchId has headCommitId: "$headCommitId" (isEmpty: ${headCommitId.isEmpty})',
      );

      if (headCommitId.isNotEmpty) {
        // Load the commit which includes the snapshot
        final commitResponse = await _commitClient.getCommit(
          commit_pb.GetCommitRequest()
            ..projectId = state.projectId!
            ..commitId = headCommitId,
        );

        VioLogger.debug(
          'VersionControlBloc: Got commit ${commitResponse.commit.id}, hasSnapshot: ${commitResponse.hasSnapshot()}, snapshotId: ${commitResponse.snapshot.id}',
        );

        // IMPORTANT: Restore the working copy (shapes table) from the snapshot
        // This ensures the database has the correct shapes for this branch
        // so that future commits capture the right state.
        if (commitResponse.hasSnapshot() &&
            commitResponse.snapshot.id.isNotEmpty) {
          try {
            await repository.restoreFromSnapshot(commitResponse.snapshot.id);
            VioLogger.info(
              'VersionControlBloc: Restored working copy from snapshot ${commitResponse.snapshot.id}',
            );
          } catch (e) {
            VioLogger.error(
              'VersionControlBloc: Failed to restore working copy - $e',
            );
            // Continue anyway - the client shapes will still be loaded from
            // the snapshot, just the DB may be stale
          }
        }

        // Parse shapes from snapshot (included in GetCommitResponse)
        final Map<String, Shape> newShapes = {};

        if (commitResponse.hasSnapshot()) {
          final snapshotBytes = commitResponse.snapshot.data;
          VioLogger.debug(
            'VersionControlBloc: Snapshot data length: ${snapshotBytes.length} bytes',
          );
          if (snapshotBytes.isNotEmpty) {
            try {
              final jsonData = jsonDecode(utf8.decode(snapshotBytes))
                  as Map<String, dynamic>;
              final shapesJson = jsonData['shapes'] as List<dynamic>? ?? [];
              VioLogger.debug(
                'VersionControlBloc: Found ${shapesJson.length} shapes in snapshot JSON',
              );
              for (final shapeJson in shapesJson) {
                try {
                  final shape =
                      ShapeFactory.fromJson(shapeJson as Map<String, dynamic>);
                  newShapes[shape.id] = shape;
                  VioLogger.debug(
                    'VersionControlBloc: Successfully parsed shape ${shape.id} (${shape.type})',
                  );
                } catch (e, stackTrace) {
                  VioLogger.warning(
                    'VersionControlBloc: Failed to parse shape from snapshot: $e\n$stackTrace',
                  );
                }
              }
              VioLogger.info(
                'VersionControlBloc: Parsed ${newShapes.length} shapes from snapshot',
              );
            } catch (e, stackTrace) {
              VioLogger.error(
                'VersionControlBloc: Failed to parse snapshot - $e\n$stackTrace',
              );
            }
          }
        }

        // CRITICAL: Update repository's internal shapes list to match snapshot
        // This ensures subsequent updateShape/deleteShape calls will work.
        // Without this, the repository thinks no shapes exist and rejects updates.
        // ALSO: We must set projectId so that _syncToServer will actually sync!
        repository.setShapesFromSnapshot(
          newShapes.values.toList(),
          projectId: state.projectId!,
          branchId: branchId,
        );

        // Update base shapes and clear staged state
        emit(
          state.copyWith(
            baseShapes: newShapes,
            currentShapes: newShapes,
            uncommittedChanges: const [],
            stagedShapeIds: const {},
          ),
        );

        VioLogger.info(
          'VersionControlBloc: Switched to branch, loaded ${newShapes.length} shapes',
        );
      } else {
        // Empty branch - clear shapes and working copy
        VioLogger.info(
          'VersionControlBloc: Branch has no head commit, clearing working copy',
        );

        // Clear the working copy (shapes table) since there's no snapshot to restore from
        try {
          await repository.clearWorkingCopy();
          VioLogger.info(
            'VersionControlBloc: Cleared working copy for empty branch',
          );
        } catch (e) {
          VioLogger.error(
            'VersionControlBloc: Failed to clear working copy - $e',
          );
          // Continue anyway - shapes will still be cleared locally
        }

        // CRITICAL: Update repository's internal shapes list to be empty
        // This ensures the repository state matches the empty branch
        // ALSO: We must set projectId so that _syncToServer will actually sync!
        repository.setShapesFromSnapshot(
          const [],
          projectId: state.projectId!,
          branchId: branchId,
        );

        emit(
          state.copyWith(
            baseShapes: const {},
            currentShapes: const {},
            uncommittedChanges: const [],
            stagedShapeIds: const {},
          ),
        );
      }

      // Refresh commits for the new branch
      add(const CommitsRefreshRequested());

      // Signal repository that branch switch is complete, resume auto-sync
      repository.endBranchSwitch();

      emit(state.copyWith(status: VersionControlStatus.ready));
    } on GrpcError catch (e) {
      // Signal repository that branch switch is complete (even on error)
      repository.endBranchSwitch();

      VioLogger.error(
        'VersionControlBloc: Failed to switch branch - ${e.message}',
      );
      emit(
        state.copyWith(
          status: VersionControlStatus.error,
          error: e.message ?? 'Failed to switch branch',
        ),
      );
    }
  }

  Future<void> _onBranchCreate(
    BranchCreateRequested event,
    Emitter<VersionControlState> emit,
  ) async {
    if (state.projectId == null || state.userId == null) return;

    VioLogger.info(
      'VersionControlBloc: Creating branch "${event.name}" from sourceBranchId: ${event.sourceBranchId}',
    );

    try {
      final request = branch_pb.CreateBranchRequest()
        ..projectId = state.projectId!
        ..name = event.name
        ..createdById = state.userId!;

      if (event.sourceBranchId != null) {
        request.sourceBranchId = event.sourceBranchId!;
      }

      final response = await _branchClient.createBranch(request);

      final newBranchId = response.branch.id;
      final newHeadCommitId = response.branch.headCommitId;
      VioLogger.info(
        'VersionControlBloc: CreateBranch response - branchId: $newBranchId, headCommitId: "$newHeadCommitId"',
      );

      // Refresh branches list
      add(const BranchesRefreshRequested());

      // If created from current branch, switch without reloading shapes (like git checkout -b)
      // This preserves the working directory state including uncommitted changes
      if (event.sourceBranchId == state.currentBranchId &&
          newBranchId.isNotEmpty) {
        VioLogger.info(
          'VersionControlBloc: Created branch from current, switching without reload',
        );
        // Save the selected branch for next app startup
        if (state.projectId != null) {
          await _prefsService.setLastBranchId(state.projectId!, newBranchId);
        }
        // Just update current branch ID - keep shapes, base shapes, and uncommitted changes
        emit(
          state.copyWith(
            currentBranchId: newBranchId,
          ),
        );
        // Refresh commits for the new branch
        add(const CommitsRefreshRequested());
      } else if (newBranchId.isNotEmpty) {
        // Created from a different branch - do full switch (which also saves preference)
        VioLogger.info(
          'VersionControlBloc: Created branch from different source, full switch',
        );
        add(BranchSwitchRequested(branchId: newBranchId, forceDiscard: true));
      }
    } on GrpcError catch (e) {
      emit(state.copyWith(error: e.message ?? 'Failed to create branch'));
    }
  }

  Future<void> _onBranchDelete(
    BranchDeleteRequested event,
    Emitter<VersionControlState> emit,
  ) async {
    if (state.projectId == null) return;

    // Check if branch is the current branch
    if (event.branchId == state.currentBranchId) {
      emit(
        state.copyWith(error: 'Cannot delete the currently active branch'),
      );
      return;
    }

    // Check if branch is protected
    final branch = state.branches.firstWhere(
      (b) => b.id == event.branchId,
      orElse: () => state.branches.first,
    );
    if (branch.isProtected) {
      emit(state.copyWith(error: 'Cannot delete a protected branch'));
      return;
    }

    // Check if branch is default
    if (branch.isDefault) {
      emit(state.copyWith(error: 'Cannot delete the default branch'));
      return;
    }

    // If not forcing, show confirmation
    if (!event.forceDelete) {
      emit(state.copyWith(pendingDeleteBranchId: event.branchId));
      return;
    }

    // Execute the delete
    await _executeBranchDelete(event.branchId, emit);
  }

  /// Confirm branch deletion
  Future<void> _onBranchDeleteConfirmed(
    BranchDeleteConfirmed event,
    Emitter<VersionControlState> emit,
  ) async {
    final pendingBranchId = state.pendingDeleteBranchId;
    if (pendingBranchId == null) return;

    // Clear pending state first
    emit(state.copyWith(clearPendingDeleteBranchId: true));

    // Execute the delete
    await _executeBranchDelete(pendingBranchId, emit);
  }

  /// Cancel pending branch deletion
  void _onBranchDeleteCanceled(
    BranchDeleteCanceled event,
    Emitter<VersionControlState> emit,
  ) {
    emit(state.copyWith(clearPendingDeleteBranchId: true));
  }

  /// Execute the actual branch deletion
  Future<void> _executeBranchDelete(
    String branchId,
    Emitter<VersionControlState> emit,
  ) async {
    try {
      await _branchClient.deleteBranch(
        branch_pb.DeleteBranchRequest()
          ..projectId = state.projectId!
          ..branchId = branchId,
      );

      add(const BranchesRefreshRequested());
    } on GrpcError catch (e) {
      emit(state.copyWith(error: e.message ?? 'Failed to delete branch'));
    }
  }

  Future<void> _onBranchCompare(
    BranchCompareRequested event,
    Emitter<VersionControlState> emit,
  ) async {
    if (state.projectId == null) return;

    try {
      final response = await _branchClient.compareBranches(
        branch_pb.CompareBranchesRequest()
          ..projectId = state.projectId!
          ..baseBranchId = event.baseBranchId
          ..headBranchId = event.headBranchId,
      );

      emit(
        state.copyWith(
          branchComparison: BranchComparisonDto(
            baseBranchId: event.baseBranchId,
            headBranchId: event.headBranchId,
            commitsAhead: response.commitsAhead,
            commitsBehind: response.commitsBehind,
            canFastForward: response.mergeable,
          ),
        ),
      );
    } on GrpcError catch (e) {
      emit(state.copyWith(error: e.message ?? 'Failed to compare branches'));
    }
  }

  // ============================================================================
  // Commit Operations
  // ============================================================================

  Future<void> _onCommitsRefresh(
    CommitsRefreshRequested event,
    Emitter<VersionControlState> emit,
  ) async {
    if (state.projectId == null || state.currentBranchId == null) return;

    try {
      final response = await _commitClient.listCommits(
        commit_pb.ListCommitsRequest()
          ..projectId = state.projectId!
          ..branchId = state.currentBranchId!,
      );

      final commits = response.commits
          .map(
            (c) => CommitDto(
              id: c.id,
              projectId: c.projectId,
              branchId: c.branchId,
              message: c.message,
              authorId: c.authorId,
              snapshotId: c.snapshotId,
              createdAt: _timestampToDateTime(c.createdAt),
              parentId: c.parentId.isEmpty ? null : c.parentId,
            ),
          )
          .toList();

      emit(state.copyWith(commits: commits));
    } on GrpcError catch (e) {
      VioLogger.error(
        'VersionControlBloc: Failed to refresh commits - ${e.message}',
      );
    }
  }

  Future<void> _onCommitCreate(
    CommitCreateRequested event,
    Emitter<VersionControlState> emit,
  ) async {
    if (state.projectId == null ||
        state.currentBranchId == null ||
        state.userId == null) {
      return;
    }

    emit(state.copyWith(status: VersionControlStatus.committing));

    try {
      // IMPORTANT: Sync pending shapes to the database BEFORE creating the commit.
      // The backend reads shapes from the database when creating a snapshot,
      // so any pending local changes must be persisted first.
      final repository = ServiceLocator.instance.canvasRepository;
      await repository.sync();
      VioLogger.info(
        'VersionControlBloc: Synced shapes to database before commit',
      );

      await _commitClient.createCommit(
        commit_pb.CreateCommitRequest()
          ..projectId = state.projectId!
          ..branchId = state.currentBranchId!
          ..message = event.message
          ..authorId = state.userId!,
      );

      // After commit, current shapes become the new base (no uncommitted changes)
      emit(
        state.copyWith(
          stagedShapeIds: {},
          baseShapes: state.currentShapes,
          uncommittedChanges: [],
          status: VersionControlStatus.ready,
        ),
      );
      add(const CommitsRefreshRequested());

      VioLogger.info('VersionControlBloc: Commit created, base shapes updated');
    } on GrpcError catch (e) {
      emit(
        state.copyWith(
          status: VersionControlStatus.error,
          error: e.message ?? 'Failed to create commit',
        ),
      );
    }
  }

  Future<void> _onCommitCheckout(
    CommitCheckoutRequested event,
    Emitter<VersionControlState> emit,
  ) async {
    if (state.projectId == null || state.userId == null) return;

    emit(state.copyWith(status: VersionControlStatus.switching));

    try {
      // First create a new branch for the checkout
      final branchResponse = await _branchClient.createBranch(
        branch_pb.CreateBranchRequest()
          ..projectId = state.projectId!
          ..name = event.newBranchName
          ..createdById = state.userId!,
      );

      // Then checkout the commit to that branch
      await _commitClient.checkoutCommit(
        commit_pb.CheckoutCommitRequest()
          ..projectId = state.projectId!
          ..branchId = branchResponse.branch.id
          ..commitId = event.commitId
          ..authorId = state.userId!
          ..message = 'Checkout commit ${event.commitId.substring(0, 8)}',
      );

      // Refresh branches and switch to the new branch
      add(const BranchesRefreshRequested());
      add(BranchSwitchRequested(branchId: branchResponse.branch.id));

      emit(state.copyWith(status: VersionControlStatus.ready));
    } on GrpcError catch (e) {
      emit(
        state.copyWith(
          status: VersionControlStatus.error,
          error: e.message ?? 'Failed to checkout commit',
        ),
      );
    }
  }

  Future<void> _onCommitRevert(
    CommitRevertRequested event,
    Emitter<VersionControlState> emit,
  ) async {
    if (state.projectId == null ||
        state.currentBranchId == null ||
        state.userId == null) {
      return;
    }

    try {
      await _commitClient.revertCommit(
        commit_pb.RevertCommitRequest()
          ..projectId = state.projectId!
          ..branchId = state.currentBranchId!
          ..commitId = event.commitId
          ..authorId = state.userId!,
      );

      add(const CommitsRefreshRequested());
    } on GrpcError catch (e) {
      emit(state.copyWith(error: e.message ?? 'Failed to revert commit'));
    }
  }

  // ============================================================================
  // Pull Request Operations
  // ============================================================================

  Future<void> _onPullRequestsRefresh(
    PullRequestsRefreshRequested event,
    Emitter<VersionControlState> emit,
  ) async {
    if (state.projectId == null) return;

    try {
      final response = await _prClient.listPullRequests(
        pr_pb.ListPullRequestsRequest()..projectId = state.projectId!,
      );

      final prs = response.pullRequests
          .map(
            (pr) => PullRequestDto(
              id: pr.id,
              projectId: pr.projectId,
              title: pr.title,
              description: pr.description.isEmpty ? null : pr.description,
              sourceBranchId: pr.sourceBranchId,
              targetBranchId: pr.targetBranchId,
              status: _mapPrStatus(pr.status),
              authorId: pr.authorId,
              createdAt: _timestampToDateTime(pr.createdAt),
              updatedAt: _timestampToDateTime(pr.updatedAt),
              mergedAt: _timestampToDateTimeOrNull(pr.mergedAt),
              closedAt: _timestampToDateTimeOrNull(pr.closedAt),
            ),
          )
          .toList();

      emit(state.copyWith(pullRequests: prs));
    } on GrpcError catch (e) {
      VioLogger.error(
        'VersionControlBloc: Failed to refresh PRs - ${e.message}',
      );
    }
  }

  PullRequestStatus _mapPrStatus(pr_pb.PullRequestStatus status) {
    switch (status) {
      case pr_pb.PullRequestStatus.PULL_REQUEST_STATUS_OPEN:
        return PullRequestStatus.open;
      case pr_pb.PullRequestStatus.PULL_REQUEST_STATUS_MERGED:
        return PullRequestStatus.merged;
      case pr_pb.PullRequestStatus.PULL_REQUEST_STATUS_CLOSED:
        return PullRequestStatus.closed;
      default:
        return PullRequestStatus.open;
    }
  }

  Future<void> _onPullRequestCreate(
    PullRequestCreateRequested event,
    Emitter<VersionControlState> emit,
  ) async {
    if (state.projectId == null || state.userId == null) return;

    try {
      await _prClient.createPullRequest(
        pr_pb.CreatePullRequestRequest()
          ..projectId = state.projectId!
          ..sourceBranchId = event.sourceBranchId
          ..targetBranchId = event.targetBranchId
          ..title = event.title
          ..description = event.description ?? ''
          ..authorId = state.userId!,
      );

      add(const PullRequestsRefreshRequested());
    } on GrpcError catch (e) {
      emit(state.copyWith(error: e.message ?? 'Failed to create pull request'));
    }
  }

  Future<void> _onPullRequestSelected(
    PullRequestSelected event,
    Emitter<VersionControlState> emit,
  ) async {
    if (state.projectId == null) return;

    final selected = state.pullRequests.firstWhere(
      (pr) => pr.id == event.pullRequestId,
      orElse: () => state.pullRequests.first,
    );

    emit(state.copyWith(selectedPullRequest: selected));
  }

  Future<void> _onPullRequestMerge(
    PullRequestMergeRequested event,
    Emitter<VersionControlState> emit,
  ) async {
    if (state.projectId == null) return;

    emit(state.copyWith(status: VersionControlStatus.merging));

    try {
      await _prClient.mergePullRequest(
        pr_pb.MergePullRequestRequest()
          ..projectId = state.projectId!
          ..pullRequestId = event.pullRequestId,
      );

      emit(
        state.copyWith(
          status: VersionControlStatus.ready,
          clearSelectedPullRequest: true,
        ),
      );
      add(const PullRequestsRefreshRequested());
      add(const BranchesRefreshRequested());
      add(const CommitsRefreshRequested());
    } on GrpcError catch (e) {
      emit(
        state.copyWith(
          status: VersionControlStatus.error,
          error: e.message ?? 'Failed to merge pull request',
        ),
      );
    }
  }

  Future<void> _onPullRequestClose(
    PullRequestCloseRequested event,
    Emitter<VersionControlState> emit,
  ) async {
    if (state.projectId == null) return;

    try {
      await _prClient.closePullRequest(
        pr_pb.ClosePullRequestRequest()
          ..projectId = state.projectId!
          ..pullRequestId = event.pullRequestId,
      );

      emit(state.copyWith(clearSelectedPullRequest: true));
      add(const PullRequestsRefreshRequested());
    } on GrpcError catch (e) {
      emit(state.copyWith(error: e.message ?? 'Failed to close pull request'));
    }
  }

  Future<void> _onConflictsResolve(
    ConflictsResolveRequested event,
    Emitter<VersionControlState> emit,
  ) async {
    // Conflict resolution requires complex UI - just log for now
    VioLogger.warning(
      'VersionControlBloc: Conflict resolution not yet implemented in UI',
    );
  }

  // ============================================================================
  // Staging Operations (Local only - works in stub mode)
  // ============================================================================

  void _onShapesStaged(
    ShapesStagedForCommit event,
    Emitter<VersionControlState> emit,
  ) {
    final newStaged = Set<String>.from(state.stagedShapeIds)
      ..addAll(event.shapeIds);
    emit(state.copyWith(stagedShapeIds: newStaged));
  }

  void _onStagedCleared(
    StagedShapesCleared event,
    Emitter<VersionControlState> emit,
  ) {
    emit(state.copyWith(stagedShapeIds: {}));
  }

  // ============================================================================
  // Canvas Change Detection
  // ============================================================================

  void _onBaseShapesLoaded(
    BaseShapesLoaded event,
    Emitter<VersionControlState> emit,
  ) {
    final changes = _computeChanges(event.shapes, state.currentShapes);
    emit(
      state.copyWith(
        baseShapes: event.shapes,
        uncommittedChanges: changes,
      ),
    );
    VioLogger.debug(
      'VersionControlBloc: Base shapes loaded (${event.shapes.length} shapes, '
      '${changes.length} uncommitted changes)',
    );
  }

  void _onCanvasShapesChanged(
    CanvasShapesChanged event,
    Emitter<VersionControlState> emit,
  ) {
    // If VC hasn't finished loading yet, just store current shapes
    // Don't set base shapes - wait for VC to load them from HEAD commit
    if (state.status == VersionControlStatus.initial ||
        state.status == VersionControlStatus.loading) {
      emit(state.copyWith(currentShapes: event.shapes));
      VioLogger.debug(
        'VersionControlBloc: VC not ready yet, stored ${event.shapes.length} '
        'current shapes (status: ${state.status})',
      );
      return;
    }

    // If base shapes haven't been set and VC is ready with no commits,
    // initialize base with current shapes (nothing to compare against)
    if (state.baseShapes.isEmpty && state.commits.isEmpty) {
      emit(
        state.copyWith(
          baseShapes: event.shapes,
          currentShapes: event.shapes,
          uncommittedChanges: [],
        ),
      );
      VioLogger.debug(
        'VersionControlBloc: No commits - initialized base shapes with '
        '${event.shapes.length} current shapes',
      );
      return;
    }

    final changes = _computeChanges(state.baseShapes, event.shapes);
    emit(
      state.copyWith(
        currentShapes: event.shapes,
        uncommittedChanges: changes,
      ),
    );
    VioLogger.debug(
      'VersionControlBloc: Canvas changed (${event.shapes.length} shapes, '
      '${changes.length} uncommitted changes)',
    );
  }

  /// Compute shape changes between base and current shapes
  List<ShapeChangeDto> _computeChanges(
    Map<String, Shape> base,
    Map<String, Shape> current,
  ) {
    final changes = <ShapeChangeDto>[];

    // Check for added and modified shapes
    for (final entry in current.entries) {
      final id = entry.key;
      final currentShape = entry.value;
      final baseShape = base[id];

      if (baseShape == null) {
        // Shape was added
        changes.add(
          ShapeChangeDto(
            shapeId: id,
            shapeName: currentShape.name,
            changeType: ShapeChangeType.added,
            afterShape: currentShape,
          ),
        );
      } else if (_hasShapeChanged(baseShape, currentShape)) {
        // Shape was modified
        changes.add(
          ShapeChangeDto(
            shapeId: id,
            shapeName: currentShape.name,
            changeType: ShapeChangeType.modified,
            beforeShape: baseShape,
            afterShape: currentShape,
            changedProperties: _getChangedProperties(baseShape, currentShape),
          ),
        );
      }
    }

    // Check for deleted shapes
    for (final entry in base.entries) {
      final id = entry.key;
      if (!current.containsKey(id)) {
        changes.add(
          ShapeChangeDto(
            shapeId: id,
            shapeName: entry.value.name,
            changeType: ShapeChangeType.deleted,
            beforeShape: entry.value,
          ),
        );
      }
    }

    return changes;
  }

  /// Check if a shape has meaningful changes
  bool _hasShapeChanged(Shape base, Shape current) {
    // Quick equality check using Equatable
    if (base == current) return false;

    // Compare key properties
    return base.x != current.x ||
        base.y != current.y ||
        base.width != current.width ||
        base.height != current.height ||
        base.rotation != current.rotation ||
        base.transform != current.transform ||
        base.fills != current.fills ||
        base.strokes != current.strokes ||
        base.opacity != current.opacity ||
        base.hidden != current.hidden ||
        base.blocked != current.blocked ||
        base.name != current.name ||
        base.shadow != current.shadow ||
        base.blur != current.blur;
  }

  /// Get list of changed property names for display
  List<String> _getChangedProperties(Shape base, Shape current) {
    final changed = <String>[];
    if (base.x != current.x || base.y != current.y) changed.add('position');
    if (base.width != current.width || base.height != current.height) {
      changed.add('size');
    }
    if (base.rotation != current.rotation) changed.add('rotation');
    if (base.fills != current.fills) changed.add('fills');
    if (base.strokes != current.strokes) changed.add('strokes');
    if (base.opacity != current.opacity) changed.add('opacity');
    if (base.hidden != current.hidden) changed.add('visibility');
    if (base.blocked != current.blocked) changed.add('locked');
    if (base.name != current.name) changed.add('name');
    if (base.shadow != current.shadow) changed.add('shadow');
    if (base.blur != current.blur) changed.add('blur');
    return changed;
  }

  /// Handle discard shape change request
  /// This computes what the canvas state should be to discard the change,
  /// then the UI layer is responsible for applying it to CanvasBloc
  void _onShapeChangeDiscarded(
    ShapeChangeDiscarded event,
    Emitter<VersionControlState> emit,
  ) {
    final change = state.uncommittedChanges.firstWhere(
      (c) => c.shapeId == event.shapeId,
      orElse: () => throw StateError('Change not found'),
    );

    // Compute new current shapes after discarding
    final newCurrentShapes = Map<String, Shape>.from(state.currentShapes);

    switch (change.changeType) {
      case ShapeChangeType.added:
        // Remove the added shape
        newCurrentShapes.remove(event.shapeId);
      case ShapeChangeType.modified:
        // Revert to base shape
        final baseShape = state.baseShapes[event.shapeId];
        if (baseShape != null) {
          newCurrentShapes[event.shapeId] = baseShape;
        }
      case ShapeChangeType.deleted:
        // Restore the deleted shape
        final baseShape = state.baseShapes[event.shapeId];
        if (baseShape != null) {
          newCurrentShapes[event.shapeId] = baseShape;
        }
    }

    // Recompute changes
    final newChanges = _computeChanges(state.baseShapes, newCurrentShapes);

    // Remove from staged if it was staged
    final newStagedIds = Set<String>.from(state.stagedShapeIds)
      ..remove(event.shapeId);

    emit(
      state.copyWith(
        currentShapes: newCurrentShapes,
        uncommittedChanges: newChanges,
        stagedShapeIds: newStagedIds,
      ),
    );
  }

  /// Handle discard all changes request
  void _onAllChangesDiscarded(
    AllChangesDiscarded event,
    Emitter<VersionControlState> emit,
  ) {
    // Revert currentShapes to baseShapes
    final newCurrentShapes = Map<String, Shape>.from(state.baseShapes);

    emit(
      state.copyWith(
        currentShapes: newCurrentShapes,
        uncommittedChanges: [],
        stagedShapeIds: <String>{},
      ),
    );
  }

  /// Get the shapes that should be applied to canvas after a discard
  /// Returns null if no change found
  Map<String, Shape>? getDiscardedShapesState(String shapeId) {
    final change = state.uncommittedChanges.firstWhere(
      (c) => c.shapeId == shapeId,
      orElse: () => throw StateError('Change not found'),
    );

    final newShapes = Map<String, Shape>.from(state.currentShapes);

    switch (change.changeType) {
      case ShapeChangeType.added:
        newShapes.remove(shapeId);
      case ShapeChangeType.modified:
        final baseShape = state.baseShapes[shapeId];
        if (baseShape != null) {
          newShapes[shapeId] = baseShape;
        }
      case ShapeChangeType.deleted:
        final baseShape = state.baseShapes[shapeId];
        if (baseShape != null) {
          newShapes[shapeId] = baseShape;
        }
    }

    return newShapes;
  }

  // ============================================================================
  // Commit and Switch
  // ============================================================================

  /// Commit current changes and then switch to a target branch.
  Future<void> _onCommitAndSwitch(
    CommitAndSwitchRequested event,
    Emitter<VersionControlState> emit,
  ) async {
    if (state.projectId == null || state.userId == null) return;

    emit(
      state.copyWith(
        status: VersionControlStatus.committing,
        clearPendingSwitchBranchId: true,
      ),
    );

    try {
      // Step 1: Sync shapes to database
      final repository = ServiceLocator.instance.canvasRepository;
      await repository.sync();
      VioLogger.info(
        'VersionControlBloc: Synced shapes before commit-and-switch',
      );

      // Step 2: Create the commit
      await _commitClient.createCommit(
        commit_pb.CreateCommitRequest()
          ..projectId = state.projectId!
          ..branchId = state.currentBranchId!
          ..message = event.message
          ..authorId = state.userId!,
      );

      // Update state: current shapes become base (no uncommitted changes)
      emit(
        state.copyWith(
          stagedShapeIds: {},
          baseShapes: state.currentShapes,
          uncommittedChanges: [],
          status: VersionControlStatus.ready,
        ),
      );

      VioLogger.info(
        'VersionControlBloc: Commit created, now switching to ${event.targetBranchId}',
      );

      // Step 3: Switch to the target branch
      add(
        BranchSwitchRequested(
          branchId: event.targetBranchId,
          forceDiscard: true,
        ),
      );
    } on GrpcError catch (e) {
      emit(
        state.copyWith(
          status: VersionControlStatus.error,
          error: e.message ?? 'Failed to commit and switch branch',
        ),
      );
    }
  }

  // ============================================================================
  // Branch Update
  // ============================================================================

  /// Update branch name, description, or protection status.
  Future<void> _onBranchUpdate(
    BranchUpdateRequested event,
    Emitter<VersionControlState> emit,
  ) async {
    if (state.projectId == null) return;

    emit(state.copyWith(status: VersionControlStatus.loading));

    try {
      final request = branch_pb.UpdateBranchRequest()
        ..projectId = state.projectId!
        ..branchId = event.branchId;

      if (event.name != null) request.name = event.name!;
      if (event.description != null) request.description = event.description!;
      if (event.isProtected != null) request.isProtected = event.isProtected!;

      final response = await _branchClient.updateBranch(request);

      // Update the branch in local state
      final updatedBranch = BranchDto(
        id: response.branch.id,
        name: response.branch.name,
        projectId: response.branch.projectId,
        description: response.branch.description.isEmpty
            ? null
            : response.branch.description,
        headCommitId: response.branch.headCommitId.isEmpty
            ? null
            : response.branch.headCommitId,
        isDefault: response.branch.isDefault,
        isProtected: response.branch.isProtected,
        createdById: response.branch.createdById,
        createdAt: _timestampToDateTimeOrNull(response.branch.createdAt),
        updatedAt: _timestampToDateTimeOrNull(response.branch.updatedAt),
      );

      final updatedBranches = state.branches.map((b) {
        return b.id == updatedBranch.id ? updatedBranch : b;
      }).toList();

      emit(
        state.copyWith(
          branches: updatedBranches,
          status: VersionControlStatus.ready,
        ),
      );

      VioLogger.info(
        'VersionControlBloc: Branch ${event.branchId} updated',
      );
    } on GrpcError catch (e) {
      emit(
        state.copyWith(
          status: VersionControlStatus.error,
          error: e.message ?? 'Failed to update branch',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _pollingTimer?.cancel();
    return super.close();
  }
}
