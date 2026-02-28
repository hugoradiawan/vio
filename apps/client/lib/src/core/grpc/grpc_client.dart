import 'package:flutter/foundation.dart';
import 'package:grpc/grpc_connection_interface.dart';
import 'package:grpc/service_api.dart' as grpc_api;

import '../../gen/vio/v1/asset.pbgrpc.dart';
import '../../gen/vio/v1/auth.pbgrpc.dart';
import '../../gen/vio/v1/branch.pbgrpc.dart';
import '../../gen/vio/v1/canvas.pbgrpc.dart';
import '../../gen/vio/v1/commit.pbgrpc.dart';
import '../../gen/vio/v1/project.pbgrpc.dart';
import '../../gen/vio/v1/pullrequest.pbgrpc.dart';
import '../../gen/vio/v1/shape.pbgrpc.dart';
import '../auth/token_storage.dart';
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
  AssetServiceClient? _assetClient;
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

    // Initialize all service clients with auth interceptor
    final interceptors = [_authInterceptor];
    _assetClient = AssetServiceClient(_channel!, interceptors: interceptors);
    _authClient =
        AuthServiceClient(_channel!); // No auth needed for auth service
    _projectClient =
        ProjectServiceClient(_channel!, interceptors: interceptors);
    _branchClient = BranchServiceClient(_channel!, interceptors: interceptors);
    _commitClient = CommitServiceClient(_channel!, interceptors: interceptors);
    _shapeClient = ShapeServiceClient(_channel!, interceptors: interceptors);
    _canvasClient = CanvasServiceClient(_channel!, interceptors: interceptors);
    _pullRequestClient =
        PullRequestServiceClient(_channel!, interceptors: interceptors);

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

  // ============== Auth Token Management ==============

  String? _authToken;
  Future<bool>? _ongoingTokenRefresh;

  /// The auth interceptor used by all service clients.
  late final _AuthInterceptor _authInterceptor = _AuthInterceptor(this);

  /// Set the auth token to be included in all subsequent gRPC calls.
  void setAuthToken(String token) {
    _authToken = token;
    debugPrint('[GrpcClient] Auth token set');
  }

  /// Clear the auth token (on logout).
  void clearAuthToken() {
    _authToken = null;
    debugPrint('[GrpcClient] Auth token cleared');
  }

  /// Refresh access token using stored refresh token.
  ///
  /// Coalesces concurrent refresh attempts into one request.
  Future<bool> refreshAuthToken() {
    final ongoing = _ongoingTokenRefresh;
    if (ongoing != null) {
      return ongoing;
    }

    final refreshFuture = _refreshAuthTokenInternal();
    _ongoingTokenRefresh = refreshFuture;

    return refreshFuture.whenComplete(() {
      if (identical(_ongoingTokenRefresh, refreshFuture)) {
        _ongoingTokenRefresh = null;
      }
    });
  }

  Future<bool> _refreshAuthTokenInternal() async {
    try {
      final refreshToken = await TokenStorage.instance.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('[GrpcClient] Token refresh skipped: no refresh token');
        return false;
      }

      final response = await authClient.refreshToken(
        RefreshTokenRequest()..refreshToken = refreshToken,
      );

      await TokenStorage.instance.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );

      setAuthToken(response.accessToken);
      debugPrint('[GrpcClient] Access token refreshed');
      return true;
    } catch (error) {
      debugPrint('[GrpcClient] Token refresh failed: $error');
      await TokenStorage.instance.clearTokens();
      clearAuthToken();
      return false;
    }
  }

  /// Get the asset service client
  AssetServiceClient get assetClient {
    _ensureInitialized();
    return _assetClient!;
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
    _assetClient = null;
    _authClient = null;
    _projectClient = null;
    _branchClient = null;
    _commitClient = null;
    _shapeClient = null;
    _canvasClient = null;
    _pullRequestClient = null;
  }
}

/// gRPC client interceptor that attaches the auth token to every request.
///
/// Reads the token from the parent [GrpcClient] at call time so it
/// always reflects the current auth state (login/logout).
class _AuthInterceptor extends grpc_api.ClientInterceptor {
  _AuthInterceptor(this._grpcClient);

  final GrpcClient _grpcClient;

  @override
  grpc_api.ResponseFuture<R> interceptUnary<Q, R>(
    grpc_api.ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
    grpc_api.ClientUnaryInvoker<Q, R> invoker,
  ) {
    final newOptions = _applyAuth(options);
    return invoker(method, request, newOptions);
  }

  @override
  grpc_api.ResponseStream<R> interceptStreaming<Q, R>(
    grpc_api.ClientMethod<Q, R> method,
    Stream<Q> requests,
    CallOptions options,
    grpc_api.ClientStreamingInvoker<Q, R> invoker,
  ) {
    final newOptions = _applyAuth(options);
    return invoker(method, requests, newOptions);
  }

  CallOptions _applyAuth(CallOptions existing) {
    final token = _grpcClient._authToken;
    if (token == null) return existing;
    return existing.mergedWith(
      CallOptions(metadata: {'authorization': 'Bearer $token'}),
    );
  }
}
