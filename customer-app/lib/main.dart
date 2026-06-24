import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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
  await NotificationService.instance.initialize();

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

class _ETCRideAppState extends ConsumerState<ETCRideApp> with WidgetsBindingObserver {
  StreamSubscription<void>? _sessionSub;
  Timer? _authCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionSub = SessionExpiredNotifier.instance.stream.listen((_) {
      _handleSessionExpired();
    });
    // Periodic auth check every 5 minutes (skip on web due to storage issues)
    if (!kIsWeb) {
      _authCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
        _validateAuth();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      // Check auth when app comes to foreground (skip on web)
      _validateAuth();
    }
  }

  Future<void> _validateAuth() async {
    if (!mounted || kIsWeb) return; // Skip on web
    try {
      final isValid = await ref.read(authValidationProvider.future);
      if (!isValid && mounted) {
        await _handleSessionExpired();
      }
    } catch (e) {
      // Silently fail — network errors shouldn't force logout
      debugPrint('[Auth] Validation check failed: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref.listenManual<AsyncValue<dynamic>>(authInitProvider, (_, next) {
      next.whenData((user) {
        if (user != null) {
          final repo = ref.read(bookingRepositoryProvider);
          ChatNotificationService.instance.start(repo.getChatThreads);
          // Register / refresh FCM token whenever the user logs in.
          NotificationService.instance.getToken().then((token) {
            if (token != null && token.isNotEmpty) {
              ref
                  .read(authRepositoryProvider)
                  .updateProfile(fcmToken: token)
                  .ignore();
            }
          });
          NotificationService.instance.onTokenRefresh((token) {
            ref
                .read(authRepositoryProvider)
                .updateProfile(fcmToken: token)
                .ignore();
          });
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
    _authCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
