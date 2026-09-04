library connect_kit;

// Types that appear in this package's own API; re-exported so a consumer needs no direct
// core_model import.
export 'package:core_model/core_model.dart' show Guid, GuidX, RetryBackoff, RetryNotifier;

// The transport factory and its configuration.
export 'src/client/connect_client.dart';
export 'src/client/root_certificates.dart';
export 'src/client/transport.dart';
export 'src/client/transport_config.dart';
// The middleware contract and the middlewares.
export 'src/middleware/middleware.dart';
// Conversions between Dart values and wire types.
export 'src/tool/rpc_tool.dart';
// `Duration` is hidden: `dart:core` has its own.
export 'src/well_known_types.dart' hide Duration;
