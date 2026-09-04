// ignore_for_file: avoid_print, an example prints to show the result.

import 'package:connect_kit/connect_kit.dart';
import 'package:connectrpc/connect.dart';

/// A middleware that attaches a bearer token to every call.
class AuthMiddleware extends ConnectMiddleware {
  const AuthMiddleware(this.token);

  final String token;

  @override
  ConnectMiddlewareHandler handle(ConnectMiddlewareHandler invoker) => (path, metadata) async {
    metadata['authorization'] = 'Bearer $token';
    await invoker(path, metadata);
  };
}

Future<void> main() async {
  final httpClient = createRpcHttpClient(config: const ConnectTransportConfig(pingInterval: Duration(minutes: 1)));

  final transport = createConnectTransport(
    Uri.parse('https://api.example.com'),
    httpClient: httpClient,
    interceptors: [
      ConnectMetadataMiddleware(metadata: const {'x-app-version': '1.0.0'}).call,
      const AuthMiddleware('token').call,
      ConnectRetryMiddleware(backoff: const RetryBackoff(maxRetries: 3)).call,
    ],
  );

  // A generated client takes the transport; with a hand-written Spec it looks like this.
  const spec = Spec<Empty, Empty>('/example.v1.ExampleService/Ping', .unary, Empty.create, Empty.create);
  try {
    await Client(transport).unary(spec, Empty());
  } on ConnectException catch (e) {
    print(e.detail('Ping failed'));
  } finally {
    await httpClient.close();
  }
}
