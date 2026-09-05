// Compression on the Connect transport is a TRANSPORT-LEVEL OPTION, not an interceptor:
// `sendCompression:` / `acceptCompressions:` on `createConnectTransport` (the `Compression`
// interface from `package:connectrpc`; `GzipCompression` ships with it for VM platforms).
// Response DECODING is on by default through the platform `defaultAcceptCompressions` (gzip on the
// VM), so a server may compress what it sends back. SEND-side compression stays off unless a
// deployment turns it on.
//
// This file therefore exports nothing. It is kept because the question "where did the compression
// middleware go" has a real answer, and because the interceptor below is the shape a per-call
// compression policy would take if the transport option ever proves too coarse.
//
// ```dart
// /// {@template grpc_compression_middleware}
// /// Middleware for enabling gzip compression on gRPC requests.
// /// {@endtemplate}
// @immutable
// class GrpcCompressionMiddleware extends ClientInterceptor {
//   /// {@macro grpc_compression_middleware}
//   GrpcCompressionMiddleware({Codec codec = const GzipCodec()}) : _options = CallOptions(compression: codec);
//
//   final CallOptions _options;
//
//   @override
//   ResponseFuture<R> interceptUnary<Q, R>(
//     ClientMethod<Q, R> method,
//     Q request,
//     CallOptions options,
//     ClientUnaryInvoker<Q, R> invoker,
//   ) => invoker(method, request, options.mergedWith(_options));
//
//   @override
//   ResponseStream<R> interceptStreaming<Q, R>(
//     ClientMethod<Q, R> method,
//     Stream<Q> requests,
//     CallOptions options,
//     ClientStreamingInvoker<Q, R> invoker,
//   ) => invoker(method, requests, options.mergedWith(_options));
// }
// ```
