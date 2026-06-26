import 'dart:async';

class AccountDeactivationNotifier {
  AccountDeactivationNotifier._();
  static final instance = AccountDeactivationNotifier._();

  final _controller = StreamController<void>.broadcast();
  Stream<void> get stream => _controller.stream;

  void signal() {
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}
