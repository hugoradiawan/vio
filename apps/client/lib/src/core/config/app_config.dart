/// Application configuration based on build-time environment defines.
///
/// Values are injected via `--dart-define-from-file` using JSON config files
/// in `apps/client/config/` (dev.json, staging.json, production.json).
///
/// Example:
/// ```bash
/// flutter run --dart-define-from-file=config/dev.json
/// ```
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.grpcHost,
    required this.grpcPort,
    required this.grpcWebPort,
    required this.useTls,
  });

  /// Create config from compile-time `--dart-define` values.
  ///
  /// Falls back to development defaults if no defines are provided.
  factory AppConfig.fromEnvironment() {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const grpcHost = String.fromEnvironment('GRPC_HOST');
    const grpcPort = int.fromEnvironment('GRPC_PORT');
    const grpcWebPort = int.fromEnvironment('GRPC_WEB_PORT');
    const useTls = bool.fromEnvironment('USE_TLS');

    final environment = AppEnvironment.fromString(env);

    return AppConfig(
      environment: environment,
      apiBaseUrl: apiBaseUrl.isNotEmpty
          ? apiBaseUrl
          : environment.defaultApiBaseUrl,
      grpcHost:
          grpcHost.isNotEmpty ? grpcHost : environment.defaultGrpcHost,
      grpcPort: grpcPort != 0 ? grpcPort : environment.defaultGrpcPort,
      grpcWebPort:
          grpcWebPort != 0 ? grpcWebPort : environment.defaultGrpcWebPort,
      useTls: grpcHost.isNotEmpty ? useTls : environment.defaultUseTls,
    );
  }

  final AppEnvironment environment;
  final String apiBaseUrl;
  final String grpcHost;
  final int grpcPort;
  final int grpcWebPort;
  final bool useTls;

  bool get isProduction => environment == AppEnvironment.production;
  bool get isDevelopment => environment == AppEnvironment.dev;
  bool get isStaging => environment == AppEnvironment.staging;

  @override
  String toString() =>
      'AppConfig(env: ${environment.name}, api: $apiBaseUrl, '
      'grpc: $grpcHost:$grpcPort, tls: $useTls)';
}

/// Application environment
enum AppEnvironment {
  dev,
  staging,
  production;

  factory AppEnvironment.fromString(String value) {
    return switch (value.toLowerCase()) {
      'production' || 'prod' => AppEnvironment.production,
      'staging' || 'stg' => AppEnvironment.staging,
      _ => AppEnvironment.dev,
    };
  }

  String get defaultApiBaseUrl => switch (this) {
        AppEnvironment.dev => 'http://localhost:4000/api',
        AppEnvironment.staging => 'https://staging-api.vio.app/api',
        AppEnvironment.production => 'https://api.vio.app/api',
      };

  String get defaultGrpcHost => switch (this) {
        AppEnvironment.dev => 'localhost',
        AppEnvironment.staging => 'staging-api.vio.app',
        AppEnvironment.production => 'api.vio.app',
      };

  int get defaultGrpcPort => switch (this) {
        AppEnvironment.dev => 4000,
        AppEnvironment.staging => 443,
        AppEnvironment.production => 443,
      };

  int get defaultGrpcWebPort => switch (this) {
        AppEnvironment.dev => 4001,
        AppEnvironment.staging => 443,
        AppEnvironment.production => 443,
      };

  bool get defaultUseTls => switch (this) {
        AppEnvironment.dev => false,
        AppEnvironment.staging => true,
        AppEnvironment.production => true,
      };
}
