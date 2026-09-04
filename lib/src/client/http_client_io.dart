import 'dart:convert';
import 'dart:io';

import 'package:connect_kit/src/client/root_certificates.dart';
import 'package:connect_kit/src/client/transport_config.dart';
import 'package:connect_kit/src/tool/uri_tool.dart';
import 'package:connectrpc/connect.dart';
import 'package:connectrpc/http2.dart';
import 'package:connectrpc/io.dart' show GzipCompression;

/// The compressions the client advertises and can decode in responses (`accept-encoding` and
/// `connect-accept-encoding`), so the server may gzip what it sends back. Compressing the request
/// is a separate opt-in through `createConnectTransport`.
final List<Compression> defaultAcceptCompressions = [GzipCompression()];

/// TLS by URI scheme: `https` and `wss` get the context pinned to [RootCertificates.trustedRoots],
/// `http` and `ws` get plain h2c. Public and pure, so the trust decision is testable without a real
/// client. connectrpc branches on the same scheme and consults the [SecurityContext] only for TLS
/// origins, which is why the shared client below can always carry the pinned context.
SecurityContext? securityContextForAddress(Uri address) => address.ssl ? rpcSecurityContext() : null;

/// A [SecurityContext] without the system roots, carrying [RootCertificates.trustedRoots] instead.
/// The pinned set replaces the platform trust store, so it has to cover every CA the backends can
/// serve, fallback hosts included.
SecurityContext rpcSecurityContext() =>
    // ignore: prefer-returning-shorthands, `.new` here is redundant to the analyzer.
    SecurityContext(withTrustedRoots: false)..setTrustedCertificatesBytes(utf8.encode(RootCertificates.trustedRoots));

/// The native HTTP client: HTTP/2 with prior-knowledge h2c for `http`, pinned TLS for `https`, and
/// the keep-alive and idle behaviour from [config].
RpcHttpClientHandle createRpcHttpClient({ConnectTransportConfig config = .defaultConfig}) => .new(
  createHttpClient(
    transport: Http2ClientTransport(
      context: rpcSecurityContext(),
      pingInterval: config.pingInterval,
      pingTimeout: config.pingTimeout,
      pingIdleConnections: config.pingIdleConnections,
      idleConnectionTimeout: config.idleConnectionTimeout,
    ),
  ),
);
