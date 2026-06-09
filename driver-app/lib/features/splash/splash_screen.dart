import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/router.dart';
import '../../shared/providers/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Pre-warm auth config cache in parallel (non-blocking)
    ref.read(driverAuthConfigProvider.future).ignore();

    Future.microtask(() async {
      try {
        await ref.read(driverAuthInitProvider.future);
      } catch (_) {}
      if (!mounted) return;

      final driver = ref.read(currentDriverProvider);

      if (driver == null) {
        context.go(AppRoutes.onboarding);
        return;
      }

      // Route based on KYC status so drivers can never bypass verification
      switch (driver.kycStatus) {
        case 'verified':
          context.go(AppRoutes.home);
        case 'pending':
          context.go(AppRoutes.kycPending);
        default: // not_submitted | rejected
          context.go(AppRoutes.kyc);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
