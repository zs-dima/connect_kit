import 'package:connectrpc/connect.dart';

/// Base class for Connect RPC clients: the shared [Transport] and the per-call deadline defaults.
/// A deadline is a per-call `TimeoutSignal` rather than a stub option, and it bounds the whole
/// logical call, retries included; the server still enforces its own per-attempt deadline.
abstract class ConnectClient {
  /// Default deadline for a unary call. Every unary call carries one, and this is where the value
  /// lives.
  static const Duration defaultCallTimeout = Duration(seconds: 30);

  /// Deadline for a server-streaming call. It bounds the whole call, so it has to be generous
  /// enough not to truncate a large but finite stream; each streaming call passes it explicitly.
  static const Duration streamCallTimeout = Duration(minutes: 5);

  const ConnectClient(this.transport);

  /// The transport carrying this client's calls; interceptors are registered on it.
  ///
  /// Connections belong to the shared [RpcHttpClientHandle], so a client holds nothing to shut
  /// down.
  final Transport transport;
}
