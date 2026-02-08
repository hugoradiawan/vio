import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import 'package:vio_core/vio_core.dart';

import '../../gen/vio/v1/canvas.pb.dart' as pb;
import '../../gen/vio/v1/canvas.pbgrpc.dart';
import '../grpc/proto_converter.dart';

/// Repository that manages canvas state with gRPC sync to the backend
///
/// Implements last-write-wins conflict resolution strategy:
/// - Local changes are immediately applied
/// - Changes are periodically synced to server via gRPC
/// - Server version always wins on conflict
///
/// Branch switch protection:
/// - Auto-sync is paused during branch switching operations
/// - _loadFromServer is blocked while switching to prevent race conditions
class GrpcCanvasRepository {
  GrpcCanvasRepository({
    required CanvasServiceClient canvasClient,
    Duration syncInterval = const Duration(seconds: 5),
  })  : _canvasClient = canvasClient,
        _syncInterval = syncInterval;

  final CanvasServiceClient _canvasClient;
  final Duration _syncInterval;

  // Project/Branch context
  String? _projectId;
  String? _branchId;

  // Local state
  final List<Shape> _shapes = [];
  Int64 _localVersion = Int64.ZERO;
  bool _isDirty = false;

  // Branch switch protection - prevents auto-sync and load operations
  // while a branch switch is in progress
  bool _isBranchSwitching = false;

  // Pending operations for sync
  final List<_PendingOp> _pendingOperations = [];

  // Sync timer
  Timer? _syncTimer;
  Timer? _debouncedSyncTimer;
  bool _isSyncing = false;

  /// Duration for debounced sync after mutations (short delay to batch
  /// rapid changes while still persisting quickly).
  static const _debounceSyncDelay = Duration(milliseconds: 500);

  // Stream controllers for state updates
  final _shapesController = StreamController<List<Shape>>.broadcast();
  final _syncStatusController = StreamController<SyncStatus>.broadcast();

  /// Stream of shape updates
  Stream<List<Shape>> get shapesStream => _shapesController.stream;

  /// Stream of sync status updates
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  /// Current shapes
  List<Shape> get shapes => List.unmodifiable(_shapes);

  /// Whether there are unsaved changes
  bool get isDirty => _isDirty;

  /// Current sync status
  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus get syncStatus => _currentStatus;

  /// Whether a branch switch is in progress (blocks auto-sync and load)
  bool get isBranchSwitching => _isBranchSwitching;

  /// Signal that a branch switch is starting
  /// This pauses auto-sync and blocks _loadFromServer until the switch completes
  void beginBranchSwitch() {
    _isBranchSwitching = true;
    VioLogger.info('GrpcCanvasRepository: Branch switch started, pausing sync');
  }

  /// Signal that a branch switch has completed
  /// This resumes normal auto-sync behavior
  void endBranchSwitch() {
    _isBranchSwitching = false;
    VioLogger.info(
      'GrpcCanvasRepository: Branch switch completed, resuming sync',
    );
  }

  /// Set shapes from a snapshot during branch switch
  ///
  /// This is called by VersionControlBloc when shapes are loaded from a
  /// snapshot during branch switching. It updates the repository's internal
  /// state to match the shapes from the snapshot, so that subsequent
  /// updateShape/deleteShape calls will work correctly.
  ///
  /// IMPORTANT: This must be called after parsing shapes from snapshot,
  /// otherwise the repository will think shapes don't exist and reject updates.
  ///
  /// Both projectId and branchId are required to enable sync operations.
  /// Without projectId, _syncToServer will silently return without syncing.
  void setShapesFromSnapshot(
    List<Shape> newShapes, {
    required String projectId,
    required String branchId,
  }) {
    VioLogger.info(
      'GrpcCanvasRepository: Setting ${newShapes.length} shapes from snapshot '
      'for project $projectId, branch $branchId',
    );

    // Update project and branch context - BOTH are required for sync to work
    _projectId = projectId;
    _branchId = branchId;

    // Replace internal shapes list
    _shapes.clear();
    _shapes.addAll(newShapes);

    // Clear any pending operations since we're starting fresh from snapshot
    _pendingOperations.clear();
    _isDirty = false;

    // Start auto-sync timer if not already running
    _startSyncTimer();

    // Notify listeners
    _shapesController.add(shapes);
    _updateSyncStatus(SyncStatus.synced);

    VioLogger.debug(
      'GrpcCanvasRepository: Shapes set from snapshot: ${_shapes.map((s) => s.id).toList()}',
    );
  }

