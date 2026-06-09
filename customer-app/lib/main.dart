import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/router.dart';
import 'core/network/session_expired_notifier.dart';
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

  Future<void> _handleSessionExpired() async {
    await SecureStorage.instance.clearAll();
    // Invalidate the auth state so the router redirects correctly on next check.
    ref.invalidate(authInitProvider);
    appRouter.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
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
