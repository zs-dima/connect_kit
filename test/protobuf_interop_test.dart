// Pins the interop between connectrpc and the protobuf runtime: the codecs and the transport
// plumbing (interceptor fold, signals, the Client extension) against a well-known message.

import 'package:connect_kit/connect_kit.dart';
import 'package:connectrpc/connect.dart';
import 'package:connectrpc/protobuf.dart';
import 'package:connectrpc/test.dart';
import 'package:test/test.dart';

void main() {
  group('connectrpc and protobuf interop', () {
    test('ProtoCodec round-trips a message', () {
      const codec = ProtoCodec();
      final source = StringValue(value: '0198c5b6-1f2a-7c3d-9e4f-5a6b7c8d9e0f');

      final bytes = codec.encode(source);
      final target = StringValue();
      codec.decode(bytes, target);

      expect(target, equals(source));
      expect(target.value, equals(source.value));
    });

    test('JsonCodec round-trips through proto3 JSON', () {
      const codec = JsonCodec();
      final source = StringValue(value: '0198c5b6-1f2a-7c3d-9e4f-5a6b7c8d9e0f');

      final bytes = codec.encode(source);
      final target = StringValue();
      codec.decode(bytes, target);

      expect(target, equals(source));
    });

    test('a unary call flows through the transport plumbing', () async {
      const spec = Spec<StringValue, StringValue>(
        '/example.v1.ExampleService/Check',
        .unary,
        StringValue.create,
        StringValue.create,
      );
      final transport = FakeTransportBuilder().unary(spec, (req, context) {
        expect(req.value, equals('ping'));
        return StringValue(value: 'pong');
      }).build();

      final result = await Client(transport).unary(spec, StringValue(value: 'ping'));

      expect(result.value, equals('pong'));
    });
  });
}
