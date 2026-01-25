import '../api_client.dart';
import '../api_config.dart';
import '../dto.dart';

/// Service for pull request API operations
class PullRequestApiService {
  PullRequestApiService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  /// List all pull requests for a project
  Future<List<PullRequestDto>> getPullRequests(
    String projectId, {
    PullRequestStatus? status,
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null) queryParams['status'] = status.name;
    if (limit != null) queryParams['limit'] = limit;
    if (offset != null) queryParams['offset'] = offset;

    final response = await _client.get<List<dynamic>>(
      ApiConfig.endpoints.pullRequests(projectId),
      queryParameters: queryParams,
    );
    return response.data!
        .map((json) => PullRequestDto.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single pull request
  Future<PullRequestDto> getPullRequest(String projectId, String prId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiConfig.endpoints.pullRequest(projectId, prId),
    );
    return PullRequestDto.fromJson(response.data!);
  }

  /// Get pull request with full details (diff, conflicts)
  Future<PullRequestDetailDto> getPullRequestDetail(
    String projectId,
    String prId,
  ) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiConfig.endpoints.pullRequest(projectId, prId),
      queryParameters: {'detail': true},
    );
    return PullRequestDetailDto.fromJson(response.data!);
  }

  /// Create a new pull request
  Future<PullRequestDto> createPullRequest({
    required String projectId,
    required String sourceBranchId,
    required String targetBranchId,
    required String title,
    required String authorId,
    String? description,
    List<String>? reviewerIds,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.endpoints.pullRequests(projectId),
      data: {
        'sourceBranchId': sourceBranchId,
        'targetBranchId': targetBranchId,
        'title': title,
        'authorId': authorId,
        if (description != null) 'description': description,
        if (reviewerIds != null) 'reviewerIds': reviewerIds,
      },
    );
    return PullRequestDto.fromJson(
      response.data!['pullRequest'] as Map<String, dynamic>,
    );
  }

  /// Update a pull request
  Future<PullRequestDto> updatePullRequest(
    String projectId,
    String prId, {
    String? title,
    String? description,
    List<String>? reviewerIds,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      ApiConfig.endpoints.pullRequest(projectId, prId),
      data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (reviewerIds != null) 'reviewerIds': reviewerIds,
      },
    );
    return PullRequestDto.fromJson(
      response.data!['pullRequest'] as Map<String, dynamic>,
    );
  }

  /// Merge a pull request
  Future<MergePullRequestResultDto> mergePullRequest(
    String projectId,
    String prId, {
    required String mergedById,
    MergeStrategy strategy = MergeStrategy.mergeCommit,
    String? commitMessage,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.endpoints.mergePullRequest(projectId, prId),
      data: {
        'mergedById': mergedById,
        'strategy': strategy.name.toUpperCase(),
        if (commitMessage != null) 'commitMessage': commitMessage,
      },
    );
    return MergePullRequestResultDto.fromJson(response.data!);
  }

  /// Close a pull request without merging
  Future<PullRequestDto> closePullRequest(String projectId, String prId) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.endpoints.closePullRequest(projectId, prId),
    );
    return PullRequestDto.fromJson(
      response.data!['pullRequest'] as Map<String, dynamic>,
    );
  }

  /// Reopen a closed pull request
  Future<PullRequestDto> reopenPullRequest(
    String projectId,
    String prId,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.endpoints.reopenPullRequest(projectId, prId),
    );
    return PullRequestDto.fromJson(
      response.data!['pullRequest'] as Map<String, dynamic>,
    );
  }

  /// Check merge status (conflicts, ahead/behind)
  Future<MergeStatusDto> checkMergeStatus(
    String projectId,
    String prId,
  ) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiConfig.endpoints.checkMergeStatus(projectId, prId),
    );
    return MergeStatusDto.fromJson(response.data!);
  }

  /// Resolve conflicts for a pull request
  Future<PullRequestDto> resolveConflicts(
    String projectId,
    String prId, {
    required List<ConflictResolutionDto> resolutions,
    required String resolvedById,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.endpoints.resolveConflicts(projectId, prId),
      data: {
        'resolutions': resolutions.map((r) => r.toJson()).toList(),
        'resolvedById': resolvedById,
      },
    );
    return PullRequestDto.fromJson(
      response.data!['pullRequest'] as Map<String, dynamic>,
    );
  }
}

/// Pull request with full details including diff and conflicts
class PullRequestDetailDto {
  PullRequestDetailDto({
    required this.pullRequest,
    required this.diff,
    required this.conflicts,
    required this.mergeable,
  });

  factory PullRequestDetailDto.fromJson(Map<String, dynamic> json) {
    return PullRequestDetailDto(
      pullRequest: PullRequestDto.fromJson(
        json['pullRequest'] as Map<String, dynamic>,
      ),
      diff: json['diff'] != null
          ? DiffResultDto.fromJson(json['diff'] as Map<String, dynamic>)
          : null,
      conflicts: (json['conflicts'] as List<dynamic>?)
              ?.map((e) => ShapeConflictDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      mergeable: json['mergeable'] as bool? ?? false,
    );
  }

  final PullRequestDto pullRequest;
  final DiffResultDto? diff;
  final List<ShapeConflictDto> conflicts;
  final bool mergeable;

  bool get hasConflicts => conflicts.isNotEmpty;
}

/// Result of merging a pull request
class MergePullRequestResultDto {
  MergePullRequestResultDto({
    required this.pullRequest,
    this.mergeCommit,
  });

  factory MergePullRequestResultDto.fromJson(Map<String, dynamic> json) {
    return MergePullRequestResultDto(
      pullRequest: PullRequestDto.fromJson(
        json['pullRequest'] as Map<String, dynamic>,
      ),
      mergeCommit: json['mergeCommit'] != null
          ? CommitDto.fromJson(json['mergeCommit'] as Map<String, dynamic>)
          : null,
    );
  }

  final PullRequestDto pullRequest;
  final CommitDto? mergeCommit;
}
