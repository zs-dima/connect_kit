# connect_kit

[![CI](https://github.com/zs-dima/connect_kit/actions/workflows/ci.yml/badge.svg)](https://github.com/zs-dima/connect_kit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)

A Connect RPC runtime for Dart, built on `package:connectrpc`. It supplies the transport factory
with pinned TLS roots and keep-alive settings, a middleware contract that covers unary and streaming
calls with back-pressure, retry and metadata middlewares, conversions between Dart values and wire
types, and the protobuf well-known types.

## Features

- `createConnectTransport` over HTTP/2, with prior-knowledge h2c for `http` and a pinned
  `SecurityContext` for `https`; on web the browser's fetch stack.
- `ConnectMiddleware`: one handler wraps the whole call, so a middleware observes every message of a
  stream and any mid-stream error. Cancelling the response aborts the call through a child signal,
  and a consumer's pause reaches HTTP/2 flow control.
- `ConnectRetryMiddleware`: transient unary calls with full-jitter backoff, server pushback
  (`grpc-retry-pushback-ms`) and a total time budget.
- `ConnectMetadataMiddleware`: a fixed set of metadata entries on every call.
- The protobuf well-known types re-exported, and helpers for `Duration`, the wrapper messages and
  `ConnectException` messages.

## Install

```yaml
dependencies:
  connect_kit:
    git:
      url: https://github.com/zs-dima/connect_kit.git
      ref: v0.1.0
```

## Usage

```dart
import 'package:connect_kit/connect_kit.dart';

final http = createRpcHttpClient();
final transport = createConnectTransport(
  Uri.parse('https://api.example.com'),
  httpClient: http,
  interceptors: [
    ConnectMetadataMiddleware(metadata: const {'x-app-version': '1.0.0'}).call,
    ConnectRetryMiddleware(backoff: const RetryBackoff(maxRetries: 3)).call,
  ],
);
```

`transport` goes to a generated client, or to `Client(transport)` with a `Spec`. One
`RpcHttpClientHandle` is shared across transports, so every service multiplexes the per-origin
HTTP/2 connections; close it on teardown.

A middleware extends `ConnectMiddleware` and overrides `handle`:

```dart
class AuthMiddleware extends ConnectMiddleware {
  const AuthMiddleware(this.token);

  final String token;

  @override
  ConnectMiddlewareHandler handle(ConnectMiddlewareHandler invoker) => (path, metadata) async {
    metadata['authorization'] = 'Bearer $token';
    await invoker(path, metadata);
  };
}
```

## Middlewares

| Class | What it does |
|---|---|
| `ConnectMiddleware` | The base contract: `handle` for unary calls, `handleStreaming` for streams, and the `Interceptor` adapter that registers it on a transport. |
| `ConnectRetryMiddleware` | Retries transient unary calls with full-jitter backoff, honoring server pushback, a path opt-out list and a total budget. |
| `ConnectMetadataMiddleware` | Merges a fixed set of metadata entries into every call. |

The first interceptor in a transport's list is the outermost layer.

## Transport

`ConnectTransportConfig` carries the keep-alive ping interval and timeout, whether idle connections
are pinged, and the idle-connection timeout. `securityContextForAddress` decides TLS by URI scheme:
`https` and `wss` get the context pinned to `RootCertificates.trustedRoots`, everything else gets
plain h2c. The pinned set replaces the platform trust store, so a deployment served by another CA
passes its own roots.

Compression is a transport option rather than a middleware: `acceptCompressions` defaults to gzip
response decoding on the VM and nothing on web, and `sendCompression` is off unless a deployment
turns it on.

## Generated code

This package ships no service or message definitions. Generate them into the consumer that owns the
schema, and re-export the well-known types from here rather than depending on `package:protobuf`
directly.

## Changelog

[CHANGELOG.md](CHANGELOG.md)

## License

[MIT](LICENSE)
