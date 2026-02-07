import 'package:flutter/foundation.dart';
import 'package:grpc/grpc_connection_interface.dart';

import '../../gen/vio/v1/auth.pbgrpc.dart';
import '../../gen/vio/v1/branch.pbgrpc.dart';
import '../../gen/vio/v1/canvas.pbgrpc.dart';
import '../../gen/vio/v1/commit.pbgrpc.dart';
import '../../gen/vio/v1/project.pbgrpc.dart';
import '../../gen/vio/v1/pullrequest.pbgrpc.dart';
import '../../gen/vio/v1/shape.pbgrpc.dart';
import '../config/app_config.dart';
import 'grpc_channel.dart';

/// gRPC client configuration
///
/// Reads values from [AppConfig] which is populated via
/// `--dart-define-from-file` at build time.
class GrpcConfig {
  GrpcConfig._();

  static AppConfig? _config;

  /// Configure from [AppConfig]. Called once during app startup.
  static void configure(AppConfig config) {
    _config = config;
  }

  static AppConfig get _effectiveConfig =>
      _config ?? AppConfig.fromEnvironment();

  /// Get appropriate host based on environment
  static String get host => _effectiveConfig.grpcHost;

  /// Get appropriate port based on environment and platform
  static int get port {
    final config = _effectiveConfig;
    if (config.isDevelopment) {
      // In development: web uses grpcWebPort (HTTP/1.1), native uses grpcPort (HTTP/2)
      return kIsWeb ? config.grpcWebPort : config.grpcPort;
    }
    return kIsWeb ? config.grpcWebPort : config.grpcPort;
  }

  /// Whether to use TLS
  static bool get useTls => _effectiveConfig.useTls;
}

/// Singleton gRPC client manager
///
/// Provides access to all gRPC service clients and manages the channel.
class GrpcClient {
  GrpcClient._();

  static GrpcClient? _instance;

  /// Get the singleton instance
  static GrpcClient get instance => _instance ??= GrpcClient._();

  ClientChannelBase? _channel;
  bool _initialized = false;

  // Service clients
  AuthServiceClient? _authClient;
  ProjectServiceClient? _projectClient;
  BranchServiceClient? _branchClient;
  CommitServiceClient? _commitClient;
  ShapeServiceClient? _shapeClient;
  CanvasServiceClient? _canvasClient;
  PullRequestServiceClient? _pullRequestClient;

  /// Initialize the gRPC channel and clients
  void initialize({
    String? host,
    int? port,
    bool? useTls,
  }) {
    if (_initialized) return;

    final effectiveHost = host ?? GrpcConfig.host;
    final effectivePort = port ?? GrpcConfig.port;
    final effectiveUseTls = useTls ?? GrpcConfig.useTls;

    // Use platform-specific channel factory
    // - Web: GrpcWebClientChannel (gRPC-Web over HTTP/1.1)
    // - Desktop/Mobile: ClientChannel (native gRPC over HTTP/2)
    _channel = createGrpcChannel(
      host: effectiveHost,
      port: effectivePort,
      useTls: effectiveUseTls,
    );

    // Initialize all service clients
    _authClient = AuthServiceClient(_channel!);
    _projectClient = ProjectServiceClient(_channel!);
    _branchClient = BranchServiceClient(_channel!);
    _commitClient = CommitServiceClient(_channel!);
    _shapeClient = ShapeServiceClient(_channel!);
    _canvasClient = CanvasServiceClient(_channel!);
    _pullRequestClient = PullRequestServiceClient(_channel!);

    _initialized = true;

    debugPrint(
      'gRPC client initialized: $effectiveHost:$effectivePort (TLS: $effectiveUseTls) [kIsWeb: $kIsWeb]',
    );
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'GrpcClient not initialized. Call GrpcClient.instance.initialize() first.',
      );
    }
  }

  /// Get the auth service client
  AuthServiceClient get authClient {
    _ensureInitialized();
    return _authClient!;
  }

  /// Get the project service client
  ProjectServiceClient get projectClient {
    _ensureInitialized();
    return _projectClient!;
  }

  /// Get the branch service client
  BranchServiceClient get branchClient {
    _ensureInitialized();
    return _branchClient!;
  }

  /// Get the commit service client
  CommitServiceClient get commitClient {
    _ensureInitialized();
    return _commitClient!;
  }

  /// Get the shape service client
  ShapeServiceClient get shapeClient {
    _ensureInitialized();
    return _shapeClient!;
  }

  /// Get the canvas service client
  CanvasServiceClient get canvasClient {
    _ensureInitialized();
    return _canvasClient!;
  }

  /// Get the pull request service client
  PullRequestServiceClient get pullRequestClient {
    _ensureInitialized();
    return _pullRequestClient!;
  }

  /// Shutdown the gRPC channel
  Future<void> shutdown() async {
    if (_channel != null) {
      await _channel!.shutdown();
      _channel = null;
    }
    _initialized = false;
    _authClient = null;
    _projectClient = null;
    _branchClient = null;
    _commitClient = null;
    _shapeClient = null;
    _canvasClient = null;
    _pullRequestClient = null;
  }
}
