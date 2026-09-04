import 'package:connectrpc/connect.dart';

/// Keep-alive and idle settings for the HTTP/2 client behind the Connect transports.
class ConnectTransportConfig {
  static const defaultConfig = ConnectTransportConfig();

  const ConnectTransportConfig({
    this.pingInterval,
    this.pingTimeout = const Duration(minutes: 5),
    this.pingIdleConnections = false,
    this.idleConnectionTimeout = const Duration(minutes: 15),
  });

  /// Interval between keep-alive pings. Null disables client-initiated keep-alive; set it to keep
  /// idle HTTP/2 connections warm. Keep it in minutes: aggressive pinging can earn a server
  /// `GOAWAY`.
  final Duration? pingInterval;

  /// How long to wait for a ping ack before the connection counts as dead. It applies only when
  /// [pingInterval] is set, since without an interval no ping is sent.
  final Duration pingTimeout;

  /// Whether keep-alive pings also go out on idle connections.
  final bool pingIdleConnections;

  /// Closes a connection when the time since its last request stream exceeds this value.
  final Duration idleConnectionTimeout;

  // connectrpc has no connection-establishment timeout: setup is bounded by the per-call deadline,
  // which belongs to the call rather than the transport.
}

/// Owns the platform HTTP client shared by the transports: create one, pass it to every
/// `createConnectTransport`, close it on teardown. One handle lets every service multiplex the
/// per-origin HTTP/2 connections.
final class RpcHttpClientHandle {
  const RpcHttpClientHandle(this.client);

  /// The connect-dart HTTP client function backing the transports.
  final HttpClient client;

  /// Releases the underlying connections. connectrpc exposes no close API, so this is a no-op and
  /// idle connections are reaped through [ConnectTransportConfig.idleConnectionTimeout]. It stays
  /// the single disposal point, so a future connectrpc can close for real without rewiring.
  Future<void> close() async {}
}
