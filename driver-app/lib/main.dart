import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/router.dart';
import 'core/network/session_expired_notifier.dart';
import 'core/services/chat_notification_service.dart';
import 'core/services/notification_service.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'shared/providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('[FCM] Firebase.initializeApp() failed: $e');
  }
  await DriverNotificationService.instance.initialize();

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

class _ETCrideDriverAppState extends ConsumerState<ETCrideDriverApp> with WidgetsBindingObserver {
  StreamSubscription<void>? _sessionSub;
  Timer? _authCheckTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref.listenManual<AsyncValue<dynamic>>(driverAuthInitProvider, (_, next) {
      next.whenData((driver) {
        if (driver != null) {
          final repo = ref.read(driverRepositoryProvider);
          ChatNotificationService.instance.start(repo.getChatThreads);
          // Register / refresh FCM token whenever the driver logs in.
          DriverNotificationService.instance.getToken().then((token) {
            if (token != null && token.isNotEmpty) {
              ref
                  .read(driverAuthRepositoryProvider)
                  .updateFcmToken(token)
                  .ignore();
            }
          });
          DriverNotificationService.instance.onTokenRefresh((token) {
            ref
                .read(driverAuthRepositoryProvider)
                .updateFcmToken(token)
                .ignore();
          });
        } else {
          ChatNotificationService.instance.stop();
        }
      });
    }, fireImmediately: true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionSub = SessionExpiredNotifier.instance.stream.listen((_) {
      _handleSessionExpired();
    });
    // Periodic auth check every 5 minutes
    _authCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      _validateAuth();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check auth when app comes to foreground
      _validateAuth();
    }
  }

  Future<void> _validateAuth() async {
    if (!mounted) return;
    try {
      final isValid = await ref.read(driverAuthValidationProvider.future);
      if (!isValid && mounted) {
        await _handleSessionExpired();
      }
    } catch (e) {
      // Silently fail — network errors shouldn't force logout
      debugPrint('[Auth] Validation check failed: $e');
    }
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
    _authCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
