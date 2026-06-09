import 'dart:async';

/// Lightweight singleton stream used by [ErrorInterceptor] to signal a
/// 401-Unauthorized response that came from a protected endpoint.
///
/// [main.dart] subscribes to [stream] and performs token-clearing + redirect
/// to login so the interceptor stays free of Flutter / routing dependencies.
class SessionExpiredNotifier {
  SessionExpiredNotifier._();
  static final SessionExpiredNotifier instance = SessionExpiredNotifier._();

  final _controller = StreamController<void>.broadcast();

  /// Emits whenever the backend returns 401 on a protected route.
  Stream<void> get stream => _controller.stream;

  /// Called by [ErrorInterceptor] — safe to call from any isolate.
  void signal() {
    if (!_controller.isClosed) _controller.add(null);
  }
}