  /// Initialize repository with a project and branch
  Future<void> initialize({
    required String projectId,
    required String branchId,
  }) async {
    _projectId = projectId;
    _branchId = branchId;

    // Load initial state from server
    await _loadFromServer();

    // Start auto-sync timer
    _startSyncTimer();
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _debouncedSyncTimer?.cancel();
    // Attempt a final sync before disposing to avoid losing pending changes.
    if (_pendingOperations.isNotEmpty || _isDirty) {
      _syncToServer();
    }
    _shapesController.close();
    _syncStatusController.close();
  }

  /// Load canvas state from server via gRPC
  Future<void> _loadFromServer() async {
    if (_projectId == null || _branchId == null) return;

    // Skip loading if a branch switch is in progress - the VersionControlBloc
    // will load shapes directly from the snapshot and dispatch ShapesReplaced
    if (_isBranchSwitching) {
      VioLogger.debug(
        'GrpcCanvasRepository: Skipping _loadFromServer during branch switch',
      );
      return;
    }

    _updateSyncStatus(SyncStatus.loading);

    try {
      final request = pb.GetCanvasStateRequest()
        ..projectId = _projectId!
        ..branchId = _branchId!;

      final response = await _canvasClient.getCanvasState(request);

      _shapes.clear();
      for (final protoShape in response.state.shapes) {
        _shapes.add(ProtoConverter.shapeFromProto(protoShape));
      }
      _localVersion = response.state.version;
      _isDirty = false;
      _pendingOperations.clear();

      _shapesController.add(shapes);
      _updateSyncStatus(SyncStatus.synced);

      VioLogger.info(
        'GrpcCanvasRepository: Loaded ${_shapes.length} shapes (v$_localVersion)',
      );
    } on GrpcError catch (e) {
      VioLogger.error(
        'GrpcCanvasRepository: Failed to load canvas state - ${e.message}',
      );
      _updateSyncStatus(SyncStatus.error);
      rethrow;
    }
  }

  /// Add a shape locally and queue for sync.
  /// Triggers an immediate sync for shape creation since this is a
  /// high-value operation that should persist ASAP.
  void addShape(Shape shape) {
    _shapes.add(shape);
    _isDirty = true;

    _pendingOperations.add(
      _PendingOp(
        type: SyncOperationType.create,
        shapeId: shape.id,
        shape: shape,
        timestamp: DateTime.now(),
      ),
    );

    VioLogger.info(
      'GrpcCanvasRepository.addShape: queued CREATE for ${shape.id} '
      '(type=${shape.type}, pending=${_pendingOperations.length}, '
      'projectId=$_projectId, branchId=$_branchId)',
    );

    _shapesController.add(shapes);
    _updateSyncStatus(SyncStatus.pending);
    // Sync immediately for shape creation — don't debounce.
    _syncToServer();
  }

  /// Update a shape locally and queue for sync
  void updateShape(Shape shape) {
    final index = _shapes.indexWhere((s) => s.id == shape.id);
    if (index == -1) {
      VioLogger.warning(
        'GrpcCanvasRepository: Attempted to update non-existent shape: ${shape.id}',
      );
      return;
    }

    _shapes[index] = shape;
    _isDirty = true;

    // Remove any pending operations for this shape and add new one
    _pendingOperations.removeWhere((op) => op.shapeId == shape.id);
    _pendingOperations.add(
      _PendingOp(
        type: SyncOperationType.update,
        shapeId: shape.id,
        shape: shape,
        timestamp: DateTime.now(),
      ),
    );

    _shapesController.add(shapes);
    _updateSyncStatus(SyncStatus.pending);
    _scheduleDebouncedSync();
  }

