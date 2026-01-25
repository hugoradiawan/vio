import '../api_client.dart';
import '../api_config.dart';
import '../dto.dart';

/// Service for branch-related API operations
class BranchApiService {
  BranchApiService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  /// Get all branches for a project
  Future<List<BranchDto>> getBranches(String projectId) async {
    final response = await _client.get<List<dynamic>>(
      ApiConfig.endpoints.projectBranches(projectId),
    );
    return response.data!
        .map((json) => BranchDto.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single branch by ID
  Future<BranchDto> getBranch(String projectId, String branchId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiConfig.endpoints.branch(projectId, branchId),
    );
    return BranchDto.fromJson(response.data!);
  }

  /// Create a new branch
  Future<BranchDto> createBranch({
    required String projectId,
    required String name,
    required String createdById,
    String? description,
    String? sourceBranchId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.endpoints.projectBranches(projectId),
      data: {
        'name': name,
        'description': description,
        'createdById': createdById,
        'sourceBranchId': sourceBranchId,
      },
    );
    return BranchDto.fromJson(response.data!);
  }

  /// Update a branch
  Future<BranchDto> updateBranch(
    String projectId,
    String branchId, {
    String? name,
    String? description,
    bool? isProtected,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      ApiConfig.endpoints.branch(projectId, branchId),
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (isProtected != null) 'isProtected': isProtected,
      },
    );
    return BranchDto.fromJson(response.data!);
  }

  /// Delete a branch
  Future<void> deleteBranch(String projectId, String branchId) async {
    await _client.delete<void>(ApiConfig.endpoints.branch(projectId, branchId));
  }

  /// Merge branches directly (without PR)
  Future<MergeBranchResultDto> mergeBranches({
    required String projectId,
    required String sourceBranchId,
    required String targetBranchId,
    required String mergedById,
    MergeStrategy strategy = MergeStrategy.mergeCommit,
    String? commitMessage,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.endpoints.mergeBranches(projectId),
      data: {
        'sourceBranchId': sourceBranchId,
        'targetBranchId': targetBranchId,
        'mergedById': mergedById,
        'strategy': strategy.name.toUpperCase(),
        if (commitMessage != null) 'commitMessage': commitMessage,
      },
    );
    return MergeBranchResultDto.fromJson(response.data!);
  }

  /// Compare two branches (ahead/behind, conflicts)
  Future<BranchComparisonDto> compareBranches({
    required String projectId,
    required String baseBranchId,
    required String headBranchId,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiConfig.endpoints.compareBranches(projectId),
      queryParameters: {
        'baseBranchId': baseBranchId,
        'headBranchId': headBranchId,
      },
    );
    return BranchComparisonDto.fromJson(response.data!);
  }
}

/// Result of merging branches
class MergeBranchResultDto {
  MergeBranchResultDto({
    required this.success,
    required this.targetBranch,
    this.mergeCommit,
    this.message,
  });

  factory MergeBranchResultDto.fromJson(Map<String, dynamic> json) {
    return MergeBranchResultDto(
      success: json['success'] as bool? ?? true,
      targetBranch: BranchDto.fromJson(
        json['targetBranch'] as Map<String, dynamic>,
      ),
      mergeCommit: json['mergeCommit'] != null
          ? CommitDto.fromJson(json['mergeCommit'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }

  final bool success;
  final BranchDto targetBranch;
  final CommitDto? mergeCommit;
  final String? message;
}
