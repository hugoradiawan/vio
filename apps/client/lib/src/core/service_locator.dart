import '../gen/vio/v1/asset.pbgrpc.dart';
import '../gen/vio/v1/auth.pbgrpc.dart';
import '../gen/vio/v1/branch.pbgrpc.dart';
import '../gen/vio/v1/canvas.pbgrpc.dart';
import '../gen/vio/v1/commit.pbgrpc.dart';
import '../gen/vio/v1/project.pbgrpc.dart';
import '../gen/vio/v1/pullrequest.pbgrpc.dart';
import '../gen/vio/v1/shape.pbgrpc.dart';
import 'config/app_config.dart';
import 'grpc/grpc.dart';
import 'repositories/repositories.dart';
import 'services/preferences_service.dart';

/// Service locator for gRPC services
///
/// Provides singleton instances of gRPC service clients throughout the app.
/// Initialize in main() before runApp().
class ServiceLocator {
  ServiceLocator._();

  static ServiceLocator? _instance;
  static ServiceLocator get instance => _instance ??= ServiceLocator._();

  late final GrpcClient _grpcClient;
  late final AssetServiceClient _assetService;
  late final AuthServiceClient _authService;
  late final ProjectServiceClient _projectService;
  late final BranchServiceClient _branchService;
  late final CanvasServiceClient _canvasService;
  late final CommitServiceClient _commitService;
  late final PullRequestServiceClient _pullRequestService;
  late final ShapeServiceClient _shapeService;
  late final GrpcCanvasRepository _canvasRepository;
  late final PreferencesService _preferencesService;

  bool _initialized = false;

  /// Initialize all services
  ///
  /// Accepts an optional [AppConfig] for environment-specific settings.
  /// If not provided, defaults are resolved from `--dart-define` values.
  Future<void> initialize({AppConfig? config}) async {
    if (_initialized) return;

    final effectiveConfig = config ?? AppConfig.fromEnvironment();

    // Configure environment-aware singletons
    GrpcConfig.configure(effectiveConfig);

    // Initialize preferences service first (no dependencies)
    _preferencesService = PreferencesService.instance;
    await _preferencesService.initialize();

    // Initialize gRPC client (singleton)
    _grpcClient = GrpcClient.instance;
    _grpcClient.initialize(
      host: effectiveConfig.grpcHost,
      port: GrpcConfig.port,
    );

    // Get gRPC service clients
    _assetService = _grpcClient.assetClient;
    _authService = _grpcClient.authClient;
    _projectService = _grpcClient.projectClient;
    _branchService = _grpcClient.branchClient;
    _canvasService = _grpcClient.canvasClient;
    _commitService = _grpcClient.commitClient;
    _pullRequestService = _grpcClient.pullRequestClient;
    _shapeService = _grpcClient.shapeClient;

    // Create repositories
    _canvasRepository = GrpcCanvasRepository(canvasClient: _canvasService);

    _initialized = true;
  }

  /// Get the gRPC client
  GrpcClient get grpcClient {
    _ensureInitialized();
    return _grpcClient;
  }

  /// Get the asset gRPC service client
  AssetServiceClient get assetService {
    _ensureInitialized();
    return _assetService;
  }

  /// Get the auth gRPC service client
  AuthServiceClient get authService {
    _ensureInitialized();
    return _authService;
  }

  /// Get the project gRPC service client
  ProjectServiceClient get projectService {
    _ensureInitialized();
    return _projectService;
  }

  /// Get the branch gRPC service client
  BranchServiceClient get branchService {
    _ensureInitialized();
    return _branchService;
  }

  /// Get the canvas gRPC service client
  CanvasServiceClient get canvasService {
    _ensureInitialized();
    return _canvasService;
  }

  /// Get the shape gRPC service client
  ShapeServiceClient get shapeService {
    _ensureInitialized();
    return _shapeService;
  }

  /// Get the canvas repository
  GrpcCanvasRepository get canvasRepository {
    _ensureInitialized();
    return _canvasRepository;
  }

  /// Get the commit gRPC service client
  CommitServiceClient get commitService {
    _ensureInitialized();
    return _commitService;
  }

  /// Get the pull request gRPC service client
  PullRequestServiceClient get pullRequestService {
    _ensureInitialized();
    return _pullRequestService;
  }

  /// Get the preferences service
  PreferencesService get preferencesService {
    _ensureInitialized();
    return _preferencesService;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'ServiceLocator not initialized. Call ServiceLocator.instance.initialize() first.',
      );
    }
  }

  /// Dispose all services (call on app shutdown)
  Future<void> dispose() async {
    if (_initialized) {
      _canvasRepository.dispose();
      await _grpcClient.shutdown();
    }
  }
}
