import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/router.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
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
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    try {
      await Future.wait<void>([
        ref.read(driverAuthInitProvider.future),
        Future<void>.delayed(const Duration(milliseconds: 1400)),
      ]);
    } catch (_) {}

    if (!mounted) return;
    final driver = ref.read(currentDriverProvider);
    context.go(driver != null ? AppRoutes.home : AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 32, 24, 48),
          child: Column(
            children: [
              Spacer(flex: 4),
              _SplashBrand(),
              Spacer(flex: 5),
              _SplashTagline(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashBrand extends StatelessWidget {
  const _SplashBrand();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 200,
        child: SvgPicture.asset(
          AppAssets.logoDark,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _SplashTagline extends StatelessWidget {
  const _SplashTagline();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Earn. Drive. Deliver',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.black,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        height: 1.2,
      ),
    );
  }
}
