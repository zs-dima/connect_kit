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
  Duration toDuration() => .new(seconds: seconds.toInt());
}

extension DurationRpc1X on Duration {
  rpc.Duration toDuration() => rpc.Duration()..seconds = fn.Int64(inSeconds);
}

extension DoubleValueX on rpc.DoubleValue {
  double? toDouble() => hasValue() ? value : null;
}

extension RpcDoubleX on double? {
  rpc.DoubleValue toDoubleValue() =>
      this == null ? rpc.DoubleValue.getDefault() : (rpc.DoubleValue()..setField(1, this!));
}

extension BoolValueX on rpc.BoolValue {
  bool? toBool() => hasValue() ? value : null;
}

extension RpcBoolX on bool? {
  rpc.BoolValue toBoolValue() => this == null ? rpc.BoolValue.getDefault() : (rpc.BoolValue()..setField(1, this!));
}

extension RpcBytesX on Uint8List? {
  rpc.BytesValue toBytesValue() => this == null ? rpc.BytesValue.getDefault() : (rpc.BytesValue()..setField(1, this!));
}

extension BytesValueX on rpc.BytesValue {
  Uint8List? toBytes() => hasValue() ? .fromList(value) : null;
}

extension Int32ValueX on rpc.Int32Value {
  int? toInt() => hasValue() ? value : null;
}

extension RpcIntX on int? {
  rpc.Int32Value toIntValue() => this == null ? rpc.Int32Value.getDefault() : (rpc.Int32Value()..setField(1, this!));
}

/// Maps an RPC failure to a message for the user.
extension ConnectExceptionX on ConnectException {
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
