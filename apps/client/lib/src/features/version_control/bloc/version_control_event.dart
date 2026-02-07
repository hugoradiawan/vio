part of 'version_control_bloc.dart';

/// Events for version control feature
sealed class VersionControlEvent extends Equatable {
  const VersionControlEvent();
}

/// Initialize version control with project context
class VersionControlInitialized extends VersionControlEvent {
  const VersionControlInitialized({
    required this.projectId,
    required this.userId,
  });

  final String projectId;
  final String userId;

  @override
  List<Object?> get props => [projectId, userId];
}

/// Start polling for updates
class VersionControlPollingStarted extends VersionControlEvent {
  const VersionControlPollingStarted();

  @override
  List<Object?> get props => [];
}

/// Stop polling for updates
class VersionControlPollingStopped extends VersionControlEvent {
  const VersionControlPollingStopped();

  @override
  List<Object?> get props => [];
}

/// Refresh branches list
class BranchesRefreshRequested extends VersionControlEvent {
  const BranchesRefreshRequested();

  @override
  List<Object?> get props => [];
}

/// Switch to a different branch
class BranchSwitchRequested extends VersionControlEvent {
  const BranchSwitchRequested({
    required this.branchId,
    this.forceDiscard = false,
  });

  final String branchId;

  /// If true, discard uncommitted changes without prompting
  final bool forceDiscard;

  @override
  List<Object?> get props => [branchId, forceDiscard];
}

/// Confirm branch switch (discard uncommitted changes)
class BranchSwitchConfirmed extends VersionControlEvent {
  const BranchSwitchConfirmed();

  @override
  List<Object?> get props => [];
}

/// Cancel pending branch switch
class BranchSwitchCanceled extends VersionControlEvent {
  const BranchSwitchCanceled();

  @override
  List<Object?> get props => [];
}

/// Create a new branch
class BranchCreateRequested extends VersionControlEvent {
  const BranchCreateRequested({
    required this.name,
    this.description,
    this.sourceBranchId,
  });

  final String name;
  final String? description;
  final String? sourceBranchId;

  @override
  List<Object?> get props => [name, description, sourceBranchId];
}

/// Delete a branch (shows confirmation if needed)
class BranchDeleteRequested extends VersionControlEvent {
  const BranchDeleteRequested({
    required this.branchId,
    this.forceDelete = false,
  });

  final String branchId;

  /// If true, delete without confirmation
  final bool forceDelete;

  @override
  List<Object?> get props => [branchId, forceDelete];
}

/// Confirm branch deletion after user acknowledges
class BranchDeleteConfirmed extends VersionControlEvent {
  const BranchDeleteConfirmed();

  @override
  List<Object?> get props => [];
}

/// Cancel pending branch deletion
class BranchDeleteCanceled extends VersionControlEvent {
  const BranchDeleteCanceled();

  @override
  List<Object?> get props => [];
}

/// Refresh commits for current branch
class CommitsRefreshRequested extends VersionControlEvent {
  const CommitsRefreshRequested();

  @override
  List<Object?> get props => [];
}

