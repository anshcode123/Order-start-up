import 'package:scanserve/core/network/dio_client.dart';

/// Socket.IO attaches directly to the same HTTP server the REST API
/// uses (see backend/server.js) but at its own default path
/// ("/socket.io/"), not under "/api" - so this strips the path off
/// [kApiBaseUrl] and keeps just the origin.
final String kSocketBaseUrl = () {
  final uri = Uri.parse(kApiBaseUrl);
  return Uri(scheme: uri.scheme, host: uri.host, port: uri.port).toString();
}();
