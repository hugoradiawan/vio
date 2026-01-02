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
    required String createdById, String? description,
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
}
