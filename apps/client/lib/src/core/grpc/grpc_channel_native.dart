import 'package:grpc/grpc.dart';
import 'package:grpc/grpc_connection_interface.dart';

/// Creates a native gRPC channel for Desktop/Mobile platforms.
/// Uses HTTP/2 with native TCP sockets.
///
/// For development without TLS, requires the server to support HTTP/2 cleartext (h2c).
/// For production, use TLS for both security and protocol negotiation.
ClientChannelBase createGrpcChannel({
  required String host,
  required int port,
  required bool useTls,
}) {
  return ClientChannel(
    host,
    port: port,
    options: ChannelOptions(
      credentials: useTls
          ? const ChannelCredentials.secure()
          : const ChannelCredentials.insecure(),
    ),
  );
}
