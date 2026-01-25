import 'package:flutter/foundation.dart';
import 'package:grpc/grpc_or_grpcweb.dart';

import '../../gen/vio/v1/auth.pbgrpc.dart';
import '../../gen/vio/v1/branch.pbgrpc.dart';
import '../../gen/vio/v1/canvas.pbgrpc.dart';
import '../../gen/vio/v1/commit.pbgrpc.dart';
import '../../gen/vio/v1/project.pbgrpc.dart';
import '../../gen/vio/v1/pullrequest.pbgrpc.dart';
import '../../gen/vio/v1/shape.pbgrpc.dart';

/// gRPC client configuration
class GrpcConfig {
  GrpcConfig._();

  /// Host for gRPC server in development
  static const String devHost = 'localhost';

  /// Port for gRPC server in development
  static const int devPort = 4000;

  /// Host for gRPC server in production
  static const String prodHost = 'api.vio.app';

  /// Port for gRPC server in production
  static const int prodPort = 443;

  /// Get appropriate host based on environment
  static String get host {
    const isProduction = bool.fromEnvironment('dart.vm.product');
    return isProduction ? prodHost : devHost;
  }

  /// Get appropriate port based on environment
  static int get port {
    const isProduction = bool.fromEnvironment('dart.vm.product');
    return isProduction ? prodPort : devPort;
  }

  /// Whether to use TLS
  static bool get useTls {
    const isProduction = bool.fromEnvironment('dart.vm.product');
    return isProduction;
  }
}

/// Singleton gRPC client manager
///
/// Provides access to all gRPC service clients and manages the channel.
class GrpcClient {
  GrpcClient._();

  static GrpcClient? _instance;

  /// Get the singleton instance
  static GrpcClient get instance => _instance ??= GrpcClient._();

  GrpcOrGrpcWebClientChannel? _channel;
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

    // Use GrpcOrGrpcWebClientChannel for cross-platform support
    // On web, this uses gRPC-Web; on native platforms, it uses native gRPC
    _channel = GrpcOrGrpcWebClientChannel.toSingleEndpoint(
      host: effectiveHost,
      port: effectivePort,
      transportSecure: effectiveUseTls,
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

    debugPrint('gRPC client initialized: $effectiveHost:$effectivePort (TLS: $effectiveUseTls)');
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
