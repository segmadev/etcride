import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/router.dart';
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

class ETCRideApp extends ConsumerWidget {
  const ETCRideApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authInitProvider);
    return MaterialApp.router(
      title: 'ETC Rides',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
