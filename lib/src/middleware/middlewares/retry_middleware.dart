// ignore_for_file: prefer-async-callback

import 'dart:async';
import 'dart:math' as math;

import 'package:connect_kit/src/middleware/connect_middleware.dart';
import 'package:connectrpc/connect.dart';
import 'package:core_model/core_model.dart';
import 'package:meta/meta.dart';

/// Trailing-metadata key by which the server says how long to wait before retrying. A negative
/// value means "do not retry".
const _kRetryPushbackHeader = 'grpc-retry-pushback-ms';

/// The Connect protocol demotes unary trailing metadata to `trailer-`-prefixed response headers,
/// so the pushback can arrive under either key and both are read.
const _kRetryPushbackTrailerHeader = 'trailer-$_kRetryPushbackHeader';

/// Upper bound applied to a server pushback delay (the total budget is the real ceiling).
const _kMaxPushback = Duration(seconds: 60);

/// {@template connect_retry_middleware}
/// The one transient-retry layer for the Connect transport: retries transient unary calls with
/// full-jitter exponential backoff ([RetryBackoff]), honoring server pushback
/// (`grpc-retry-pushback-ms`) and a total time budget. Retries elsewhere nest and amplify; do not
/// add them.
///
/// Only unary calls are retried. A streaming request is not replayable, so it passes through.
///
/// Retry is decided by code alone, since RPC has no verb semantics. `DEADLINE_EXCEEDED` is
/// retried, though the per-call `TimeoutSignal` bounds the whole logical call, retries included,
/// so it helps only under a longer budget; per-attempt deadlines would need a fresh signal per
/// attempt. A call sensitive to an `INTERNAL` or `ABORTED` replay opts out through a custom
/// [retryEvaluator]. `UNAUTHENTICATED` is left out: a refresh flow recovers it.
///
/// It implements the raw [Interceptor] contract rather than [ConnectMiddleware], because the
/// retry loop needs the typed request and response rather than the (path, metadata) handler.
/// {@endtemplate}
@immutable
class ConnectRetryMiddleware {
  /// {@macro connect_retry_middleware}
  ConnectRetryMiddleware({
    this.backoff = const RetryBackoff(),
    this.retryEvaluator,
    this.onRetry,
    this.noRetryPaths = const <String>{},
    math.Random? random,
  }) : _random = random ?? math.Random();

  /// Jitter source; injectable for deterministic tests.
  final math.Random _random;

  /// Backoff policy: max retries, full-jitter exponential delays, per-attempt ceiling, total budget.
  final RetryBackoff backoff;

  /// Paths, in `/package.Service/Method` form, that must never be replayed: a token refresh whose
  /// replay would trip reuse detection, for instance. They get one attempt and [retryEvaluator]
  /// is not consulted.
  final Set<String> noRetryPaths;

  /// Overrides [defaultRetryEvaluator] for deciding whether an error is retryable. A negative
  /// pushback and a cancelled call still stop the loop, whatever the evaluator says.
  final bool Function(Object error, int attempt)? retryEvaluator;

  /// Called once per retry, just before the backoff sleep. Retries are otherwise invisible: a
  /// middleware outside this one sees only the last attempt.
  final RetryNotifier? onRetry;

  /// The [Interceptor] entry point.
  AnyFn<I, O> call<I extends Object, O extends Object>(AnyFn<I, O> next) => (req) {
    if (req is! UnaryRequest<I, O>) return next(req); // a streaming call passes through
    // An opted-out path gets one attempt, with no retry wrapper at all.
    if (noRetryPaths.contains(ConnectMiddleware.normalizePath(req.spec.procedure))) return next(req);
    return _executeWithRetry(req, next);
  };

  /// Whether [error] is worth retrying: transient codes only. `RESOURCE_EXHAUSTED` is retried
  /// only when the server sent a non-negative pushback saying it is safe. A negative pushback is
  /// handled in [_executeWithRetry], so it is not re-checked here.
  ///
  /// A custom [retryEvaluator] replaces this entirely.
  static bool defaultRetryEvaluator(Object error, int attempt) => switch (error) {
    ConnectException(code: Code.resourceExhausted) => _pushback(error) != null,
    ConnectException(:final code) => const {
      Code.unavailable,
      Code.aborted,
      Code.internal,
      Code.deadlineExceeded,
    }.contains(code),
    _ => false,
  };

  Future<Response<I, O>> _executeWithRetry<I extends Object, O extends Object>(
    UnaryRequest<I, O> req,
    AnyFn<I, O> next,
  ) async {
    final evaluate = retryEvaluator ?? defaultRetryEvaluator;
    // A signal exposes an abort as a future rather than a flag, so the abort is tracked locally
    // and the loop can stop between attempts, a cancel during a backoff sleep included. An
    // in-flight attempt is aborted by the transport itself.
    var aborted = false;
    req.signal.future.then((_) => aborted = true).ignore();
    var attempt = 0;
    final stopwatch = Stopwatch()..start();
    while (true) {
      if (aborted) throw ConnectException(.canceled, 'Call canceled by caller');
      try {
        return await next(req);
      } on Object catch (e) {
        // A cancelled call and a negative pushback stop the loop whatever `evaluate` says.
        if (aborted || _pushbackForbidsRetry(e) || attempt >= backoff.maxRetries || !evaluate(e, attempt)) {
          rethrow;
        }
        // The server's pushback wins, without jitter; otherwise full-jitter backoff.
        final delay = _pushback(e) ?? backoff.backoff(attempt, _random);
        if (!backoff.withinBudget(stopwatch.elapsed, delay)) rethrow;
        onRetry?.call(e, attempt, delay);
        await Future<void>.delayed(delay);
        attempt++;
      }
    }
  }

  /// The raw pushback from a [ConnectException]'s metadata, under either key.
  static String? _rawPushback(Object error) {
    if (error is! ConnectException) return null;
    return error.metadata[_kRetryPushbackHeader] ?? error.metadata[_kRetryPushbackTrailerHeader];
  }

  /// The pushback as a non-negative [Duration], capped at [_kMaxPushback]; null when it is absent
  /// or negative, which [_pushbackForbidsRetry] reports instead.
  static Duration? _pushback(Object error) {
    final raw = _rawPushback(error);
    final ms = raw == null ? null : int.tryParse(raw.trim());
    if (ms == null || ms < 0) return null;
    final d = Duration(milliseconds: ms);
    return d > _kMaxPushback ? _kMaxPushback : d;
  }

  /// Whether the server asked for no retry at all, through a negative pushback.
  static bool _pushbackForbidsRetry(Object error) {
    final raw = _rawPushback(error);
    final ms = raw == null ? null : int.tryParse(raw.trim());
    return ms != null && ms < 0;
  }
}