  /// Delete a shape locally and queue for sync
  void deleteShape(String shapeId) {
    final index = _shapes.indexWhere((s) => s.id == shapeId);
    if (index == -1) {
      VioLogger.warning(
        'GrpcCanvasRepository: Attempted to delete non-existent shape: $shapeId',
      );
      return;
    }

    _shapes.removeAt(index);
    _isDirty = true;

    // Remove any pending operations for this shape and add delete
    _pendingOperations.removeWhere((op) => op.shapeId == shapeId);
    _pendingOperations.add(
      _PendingOp(
        type: SyncOperationType.delete,
        shapeId: shapeId,
        timestamp: DateTime.now(),
      ),
    );

    _shapesController.add(shapes);
    _updateSyncStatus(SyncStatus.pending);
    // Sync immediately for shape deletion.
    _syncToServer();
  }

  /// Update multiple shapes at once
  void updateShapes(List<Shape> updatedShapes) {
    for (final shape in updatedShapes) {
      updateShape(shape);
    }
  }

  /// Replace all shapes (for undo/redo or full sync)
  void setShapes(List<Shape> newShapes) {
    _shapes.clear();
    _shapes.addAll(newShapes);
    _isDirty = true;
    _shapesController.add(shapes);
    _updateSyncStatus(SyncStatus.pending);
  }

  /// Schedule a debounced sync shortly after a mutation so changes
  /// are persisted quickly without waiting for the full sync interval.
  /// Uses a very short delay to batch rapid consecutive mutations
  /// (e.g., moving a shape fires many updates) while still syncing
  /// almost immediately for single operations like shape creation.
  void _scheduleDebouncedSync() {
    _debouncedSyncTimer?.cancel();
    _debouncedSyncTimer = Timer(_debounceSyncDelay, _syncToServer);
  }

