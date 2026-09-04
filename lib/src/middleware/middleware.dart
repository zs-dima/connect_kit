// Two contracts live here. [ConnectMiddleware] wraps the invoker behind a (path, metadata) handler
// and suits anything that observes or decorates a call: authentication, telemetry, metadata. The
// raw connectrpc [Interceptor] works on the typed request and response flow and suits anything that
// needs typed errors or request identity, which is why retry uses it.

export 'connect_middleware.dart';
export 'middlewares/metadata_middleware.dart';
export 'middlewares/retry_middleware.dart';
