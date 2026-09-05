import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:connect_kit/src/well_known_types.dart' as rpc;
import 'package:connectrpc/connect.dart';
import 'package:core_model/core_model.dart';
import 'package:fixnum/fixnum.dart' as fn;

/// Whether a [Guid] carries no id: null, empty, or the nil UUID.
extension GuidNullX on Guid? {
  bool get isNull => this == null || this!.isEmpty || this == GuidX.nil;
}

/// Seconds, the only field the wire `Duration` carries here.
extension DurationRpcX on rpc.Duration {
  /// The Dart duration behind the wire message.
  Duration toDuration() => .new(seconds: seconds.toInt());
}

/// A Dart [Duration] as the wire message, whole seconds only.
extension DurationRpc1X on Duration {
  /// The wire message for this duration.
  rpc.Duration toDuration() => rpc.Duration()..seconds = fn.Int64(inSeconds);
}

/// A wrapper message as a nullable Dart value: unset on the wire reads as null.
extension DoubleValueX on rpc.DoubleValue {
  /// The value, or null when the message carries none.
  double? toDouble() => hasValue() ? value : null;
}

/// A nullable Dart value as its wrapper message: null becomes the unset default.
extension RpcDoubleX on double? {
  /// The wire message for this value.
  rpc.DoubleValue toDoubleValue() =>
      this == null ? rpc.DoubleValue.getDefault() : (rpc.DoubleValue()..setField(1, this!));
}

/// A wrapper message as a nullable Dart value: unset on the wire reads as null.
extension BoolValueX on rpc.BoolValue {
  /// The value, or null when the message carries none.
  bool? toBool() => hasValue() ? value : null;
}

/// A nullable Dart value as its wrapper message: null becomes the unset default.
extension RpcBoolX on bool? {
  /// The wire message for this value.
  rpc.BoolValue toBoolValue() => this == null ? rpc.BoolValue.getDefault() : (rpc.BoolValue()..setField(1, this!));
}

/// Nullable bytes as their wrapper message: null becomes the unset default.
extension RpcBytesX on Uint8List? {
  /// The wire message for these bytes.
  rpc.BytesValue toBytesValue() => this == null ? rpc.BytesValue.getDefault() : (rpc.BytesValue()..setField(1, this!));
}

/// A wrapper message as nullable bytes: unset on the wire reads as null.
extension BytesValueX on rpc.BytesValue {
  /// The bytes, or null when the message carries none.
  Uint8List? toBytes() => hasValue() ? .fromList(value) : null;
}

/// A wrapper message as a nullable Dart value: unset on the wire reads as null.
extension Int32ValueX on rpc.Int32Value {
  /// The value, or null when the message carries none.
  int? toInt() => hasValue() ? value : null;
}

/// A nullable Dart value as its wrapper message: null becomes the unset default.
extension RpcIntX on int? {
  /// The wire message for this value.
  rpc.Int32Value toIntValue() => this == null ? rpc.Int32Value.getDefault() : (rpc.Int32Value()..setField(1, this!));
}

/// Maps an RPC failure to a message for the user.
extension ConnectExceptionX on ConnectException {
  /// A sentence for the user, [caption] first, chosen by the failure's code.
  String detail(String caption) {
    for (final detail in details) {
      // Typed google.rpc details arrive as raw `Any` payloads, type and bytes; connectrpc exposes
      // them untyped, so their presence is logged rather than decoded.
      developer.log(
        detail.debug == null ? detail.type : '${detail.type}: ${detail.debug}',
        name: 'ConnectException',
        error: this,
      );
    }

    return switch (code) {
      .unauthenticated => message.isNotEmpty ? '$caption. $message' : caption,
      .permissionDenied => '$caption: Permission denied',
      .unavailable => 'Backend unavailable. Please contact support',
      .aborted => '$caption: Network request aborted',
      .dataLoss => '$caption: Network data loss',
      .deadlineExceeded => 'Backend error. Please contact support',
      .canceled => '$caption: Network request cancelled',
      .internal => '$caption: $message',
      .failedPrecondition => '$caption: Network request failed precondition',
      .unknown when message.contains('CORS') => '$caption: CORS error',
      _ => '$caption: Network error: $this',
    };
  }
}
