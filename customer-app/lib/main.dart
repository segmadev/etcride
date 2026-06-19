import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/router.dart';
import 'core/network/session_expired_notifier.dart';
import 'core/services/chat_notification_service.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(AppTheme.lightOverlay);

  runApp(const ProviderScope(child: ETCRideApp()));
}

class ETCRideApp extends ConsumerStatefulWidget {
  const ETCRideApp({super.key});

  @override
  ConsumerState<ETCRideApp> createState() => _ETCRideAppState();
}

class _ETCRideAppState extends ConsumerState<ETCRideApp> {
  StreamSubscription<void>? _sessionSub;

  @override
  void initState() {
    super.initState();
    _sessionSub = SessionExpiredNotifier.instance.stream.listen((_) {
      _handleSessionExpired();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start the global chat notification poller whenever the user is signed in.
    ref.listenManual<AsyncValue<dynamic>>(authInitProvider, (_, next) {
      next.whenData((user) {
        if (user != null) {
          final repo = ref.read(bookingRepositoryProvider);
          ChatNotificationService.instance.start(repo.getChatThreads);
        } else {
          ChatNotificationService.instance.stop();
        }
      });
    }, fireImmediately: true);
  }

  Future<void> _handleSessionExpired() async {
    await SecureStorage.instance.clearAll();
    ChatNotificationService.instance.stop();
    ref.invalidate(authInitProvider);
    appRouter.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    ChatNotificationService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authInitProvider);
    return MaterialApp.router(
      title: 'ETC Rides',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
