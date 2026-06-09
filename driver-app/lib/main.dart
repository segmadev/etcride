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
  void initState() {
    super.initState();
    _sessionSub = SessionExpiredNotifier.instance.stream.listen((_) {
      _handleSessionExpired();
    });
  }

  Future<void> _handleSessionExpired() async {
    await SecureStorage.instance.clearAll();
    // Invalidate the auth state so the router redirects correctly on next check.
    ref.invalidate(driverAuthInitProvider);
    appRouter.go(AppRoutes.signIn);
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
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
