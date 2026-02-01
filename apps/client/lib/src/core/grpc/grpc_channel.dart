/// Platform-agnostic gRPC channel factory
///
/// Uses conditional imports to select the correct implementation:
/// - Web: GrpcWebClientChannel (uses XHR/fetch)
/// - Desktop/Mobile: ClientChannel (uses native sockets)
library;
export 'grpc_channel_native.dart' if (dart.library.html) 'grpc_channel_web.dart';
