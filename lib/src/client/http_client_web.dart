import 'package:connect_kit/src/client/transport_config.dart';
import 'package:connectrpc/connect.dart';
import 'package:connectrpc/web.dart';

/// Nothing is advertised on web: the browser's fetch stack negotiates content-encoding itself, and
/// per-message stream compression has no web implementation.
// ignore: prefer-prefixed-global-constants, the name matches the VM factory's.
const List<Compression> defaultAcceptCompressions = [];

/// The web HTTP client: the Connect protocol over the browser's fetch stack. The browser owns
/// connections, TLS and keep-alive, so [config] is not applied; the parameter only matches the VM
/// factory's signature.
RpcHttpClientHandle createRpcHttpClient({ConnectTransportConfig config = .defaultConfig}) => .new(createHttpClient());
