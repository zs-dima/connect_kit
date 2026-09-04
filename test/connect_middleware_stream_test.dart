// [ConnectMiddleware] on streaming calls: the handler observes the whole stream, a failure before
// response headers fails the call itself, cancelling the response aborts the call through the child
// signal, and a consumer pause reaches the wire subscription.

import 'dart:async';

import 'package:connect_kit/connect_kit.dart';
import 'package:connectrpc/connect.dart';
import 'package:connectrpc/test.dart';
import 'package:test/test.dart';

int _zero() => 0;

const _kSpec = Spec<int, int>('/svc.v1.Service/List', .server, _zero, _zero);

/// Records the handler lifecycle and any error it observes, then rethrows.
class _StreamRecorder extends ConnectMiddleware {
  const _StreamRecorder(this.log);

  final List<String> log;

  @override
  ConnectMiddlewareHandler handle(ConnectMiddlewareHandler invoker) => (path, metadata) async {
    log.add('before');
    try {
      await invoker(path, metadata);
      log.add('after');
    } on ConnectException catch (e) {
      log.add('error:${e.code.name}');
      rethrow;
    }
  };
}

/// A [Transport] that hands the server stream to the interceptors as is. [FakeTransportBuilder]
/// bridges it through a controller that does not forward pause, so it cannot show whether the
/// middleware does.
final class _WireTransport implements Transport {
  const _WireTransport(this.messages, this.interceptors);

  final Stream<int> messages;
  final List<Interceptor> interceptors;

  @override
  Future<UnaryResponse<I, O>> unary<I extends Object, O extends Object>(
    Spec<I, O> spec,
    I input, [
    CallOptions? options,
  ]) => throw UnimplementedError();

  @override
  Future<StreamResponse<I, O>> stream<I extends Object, O extends Object>(
    Spec<I, O> spec,
    Stream<I> input, [
    CallOptions? options,
  ]) async {
    final request = StreamRequest<I, O>(
      spec,
      spec.procedure,
      Headers(),
      input,
      CancelableSignal(parent: options?.signal),
    );
    AnyFn<I, O> next = (_) async => StreamResponse<I, O>(spec, Headers(), messages as Stream<O>, Headers());
    // The last interceptor wraps the wire first, so the first one ends up outermost.
    for (final interceptor in interceptors.reversed) {
      next = interceptor<I, O>(next);
    }
    return await next(request) as StreamResponse<I, O>;
  }
}

void main() {
  group('ConnectMiddleware streaming', () {
    test('handler observes the whole stream (completes only after the last message)', () async {
      final log = <String>[];
      final transport = FakeTransportBuilder()
          .server(_kSpec, (req, context) => Stream.fromIterable([1, 2, 3]))
          .build(interceptors: [_StreamRecorder(log).call]);

      final events = <int>[];
      await for (final event in Client(transport).server(_kSpec, 0)) {
        events.add(event);
      }
      // The handler completes on the pump's onDone.
      await pumpEventQueue();

      expect(events, equals([1, 2, 3]));
      expect(log, equals(['before', 'after']));
    });

    test('handler observes a mid-stream error and the consumer still receives it', () async {
      final log = <String>[];
      final transport = FakeTransportBuilder()
          .server(_kSpec, (req, context) async* {
            yield 1;
            throw ConnectException(.unauthenticated, 'expired');
          })
          .build(interceptors: [_StreamRecorder(log).call]);

      final events = <int>[];
      await expectLater(
        // ignore: avoid-immediately-invoked-functions, expectLater needs the future already running.
        () async {
          await for (final event in Client(transport).server(_kSpec, 0)) {
            events.add(event);
          }
        }(),
        throwsA(isA<ConnectException>().having((e) => e.code, 'code', Code.unauthenticated)),
      );
      await pumpEventQueue();

      expect(events, equals([1]), reason: 'messages before the error are delivered');
      expect(log, equals(['before', 'error:unauthenticated']), reason: 'the handler sees the mid-stream error');
    });

    test('failure before response headers surfaces as a failure of the call itself', () async {
      final log = <String>[];
      final transport = FakeTransportBuilder()
          .server(_kSpec, (req, context) async* {
            throw ConnectException(.unavailable, 'down');
            // ignore: dead_code
            yield 0;
          })
          .build(interceptors: [_StreamRecorder(log).call]);

      await expectLater(
        transport.stream(_kSpec, Stream.value(0), const CallOptions()),
        throwsA(isA<ConnectException>().having((e) => e.code, 'code', Code.unavailable)),
      );
      await pumpEventQueue();

      expect(log, equals(['before', 'error:unavailable']));
    });

    test('consumer pause and resume reach the wire subscription', () async {
      var pausedAtSource = false;
      var resumedAtSource = false;
      final source = StreamController<int>(
        onPause: () => pausedAtSource = true,
        onResume: () => resumedAtSource = true,
      )..add(1);
      final log = <String>[];
      final transport = _WireTransport(source.stream, [_StreamRecorder(log).call]);

      final response = await transport.stream(_kSpec, Stream.value(0), const CallOptions());
      final sub = response.message.listen((_) {});
      await pumpEventQueue();

      sub.pause();
      await pumpEventQueue();
      expect(pausedAtSource, isTrue, reason: 'flow control needs the pause on the wire subscription');

      sub.resume();
      await pumpEventQueue();
      expect(resumedAtSource, isTrue);

      await source.close();
      await pumpEventQueue();
      await sub.cancel();
    });

    test('cancelling the response subscription aborts the call via the child signal', () async {
      final log = <String>[];
      final serverAborted = Completer<void>();
      final transport = FakeTransportBuilder()
          .server(_kSpec, (req, context) {
            // One value, then hang until aborted, like a live server stream.
            final controller = StreamController<int>()..add(1);
            context.signal.future.then((_) {
              if (!serverAborted.isCompleted) serverAborted.complete();
              controller.close().ignore();
            }).ignore();
            return controller.stream;
          })
          .build(interceptors: [_StreamRecorder(log).call]);

      final response = await transport.stream(_kSpec, Stream.value(0), const CallOptions());
      final received = Completer<int>();
      final sub = response.message.listen((event) {
        if (!received.isCompleted) received.complete(event);
      });

      expect(await received.future, equals(1));
      await sub.cancel();

      // The middleware forwards the request with a child CancelableSignal and cancels it when its
      // stream is cancelled; the fake wire observes the abort.
      await expectLater(serverAborted.future, completes);
      await pumpEventQueue();
      expect(log.first, equals('before'));
    });
  });
}
