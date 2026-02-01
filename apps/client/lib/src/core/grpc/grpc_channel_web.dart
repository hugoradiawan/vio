import 'package:grpc/grpc_connection_interface.dart';
import 'package:grpc/grpc_web.dart';

/// Creates a gRPC channel for web platform
/// Uses gRPC-Web over HTTP/1.1 with XHR
ClientChannelBase createGrpcChannel({
  required String host,
  required int port,
  required bool useTls,
}) {
  final protocol = useTls ? 'https' : 'http';
  return GrpcWebClientChannel.xhr(
    Uri.parse('$protocol://$host:$port'),
  );
}
