import '../../../gen/vio/v1/common.pb.dart' as common_pb;

/// Branch comparison result (client-side composite from CompareBranchesResponse)
class BranchComparison {
  BranchComparison({
    required this.commitsAhead,
    required this.commitsBehind,
    required this.canFastForward,
    this.baseBranchId,
    this.headBranchId,
    this.conflicts = const [],
  });

  final String? baseBranchId;
  final String? headBranchId;
  final int commitsAhead;
  final int commitsBehind;
  final List<common_pb.ShapeConflict> conflicts;
  final bool canFastForward;

  bool get hasConflicts => conflicts.isNotEmpty;
}
