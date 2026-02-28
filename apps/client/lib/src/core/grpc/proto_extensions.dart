import '../../gen/vio/v1/branch.pb.dart' as branch_pb;
import '../../gen/vio/v1/commit.pb.dart' as commit_pb;
import '../../gen/vio/v1/common.pb.dart' as common_pb;
import '../../gen/vio/v1/common.pbenum.dart' as common_enum;
import '../../gen/vio/v1/pullrequest.pb.dart' as pr_pb;
import '../../gen/vio/v1/pullrequest.pbenum.dart' as pr_enum;

// ============================================================================
// Timestamp Extensions
// ============================================================================

extension TimestampExt on common_pb.Timestamp {
  /// Convert proto Timestamp to Dart DateTime.
  DateTime toDateTime() => DateTime.fromMillisecondsSinceEpoch(millis.toInt());
}

/// Convert a nullable Timestamp to DateTime?.
/// Returns null if the timestamp is null or has no millis set.
DateTime? timestampToDateTime(common_pb.Timestamp? ts) {
  if (ts == null || !ts.hasMillis()) return null;
  return ts.toDateTime();
}

// ============================================================================
// Branch Extensions
// ============================================================================

extension BranchExt on branch_pb.Branch {
  DateTime? get createdAtDateTime => timestampToDateTime(createdAt);
  DateTime? get updatedAtDateTime => timestampToDateTime(updatedAt);

  /// Returns null if description is empty.
  String? get descriptionOrNull => description.isEmpty ? null : description;

  /// Returns null if headCommitId is empty.
  String? get headCommitIdOrNull => headCommitId.isEmpty ? null : headCommitId;
}

// ============================================================================
// Commit Extensions
// ============================================================================

extension CommitExt on commit_pb.Commit {
  DateTime get createdAtDateTime => createdAt.toDateTime();

  /// Returns null if parentId is empty.
  String? get parentIdOrNull => parentId.isEmpty ? null : parentId;
}

// ============================================================================
// PullRequest Extensions
// ============================================================================

extension PullRequestExt on pr_pb.PullRequest {
  DateTime get createdAtDateTime => createdAt.toDateTime();
  DateTime get updatedAtDateTime => updatedAt.toDateTime();
  DateTime? get mergedAtDateTime => timestampToDateTime(mergedAt);
  DateTime? get closedAtDateTime => timestampToDateTime(closedAt);

  /// Returns null if description is empty.
  String? get descriptionOrNull => description.isEmpty ? null : description;

  /// Check if pull request is open.
  bool get isOpen =>
      status == pr_enum.PullRequestStatus.PULL_REQUEST_STATUS_OPEN;

  /// Check if pull request is merged.
  bool get isMerged =>
      status == pr_enum.PullRequestStatus.PULL_REQUEST_STATUS_MERGED;

  /// Check if pull request is closed.
  bool get isClosed =>
      status == pr_enum.PullRequestStatus.PULL_REQUEST_STATUS_CLOSED;
}

// ============================================================================
// Enum Display Extensions
// ============================================================================

extension PullRequestStatusDisplay on pr_enum.PullRequestStatus {
  String get displayName => switch (this) {
        pr_enum.PullRequestStatus.PULL_REQUEST_STATUS_OPEN => 'Open',
        pr_enum.PullRequestStatus.PULL_REQUEST_STATUS_MERGED => 'Merged',
        pr_enum.PullRequestStatus.PULL_REQUEST_STATUS_CLOSED => 'Closed',
        _ => 'Unknown',
      };
}

extension MergeStrategyDisplay on common_enum.MergeStrategy {
  String get displayName => switch (this) {
        common_enum.MergeStrategy.MERGE_STRATEGY_MERGE_COMMIT => 'Merge Commit',
        common_enum.MergeStrategy.MERGE_STRATEGY_SQUASH => 'Squash',
        common_enum.MergeStrategy.MERGE_STRATEGY_FAST_FORWARD => 'Fast Forward',
        _ => 'Unknown',
      };
}

extension ResolutionChoiceDisplay on common_enum.ResolutionChoice {
  String get displayName => switch (this) {
        common_enum.ResolutionChoice.RESOLUTION_CHOICE_SOURCE => 'Source',
        common_enum.ResolutionChoice.RESOLUTION_CHOICE_TARGET => 'Target',
        common_enum.ResolutionChoice.RESOLUTION_CHOICE_CUSTOM => 'Custom',
        _ => 'Unknown',
      };
}