/// Create a new commit
class CommitCreateRequested extends VersionControlEvent {
  const CommitCreateRequested({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Checkout a specific commit
class CommitCheckoutRequested extends VersionControlEvent {
  const CommitCheckoutRequested({
    required this.commitId,
    required this.newBranchName,
  });

  final String commitId;
  final String newBranchName;

  @override
  List<Object?> get props => [commitId, newBranchName];
}

/// Revert a commit
class CommitRevertRequested extends VersionControlEvent {
  const CommitRevertRequested({required this.commitId, this.message});

  final String commitId;
  final String? message;

  @override
  List<Object?> get props => [commitId, message];
}

/// Refresh pull requests list
class PullRequestsRefreshRequested extends VersionControlEvent {
  const PullRequestsRefreshRequested({this.status});

  final PullRequestStatus? status;

  @override
  List<Object?> get props => [status];
}

/// Create a pull request
class PullRequestCreateRequested extends VersionControlEvent {
  const PullRequestCreateRequested({
    required this.sourceBranchId,
    required this.targetBranchId,
    required this.title,
    this.description,
  });

  final String sourceBranchId;
  final String targetBranchId;
  final String title;
  final String? description;

  @override
  List<Object?> get props =>
      [sourceBranchId, targetBranchId, title, description];
}

/// Select a pull request for viewing
class PullRequestSelected extends VersionControlEvent {
  const PullRequestSelected({required this.pullRequestId});

  final String pullRequestId;

  @override
  List<Object?> get props => [pullRequestId];
}

/// Merge a pull request
class PullRequestMergeRequested extends VersionControlEvent {
  const PullRequestMergeRequested({
    required this.pullRequestId,
    this.strategy = MergeStrategy.mergeCommit,
    this.commitMessage,
  });

  final String pullRequestId;
  final MergeStrategy strategy;
  final String? commitMessage;

  @override
  List<Object?> get props => [pullRequestId, strategy, commitMessage];
}

/// Close a pull request
class PullRequestCloseRequested extends VersionControlEvent {
  const PullRequestCloseRequested({required this.pullRequestId});

  final String pullRequestId;

  @override
  List<Object?> get props => [pullRequestId];
}

/// Resolve conflicts for a pull request
class ConflictsResolveRequested extends VersionControlEvent {
  const ConflictsResolveRequested({
    required this.pullRequestId,
    required this.resolutions,
  });

  final String pullRequestId;
  final List<ConflictResolutionDto> resolutions;

  @override
  List<Object?> get props => [pullRequestId, resolutions];
}

/// Compare two branches
class BranchCompareRequested extends VersionControlEvent {
  const BranchCompareRequested({
    required this.baseBranchId,
    required this.headBranchId,
  });

  final String baseBranchId;
  final String headBranchId;

  @override
  List<Object?> get props => [baseBranchId, headBranchId];
}

/// Mark shapes as staged for commit
class ShapesStagedForCommit extends VersionControlEvent {
  const ShapesStagedForCommit({required this.shapeIds});

  final List<String> shapeIds;

  @override
  List<Object?> get props => [shapeIds];
}

/// Clear staged shapes
class StagedShapesCleared extends VersionControlEvent {
  const StagedShapesCleared();

  @override
  List<Object?> get props => [];
}

/// Canvas shapes changed - update uncommitted changes
class CanvasShapesChanged extends VersionControlEvent {
  const CanvasShapesChanged({required this.shapes});

  final Map<String, Shape> shapes;

  @override
  List<Object?> get props => [shapes];
}

/// Set the base shapes (from last commit snapshot)
class BaseShapesLoaded extends VersionControlEvent {
  const BaseShapesLoaded({required this.shapes});

  final Map<String, Shape> shapes;

  @override
  List<Object?> get props => [shapes];
}

/// Discard a specific shape change (revert to base state)
class ShapeChangeDiscarded extends VersionControlEvent {
  const ShapeChangeDiscarded({required this.shapeId});

  final String shapeId;

  @override
  List<Object?> get props => [shapeId];
}

/// Commit current changes and then switch to a target branch
class CommitAndSwitchRequested extends VersionControlEvent {
  const CommitAndSwitchRequested({
    required this.message,
    required this.targetBranchId,
  });

  final String message;
  final String targetBranchId;

  @override
  List<Object?> get props => [message, targetBranchId];
}

/// Update branch name, description, or protection status
class BranchUpdateRequested extends VersionControlEvent {
  const BranchUpdateRequested({
    required this.branchId,
    this.name,
    this.description,
    this.isProtected,
  });

  final String branchId;
  final String? name;
  final String? description;
  final bool? isProtected;

  @override
  List<Object?> get props => [branchId, name, description, isProtected];
}
