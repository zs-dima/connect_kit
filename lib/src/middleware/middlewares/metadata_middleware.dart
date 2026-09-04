import 'package:connect_kit/src/middleware/connect_middleware.dart';
import 'package:meta/meta.dart';

/// {@template connect_metadata_middleware}
/// Adds a fixed set of metadata entries (headers) to every call.
/// {@endtemplate}
@immutable
class ConnectMetadataMiddleware extends ConnectMiddleware {
  /// {@macro connect_metadata_middleware}
  ConnectMetadataMiddleware({required Map<String, String> metadata}) : _metadata = Map.unmodifiable(metadata);

  final Map<String, String> _metadata;

  @override
  ConnectMiddlewareHandler handle(ConnectMiddlewareHandler invoker) =>
      // The fixed entries win on a key conflict.
      (path, metadata) => invoker(path, {...metadata, ..._metadata});
}
