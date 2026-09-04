import 'package:connect_kit/src/client/http_client_io.dart'
    // ignore: uri_does_not_exist
    if (dart.library.js_interop) 'package:connect_kit/src/client/http_client_web.dart'
    // ignore: uri_does_not_exist
    if (dart.library.io) 'package:connect_kit/src/client/http_client_io.dart';
import 'package:connect_kit/src/client/transport_config.dart';
import 'package:connectrpc/connect.dart';
import 'package:connectrpc/protobuf.dart';
import 'package:connectrpc/protocol/connect.dart' as connect_protocol;

export 'package:connect_kit/src/client/http_client_io.dart'
    // ignore: uri_does_not_exist
    if (dart.library.js_interop) 'package:connect_kit/src/client/http_client_web.dart'
    // ignore: uri_does_not_exist
    if (dart.library.io) 'package:connect_kit/src/client/http_client_io.dart';

/// Creates a Connect-protocol [Transport] for [address], with binary protobuf on every platform;
/// swapping the codec makes it JSON.
///
/// One [RpcHttpClientHandle] is shared across transports so every service multiplexes the
/// per-origin HTTP/2 connections. [interceptors] wrap outermost first, in list order.
///
/// Compression is a transport option rather than a middleware. [acceptCompressions] defaults to
/// the platform's `defaultAcceptCompressions`: gzip response decoding on the VM, nothing on web.
/// [sendCompression] is off unless a deployment turns it on, for example with connectrpc's
/// `GzipCompression`.
Transport createConnectTransport(
  Uri address, {
  required RpcHttpClientHandle httpClient,
  List<Interceptor> interceptors = const [],
  Compression? sendCompression,
  List<Compression>? acceptCompressions,
}) => connect_protocol.Transport(
  baseUrl: address.toString(),
  codec: const ProtoCodec(),
  httpClient: httpClient.client,
  interceptors: interceptors,
  sendCompression: sendCompression,
  acceptCompressions: acceptCompressions ?? defaultAcceptCompressions,
);
