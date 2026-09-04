// Pins the order in which interceptors are applied. The transport folds `interceptors.reversed`,
// so the first element of the list is the outermost layer and sees the request first; the
// upstream wording, "the interceptor at the end of the array is applied first", describes the
// wrapping rather than the request order. A connectrpc upgrade that flips the fold fails here.

import 'package:connect_kit/connect_kit.dart';
import 'package:connectrpc/connect.dart';
import 'package:connectrpc/test.dart';
import 'package:test/test.dart';

int _zero() => 0;

const _kSpec = Spec<int, int>('/svc.v1.Service/Method', .unary, _zero, _zero);

/// Handler-based recorder (the [ConnectMiddleware] contract used by logger/metadata/sentry/auth).
class _Recorder extends ConnectMiddleware {
  const _Recorder(this.name, this.log);

  final String name;
  final List<String> log;

  @override
  ConnectMiddlewareHandler handle(ConnectMiddlewareHandler invoker) => (path, metadata) async {
    log.add('$name:before');
    await invoker(path, {...metadata, name: 'seen'});
    log.add('$name:after');
  };
}

/// Raw-contract recorder (the [Interceptor] shape used by retry).
class _RawRecorder {
  const _RawRecorder(this.name, this.log);

  final String name;
  final List<String> log;

  AnyFn<I, O> call<I extends Object, O extends Object>(AnyFn<I, O> next) => (req) async {
    log.add('$name:before');
    final res = await next(req);
    log.add('$name:after');
    return res;
  };
}

void main() {
  test('first interceptor in the list is the outermost layer (both contracts)', () async {
    final log = <String>[];
    Headers? wireHeaders;

    final transport = FakeTransportBuilder()
        .unary(_kSpec, (req, context) {
          log.add('wire');
          wireHeaders = context.requestHeaders;
          return 2;
        })
        .build(
          interceptors: [
            _Recorder('outer', log).call,
            _RawRecorder('mid', log).call,
            _Recorder('inner', log).call,
          ],
        );

    final result = await Client(transport).unary(_kSpec, 1);

    expect(result, equals(2));
    expect(
      log,
      equals(['outer:before', 'mid:before', 'inner:before', 'wire', 'inner:after', 'mid:after', 'outer:after']),
      reason: 'list order must be outermost → innermost',
    );
    // Metadata added by the handler-based middleware reaches the wire (merge direction pinned).
    expect(wireHeaders?['outer'], equals('seen'));
    expect(wireHeaders?['inner'], equals('seen'));
  });
}
