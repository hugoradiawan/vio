import 'api/api.dart';
import 'repositories/repositories.dart';

/// Service locator for API services
///
/// Provides singleton instances of API services throughout the app.
/// Initialize in main() before runApp().
class ServiceLocator {
  ServiceLocator._();

  static ServiceLocator? _instance;
  static ServiceLocator get instance => _instance ??= ServiceLocator._();

  late final ApiClient _apiClient;
  late final ProjectApiService _projectService;
  late final BranchApiService _branchService;
  late final CanvasApiService _canvasService;
  late final CanvasRepository _canvasRepository;

  bool _initialized = false;

  /// Initialize all services
  void initialize() {
    if (_initialized) return;

    _apiClient = ApiClient(baseUrl: ApiConfig.baseUrl);
    _projectService = ProjectApiService(apiClient: _apiClient);
    _branchService = BranchApiService(apiClient: _apiClient);
    _canvasService = CanvasApiService(apiClient: _apiClient);
    _canvasRepository = CanvasRepository(canvasService: _canvasService);

    _initialized = true;
  }

  /// Get the API client
  ApiClient get apiClient {
    _ensureInitialized();
    return _apiClient;
  }

  /// Get the project API service
  ProjectApiService get projectService {
    _ensureInitialized();
    return _projectService;
  }

  /// Get the branch API service
  BranchApiService get branchService {
    _ensureInitialized();
    return _branchService;
  }

  /// Get the canvas API service
  CanvasApiService get canvasService {
    _ensureInitialized();
    return _canvasService;
  }

  /// Get the canvas repository
  CanvasRepository get canvasRepository {
    _ensureInitialized();
    return _canvasRepository;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'ServiceLocator not initialized. Call ServiceLocator.instance.initialize() first.',
      );
    }
  }

  /// Dispose all services (call on app shutdown)
  void dispose() {
    if (_initialized) {
      _canvasRepository.dispose();
    }
  }
}
