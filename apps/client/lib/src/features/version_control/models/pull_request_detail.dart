import '../../../gen/vio/v1/branch.pb.dart' as branch_pb;
import '../../../gen/vio/v1/common.pb.dart' as common_pb;
import '../../../gen/vio/v1/pullrequest.pb.dart' as pr_pb;

/// Pull request detail with additional context (branches, conflicts, etc.)
///
/// Client-side composite assembled from multiple gRPC responses.
class PullRequestDetail {
  PullRequestDetail({
    required this.pullRequest,
    this.sourceBranch,
    this.targetBranch,
    this.mergeable = false,
    this.conflicts = const [],
    this.diffStats,
  });

  final pr_pb.PullRequest pullRequest;
  final branch_pb.Branch? sourceBranch;
  final branch_pb.Branch? targetBranch;
  final bool mergeable;
  final List<common_pb.ShapeConflict> conflicts;
  final DiffStats? diffStats;

  bool get hasConflicts => conflicts.isNotEmpty;
}

/// Diff statistics (client-computed)
class DiffStats {
  DiffStats({
    this.shapesAdded = 0,
    this.shapesModified = 0,
    this.shapesDeleted = 0,
  });

  final int shapesAdded;
  final int shapesModified;
  final int shapesDeleted;
}
