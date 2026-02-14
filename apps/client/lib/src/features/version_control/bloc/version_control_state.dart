part of 'version_control_bloc.dart';

/// Status of version control operations
enum VersionControlStatus {
  initial,
  loading,
  ready,
  committing,
  switching,
  merging,
  error,
}

/// State for version control feature
class VersionControlState extends Equatable {
  const VersionControlState({
    this.status = VersionControlStatus.initial,
    this.projectId,
    this.userId,
    this.branches = const [],
    this.currentBranchId,
    this.commits = const [],
    this.pullRequests = const [],
    this.selectedPullRequest,
    this.selectedPullRequestDetail,
    this.branchComparison,
    this.uncommittedChanges = const [],
    this.stagedShapeIds = const {},
    this.baseShapes = const {},
    this.currentShapes = const {},
    this.pendingSwitchBranchId,
    this.pendingDeleteBranchId,
    this.error,
    this.isPolling = false,
  });

  final VersionControlStatus status;
  final String? projectId;
  final String? userId;
  final List<branch_pb.Branch> branches;
  final String? currentBranchId;
  final List<commit_pb.Commit> commits;
  final List<pr_pb.PullRequest> pullRequests;
  final pr_pb.PullRequest? selectedPullRequest;
  final PullRequestDetail? selectedPullRequestDetail;
  final BranchComparison? branchComparison;
  final List<ShapeChange> uncommittedChanges;
  final Set<String> stagedShapeIds;

  /// Shapes at the last commit (base for comparison)
  final Map<String, Shape> baseShapes;

  /// Current canvas shapes (for change detection)
  final Map<String, Shape> currentShapes;

  /// Branch ID pending switch confirmation (when uncommitted changes exist)
  final String? pendingSwitchBranchId;

  /// Branch ID pending delete confirmation
  final String? pendingDeleteBranchId;
  final String? error;
  final bool isPolling;

  /// Get current branch
  branch_pb.Branch? get currentBranch {
    if (currentBranchId == null) return null;
    return branches.firstWhere(
      (b) => b.id == currentBranchId,
      orElse: () => branches.first,
    );
  }

  /// Get default branch
  branch_pb.Branch? get defaultBranch {
    try {
      return branches.firstWhere((b) => b.isDefault);
    } catch (_) {
      return branches.isNotEmpty ? branches.first : null;
    }
  }

  /// Check if there are uncommitted changes
  bool get hasUncommittedChanges => uncommittedChanges.isNotEmpty;

  /// Get staged changes
  List<ShapeChange> get stagedChanges {
    return uncommittedChanges
        .where((c) => stagedShapeIds.contains(c.shapeId))
        .toList();
  }

  /// Check if can commit (has staged changes)
  bool get canCommit => stagedShapeIds.isNotEmpty;

  /// Get open pull requests
  List<pr_pb.PullRequest> get openPullRequests {
    return pullRequests
        .where((pr) => pr.isOpen)
        .toList();
  }

  /// Check if operation is in progress
  bool get isOperationInProgress =>
      status == VersionControlStatus.loading ||
      status == VersionControlStatus.committing ||
      status == VersionControlStatus.switching ||
      status == VersionControlStatus.merging;

  VersionControlState copyWith({
    VersionControlStatus? status,
    String? projectId,
    String? userId,
    List<branch_pb.Branch>? branches,
    String? currentBranchId,
    List<commit_pb.Commit>? commits,
    List<pr_pb.PullRequest>? pullRequests,
    pr_pb.PullRequest? selectedPullRequest,
    bool clearSelectedPullRequest = false,
    PullRequestDetail? selectedPullRequestDetail,
    bool clearSelectedPullRequestDetail = false,
    BranchComparison? branchComparison,
    bool clearBranchComparison = false,
    List<ShapeChange>? uncommittedChanges,
    Set<String>? stagedShapeIds,
    Map<String, Shape>? baseShapes,
    Map<String, Shape>? currentShapes,
    String? pendingSwitchBranchId,
    bool clearPendingSwitchBranchId = false,
    String? pendingDeleteBranchId,
    bool clearPendingDeleteBranchId = false,
    String? error,
    bool clearError = false,
    bool? isPolling,
  }) {
    return VersionControlState(
      status: status ?? this.status,
      projectId: projectId ?? this.projectId,
      userId: userId ?? this.userId,
      branches: branches ?? this.branches,
      currentBranchId: currentBranchId ?? this.currentBranchId,
      commits: commits ?? this.commits,
      pullRequests: pullRequests ?? this.pullRequests,
      selectedPullRequest: clearSelectedPullRequest
          ? null
          : (selectedPullRequest ?? this.selectedPullRequest),
      selectedPullRequestDetail: clearSelectedPullRequestDetail
          ? null
          : (selectedPullRequestDetail ?? this.selectedPullRequestDetail),
      branchComparison: clearBranchComparison
          ? null
          : (branchComparison ?? this.branchComparison),
      uncommittedChanges: uncommittedChanges ?? this.uncommittedChanges,
      stagedShapeIds: stagedShapeIds ?? this.stagedShapeIds,
      baseShapes: baseShapes ?? this.baseShapes,
      currentShapes: currentShapes ?? this.currentShapes,
      pendingSwitchBranchId: clearPendingSwitchBranchId
          ? null
          : (pendingSwitchBranchId ?? this.pendingSwitchBranchId),
      pendingDeleteBranchId: clearPendingDeleteBranchId
          ? null
          : (pendingDeleteBranchId ?? this.pendingDeleteBranchId),
      error: clearError ? null : (error ?? this.error),
      isPolling: isPolling ?? this.isPolling,
    );
  }

  @override
  List<Object?> get props => [
        status,
        projectId,
        userId,
        branches,
        currentBranchId,
        commits,
        pullRequests,
        selectedPullRequest,
        selectedPullRequestDetail,
        branchComparison,
        uncommittedChanges,
        stagedShapeIds,
        baseShapes,
        currentShapes,
        pendingSwitchBranchId,
        pendingDeleteBranchId,
        error,
        isPolling,
      ];
}
