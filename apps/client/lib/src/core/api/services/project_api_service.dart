import '../api_client.dart';
import '../api_config.dart';
import '../dto.dart';

/// Service for project-related API operations
class ProjectApiService {
  ProjectApiService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  /// Get all projects for the current user
  Future<List<ProjectDto>> getProjects() async {
    final response = await _client.get<List<dynamic>>(
      ApiConfig.endpoints.projects,
    );
    return response.data!
        .map((json) => ProjectDto.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single project by ID
  Future<ProjectDto> getProject(String id) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiConfig.endpoints.project(id),
    );
    return ProjectDto.fromJson(response.data!);
  }

  /// Create a new project
  Future<ProjectDto> createProject({
    required String name,
    required String ownerId,
    String? description,
    String? teamId,
    bool isPublic = false,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.endpoints.projects,
      data: {
        'name': name,
        'description': description,
        'ownerId': ownerId,
        'teamId': teamId,
        'isPublic': isPublic,
      },
    );
    return ProjectDto.fromJson(response.data!);
  }

  /// Update a project
  Future<ProjectDto> updateProject(
    String id, {
    String? name,
    String? description,
    bool? isPublic,
    String? defaultBranchId,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      ApiConfig.endpoints.project(id),
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (isPublic != null) 'isPublic': isPublic,
        if (defaultBranchId != null) 'defaultBranchId': defaultBranchId,
      },
    );
    return ProjectDto.fromJson(response.data!);
  }

  /// Delete a project
  Future<void> deleteProject(String id) async {
    await _client.delete<void>(ApiConfig.endpoints.project(id));
  }
}
