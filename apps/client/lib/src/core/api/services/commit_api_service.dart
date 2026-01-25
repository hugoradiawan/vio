import 'package:vio_core/vio_core.dart';

import '../api_client.dart';
import '../api_config.dart';
import '../dto.dart';

/// Service for commit-related API operations
class CommitApiService {
  CommitApiService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  /// Get all commits for a branch
  Future<List<CommitDto>> getCommits(
    String projectId,
    String branchId, {
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, dynamic>{};
    if (limit != null) queryParams['limit'] = limit;
    if (offset != null) queryParams['offset'] = offset;

    final response = await _client.get<List<dynamic>>(
      ApiConfig.endpoints.branchCommits(projectId, branchId),
      queryParameters: queryParams,
    );
    return response.data!
        .map((json) => CommitDto.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single commit by ID
  Future<CommitDto> getCommit(
    String projectId,
    String branchId,
    String commitId,
  ) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiConfig.endpoints.commit(projectId, branchId, commitId),
    );
    return CommitDto.fromJson(response.data!);
  }

  /// Create a new commit
  Future<CommitDto> createCommit({
    required String projectId,
    required String branchId,
    required String message,
    required String authorId,
    required List<Shape> shapes,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.endpoints.branchCommits(projectId, branchId),
      data: {
        'message': message,
        'authorId': authorId,
        'shapes': shapes.map((s) => s.toJson()).toList(),
      },
    );
    return CommitDto.fromJson(response.data!);
  }

  /// Get diff between two commits
  Future<DiffResultDto> getDiff(
    String projectId,
    String branchId,
    String commitId, {
    String? baseCommitId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (baseCommitId != null) queryParams['baseCommitId'] = baseCommitId;

    final response = await _client.get<Map<String, dynamic>>(
      ApiConfig.endpoints.commitDiff(projectId, branchId, commitId),
      queryParameters: queryParams,
    );
    return DiffResultDto.fromJson(response.data!);
  }

  /// Checkout a commit (restore canvas to that point)
  /// Returns the new branch created from that commit
  Future<BranchDto> checkoutCommit(
    String projectId,
    String branchId,
    String commitId, {
    required String newBranchName,
    required String userId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.endpoints.checkoutCommit(projectId, branchId, commitId),
      data: {
        'newBranchName': newBranchName,
        'userId': userId,
      },
    );
    return BranchDto.fromJson(response.data!['branch'] as Map<String, dynamic>);
  }

  /// Revert a commit (create inverse commit)
  Future<CommitDto> revertCommit(
    String projectId,
    String branchId,
    String commitId, {
    required String authorId,
    String? message,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.endpoints.revertCommit(projectId, branchId, commitId),
      data: {
        'authorId': authorId,
        if (message != null) 'message': message,
      },
    );
    return CommitDto.fromJson(
      response.data!['revertCommit'] as Map<String, dynamic>,
    );
  }

  /// Cherry-pick a commit to another branch
  Future<CommitDto> cherryPick(
    String projectId,
    String branchId,
    String commitId, {
    required String targetBranchId,
    required String authorId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.endpoints.cherryPick(projectId, branchId, commitId),
      data: {
        'targetBranchId': targetBranchId,
        'authorId': authorId,
      },
    );
    return CommitDto.fromJson(
      response.data!['newCommit'] as Map<String, dynamic>,
    );
  }
}
