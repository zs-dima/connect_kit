// The handler API is built on function typedefs, which the parameter-style lints below object to.
// ignore_for_file: type_annotate_public_apis, avoid_dynamic, avoid-dynamic, prefer-explicit-parameter-names, use_function_type_syntax_for_parameters, prefer-async-callback, prefer-explicit-function-type

import 'dart:async';

import 'package:connectrpc/connect.dart';

/// Invokes the call at [path] with [metadata] as its headers; it completes when the whole call
/// does, a streamed response included.
typedef ConnectMiddlewareHandler = Future<void> Function(String path, Map<String, String> metadata);

/// A middleware over a Connect call, in the shape HTTP middleware usually takes: one method wraps
/// the whole request and response flow. The generic [call] satisfies connectrpc's [Interceptor], so
/// an instance goes straight into a transport's `interceptors:` list, where the first entry is the
/// outermost layer.
abstract class ConnectMiddleware {
  /// Creates a Connect middleware instance.
  const ConnectMiddleware();

  /// Wraps a unary call. The handler adds to `metadata`, calls `invoker` to proceed and handles
  /// what it throws; `path` is the method path, `/package.Service/Method`.
  ///
  /// Example:
  /// ```dart
  /// ConnectMiddlewareHandler handle(ConnectMiddlewareHandler invoker) => (path, metadata) async {
  ///   metadata['Authorization'] = 'Bearer $token';
  ///   try {
  ///     await invoker(path, metadata);
  ///   } on ConnectException catch (e) {
  ///     // Handle error
  ///     rethrow;
  ///   }
  /// };
  /// ```
  ConnectMiddlewareHandler handle(ConnectMiddlewareHandler invoker);

  /// Wraps a streaming call. It falls back to [handle], so a middleware behaves the same either
  /// way unless it overrides this. A middleware that retries by calling `invoker` again has to
  /// override it: the request `Stream` cannot be listened to twice.
  ConnectMiddlewareHandler handleStreaming(ConnectMiddlewareHandler invoker) => handle(invoker);

  /// The [Interceptor] entry point: dispatches to the handler API and keeps its contract that the
  /// handler observes the whole call, every message and any mid-stream error included.
  AnyFn<I, O> call<I extends Object, O extends Object>(AnyFn<I, O> next) =>
      (req) => switch (req) {
        UnaryRequest<I, O>() => _interceptUnary(req, next),
        StreamRequest<I, O>() => _interceptStreaming(req, next),
      };

  /// The leading-slash `/package.Service/Method` form of a procedure name, so a set of paths
  /// matches whatever slash convention the code generator used.
  static String normalizePath(String procedure) => procedure.startsWith('/') ? procedure : '/$procedure';

  /// [headers] as a plain map; the last value wins for a repeated header. The map carries the
  /// protocol's own headers too (content-type, connect-protocol-version, connect-timeout-ms,
  /// user-agent), so a handler sees the full request, not only the custom entries.
  static Map<String, String> headersToMap(Headers headers) => <String, String>{
    for (final header in headers.entries) header.name: header.value,
  };

  /// [base] with every entry of [metadata] on top, so a handler's keys win.
  static Headers mergedHeaders(Headers base, Map<String, String> metadata) {
    final headers = Headers.from(base);
    for (final entry in metadata.entries) {
      headers[entry.key] = entry.value;
    }
    return headers;
  }

  Future<Response<I, O>> _interceptUnary<I extends Object, O extends Object>(
    UnaryRequest<I, O> req,
    AnyFn<I, O> next,
  ) async {
    Response<I, O>? response;
    final handler = handle((path, metadata) async {
      final request = metadata.isEmpty
          ? req
          : UnaryRequest<I, O>(req.spec, req.url, mergedHeaders(req.headers, metadata), req.message, req.signal);
      response = await next(request);
    });
    await handler(normalizePath(req.spec.procedure), headersToMap(req.headers));
    return response ?? (throw StateError('ConnectMiddleware.handle completed without invoking the request'));
  }

  Future<Response<I, O>> _interceptStreaming<I extends Object, O extends Object>(
    StreamRequest<I, O> req,
    AnyFn<I, O> next,
  ) {
    final out = Completer<Response<I, O>>();
    final controller = StreamController<O>();
    // The child signal goes into the forwarded request: cancelling it aborts the HTTP/2 stream,
    // while the caller's own signal still reaches it as the parent.
    final child = CancelableSignal(parent: req.signal);
    var cancelled = false;
    StreamSubscription<O>? sub;
    Completer<void>? done;

    // Cancellation is registered before any async work, so an unsubscribe that happens before the
    // call exists still aborts it: the flag is recorded and the invoker checks it the moment it
    // runs.
    controller.onCancel = () {
      cancelled = true;
      child.cancel();
      sub?.cancel().ignore();
      // Consumer walked away: let a still-waiting handler finish quietly (a signal-abort error
      // usually wins the race and surfaces as `canceled` instead).
      final pending = done;
      if (pending != null && !pending.isCompleted) pending.complete();
    };

    Future<void> execute() async {
      final handler = handleStreaming((path, metadata) async {
        if (cancelled) return; // unsubscribed before the call existed, so it never starts
        final request = StreamRequest<I, O>(
          req.spec,
          req.url,
          metadata.isEmpty ? req.headers : mergedHeaders(req.headers, metadata),
          req.message,
          child,
        );
        final res = await next(request) as StreamResponse<I, O>;

        // Publish the response at header time, so the caller can start consuming while this
        // handler and every outer middleware keep observing the whole stream, mid-stream errors
        // included.
        if (!out.isCompleted) {
          out.complete(StreamResponse<I, O>(res.spec, res.headers, controller.stream, res.trailers));
        }

        final finished = done = Completer<void>();
        final subscription = res.message.listen(
          (event) {
            if (!controller.isClosed) controller.add(event);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!finished.isCompleted) finished.completeError(error, stackTrace);
          },
          onDone: () {
            if (!finished.isCompleted) finished.complete();
          },
          cancelOnError: true,
        );
        sub = subscription;
        // Back-pressure, as far as this layer can carry it: the consumer's pause and resume reach
        // the wire subscription. Whether that reaches HTTP/2 flow control is the transport's
        // business — upstream connectrpc pumps frames into a StreamController without consulting
        // the consumer, so today it buffers instead (see the package README).
        controller
          ..onPause = subscription.pause
          ..onResume = subscription.resume;
        // A pause that arrived before the call existed. hasListener matters: with no listener
        // isPaused is true as well, and pausing then would freeze the source, since listening does
        // not call onResume.
        if (controller.hasListener && controller.isPaused) subscription.pause();
        if (cancelled) {
          // The consumer cancelled while the call was being created: abort the pump.
          await subscription.cancel();
          return;
        }
        await finished.future; // the handler awaits the full stream, so an error lands here
      });

      try {
        await handler(normalizePath(req.spec.procedure), headersToMap(req.headers));
      } on Object catch (error, stackTrace) {
        if (!out.isCompleted) {
          // A failure before the response headers is a failure of the call itself.
          out.completeError(error, stackTrace);
        } else if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        if (!out.isCompleted) {
          // The handler returned without invoking, after an early cancel or as a no-op: an empty
          // stream, closed below.
          out.complete(StreamResponse<I, O>(req.spec, Headers(), controller.stream, Headers()));
        }
        if (!controller.isClosed) await controller.close();
      }
    }

    unawaited(execute());

    return out.future;
  }
}
