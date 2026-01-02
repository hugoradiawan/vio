/// API configuration constants
class ApiConfig {
  ApiConfig._();

  /// Base URL for the API in development
  static const String devBaseUrl = 'http://localhost:4000/api';

  /// Base URL for the API in production (to be configured)
  static const String prodBaseUrl = 'https://api.vio.app/api';

  /// Get the appropriate base URL based on environment
  static String get baseUrl {
    // TODO: Use proper environment detection
    const isProduction = bool.fromEnvironment('dart.vm.product');
    return isProduction ? prodBaseUrl : devBaseUrl;
  }

  /// API endpoints
  static const ApiEndpoints endpoints = ApiEndpoints._();
}

/// API endpoint paths
class ApiEndpoints {
  const ApiEndpoints._();

  // Project endpoints
  String get projects => '/projects';
  String project(String id) => '/projects/$id';

  // Branch endpoints
  String projectBranches(String projectId) => '/projects/$projectId/branches';
  String branch(String projectId, String branchId) =>
      '/projects/$projectId/branches/$branchId';

  // Commit endpoints
  String branchCommits(String projectId, String branchId) =>
      '/projects/$projectId/branches/$branchId/commits';
  String commit(String projectId, String branchId, String commitId) =>
      '/projects/$projectId/branches/$branchId/commits/$commitId';

  // Shape endpoints (project-level)
  String projectShapes(String projectId) => '/projects/$projectId/shapes';
  String projectShape(String projectId, String shapeId) =>
      '/projects/$projectId/shapes/$shapeId';

  // Canvas state endpoint (get current canvas state for a branch)
  String canvasState(String projectId, String branchId) =>
      '/projects/$projectId/branches/$branchId/canvas';

  // Sync endpoint (for auto-sync operations)
  String sync(String projectId, String branchId) =>
      '/projects/$projectId/branches/$branchId/sync';
}
