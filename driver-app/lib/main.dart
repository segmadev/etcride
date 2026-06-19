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
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.lightOverlay);
  runApp(const ProviderScope(child: ETCrideDriverApp()));
}

class ETCrideDriverApp extends ConsumerStatefulWidget {
  const ETCrideDriverApp({super.key});

  @override
  ConsumerState<ETCrideDriverApp> createState() => _ETCrideDriverAppState();
}

class _ETCrideDriverAppState extends ConsumerState<ETCrideDriverApp> {
  StreamSubscription<void>? _sessionSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref.listenManual<AsyncValue<dynamic>>(driverAuthInitProvider, (_, next) {
      next.whenData((driver) {
        if (driver != null) {
          final repo = ref.read(driverRepositoryProvider);
          ChatNotificationService.instance.start(repo.getChatThreads);
        } else {
          ChatNotificationService.instance.stop();
        }
      });
    }, fireImmediately: true);
  }

  @override
  void initState() {
    super.initState();
    _sessionSub = SessionExpiredNotifier.instance.stream.listen((_) {
      _handleSessionExpired();
    });
  }

  Future<void> _handleSessionExpired() async {
    await SecureStorage.instance.clearAll();
    ChatNotificationService.instance.stop();
    ref.invalidate(driverAuthInitProvider);
    appRouter.go(AppRoutes.signIn);
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    ChatNotificationService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(driverAuthInitProvider);
    return MaterialApp.router(
      title: 'ETCride Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