  /// Start the auto-sync timer
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => _syncToServer());
  }

  /// Sync pending changes to server via gRPC
  Future<void> _syncToServer() async {
    if (_projectId == null || _branchId == null) {
      VioLogger.warning(
        'GrpcCanvasRepository: _syncToServer skipped - projectId=$_projectId, branchId=$_branchId',
      );
      return;
    }
    if (_isSyncing) return;
    if (_pendingOperations.isEmpty && !_isDirty) return;

    // Skip syncing during branch switch to prevent race conditions
    if (_isBranchSwitching) {
      VioLogger.debug(
        'GrpcCanvasRepository: Skipping sync during branch switch',
      );
      return;
    }

    VioLogger.debug(
      'GrpcCanvasRepository: Syncing ${_pendingOperations.length} operations...',
    );

    _isSyncing = true;
    _updateSyncStatus(SyncStatus.syncing);

    try {
      final request = pb.SyncChangesRequest()
        ..projectId = _projectId!
        ..branchId = _branchId!
        ..localVersion = _localVersion;

      // Convert pending operations to proto
      for (final op in _pendingOperations) {
        request.operations.add(
          ProtoConverter.syncOperationToProto(
            op.type,
            op.shapeId,
            op.shape,
            op.timestamp,
            _projectId,
          ),
        );
      }

      final response = await _canvasClient.syncChanges(request);

      if (response.success) {
        _localVersion = response.serverVersion;
        _pendingOperations.clear();
        _isDirty = false;

        // If server returned shapes (conflict resolution), apply them
        if (response.shapes.isNotEmpty) {
          _shapes.clear();
          for (final protoShape in response.shapes) {
            _shapes.add(ProtoConverter.shapeFromProto(protoShape));
          }
          _shapesController.add(shapes);

          VioLogger.info(
            'GrpcCanvasRepository: Server resolved conflicts, updated to v$_localVersion',
          );
        }

        _updateSyncStatus(SyncStatus.synced);

        VioLogger.info(
          'GrpcCanvasRepository: Synced successfully (v$_localVersion)',
        );
      } else {
        VioLogger.warning('GrpcCanvasRepository: Sync failed');
        _updateSyncStatus(SyncStatus.error);
      }
    } on GrpcError catch (e) {
      VioLogger.error('GrpcCanvasRepository: Sync error - ${e.message}');
      _updateSyncStatus(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  /// Force an immediate sync
  Future<void> sync() async {
    await _syncToServer();
  }

  /// Refresh from server (discard local changes)
  Future<void> refresh() async {
    _pendingOperations.clear();
    await _loadFromServer();
  }

  /// Restore working copy from a snapshot (for branch switching)
  ///
  /// This replaces all shapes in the database with shapes from the specified
  /// snapshot, ensuring the working copy matches the target branch's state.
  Future<void> restoreFromSnapshot(String snapshotId) async {
    if (_projectId == null) {
      throw StateError('Repository not initialized');
    }

    VioLogger.info(
      'GrpcCanvasRepository: Restoring from snapshot $snapshotId',
    );

    _updateSyncStatus(SyncStatus.syncing);

    try {
      final request = pb.RestoreFromSnapshotRequest()
        ..projectId = _projectId!
        ..snapshotId = snapshotId;

      final response = await _canvasClient.restoreFromSnapshot(request);

      if (response.success) {
        // Clear pending operations since we just restored from a clean state
        _pendingOperations.clear();
        _isDirty = false;

        VioLogger.info(
          'GrpcCanvasRepository: Restored ${response.shapeCount} shapes from snapshot',
        );
        _updateSyncStatus(SyncStatus.synced);
      } else {
        VioLogger.warning(
          'GrpcCanvasRepository: Restore failed - ${response.message}',
        );
        _updateSyncStatus(SyncStatus.error);
      }
    } on GrpcError catch (e) {
      VioLogger.error(
        'GrpcCanvasRepository: Restore error - ${e.message}',
      );
      _updateSyncStatus(SyncStatus.error);
      rethrow;
    }
  }

  /// Clear working copy (for switching to empty branches)
  ///
  /// This removes all shapes from the database for the project.
  /// Used when switching to an empty branch with no commits.
  Future<void> clearWorkingCopy() async {
    if (_projectId == null) {
      throw StateError('Repository not initialized');
    }

    VioLogger.info('GrpcCanvasRepository: Clearing working copy');

    _updateSyncStatus(SyncStatus.syncing);

    try {
      final request = pb.ClearWorkingCopyRequest()..projectId = _projectId!;

      final response = await _canvasClient.clearWorkingCopy(request);

      if (response.success) {
        // Clear local state too
        _shapes.clear();
        _pendingOperations.clear();
        _isDirty = false;
        _shapesController.add(shapes);

        VioLogger.info(
          'GrpcCanvasRepository: Cleared ${response.deletedCount} shapes',
        );
        _updateSyncStatus(SyncStatus.synced);
      } else {
        VioLogger.warning(
          'GrpcCanvasRepository: Clear failed - ${response.message}',
        );
        _updateSyncStatus(SyncStatus.error);
      }
    } on GrpcError catch (e) {
      VioLogger.error(
        'GrpcCanvasRepository: Clear error - ${e.message}',
      );
      _updateSyncStatus(SyncStatus.error);
      rethrow;
    }
  }

  void _updateSyncStatus(SyncStatus status) {
    _currentStatus = status;
    _syncStatusController.add(status);
  }
}

/// Internal pending operation class
class _PendingOp {
  _PendingOp({
    required this.type,
    required this.shapeId,
    required this.timestamp,
    this.shape,
  });

  final SyncOperationType type;
  final String shapeId;
  final Shape? shape;
  final DateTime timestamp;
}

/// Sync status states
enum SyncStatus {
  /// Initial state, no operations pending
  idle,

  /// Loading initial data from server
  loading,

  /// Local changes pending sync
  pending,

  /// Currently syncing with server
  syncing,

  /// All changes synced
  synced,

  /// Sync error occurred
  error,
}
