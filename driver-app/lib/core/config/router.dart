import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/job_model.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/verified_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/kyc/kyc_pending_screen.dart';
import '../../features/kyc/kyc_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/splash/splash_screen.dart';

// ── Shared page transition (fade) ─────────────────────────────────────────────

CustomTransitionPage<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

// ── Route name constants ──────────────────────────────────────────────────────

abstract final class AppRoutes {
  static const String splash     = '/';
  static const String onboarding = '/onboarding';

  // Auth
  static const String signIn    = '/sign-in';
  static const String driverOtp = '/driver-otp';  // extra: contact (String)
  static const String register  = '/register';
  static const String verified  = '/verified';

  // Legacy alias — redirects to signIn
  static const String login     = '/login';

  // KYC
  static const String kyc        = '/kyc';
  static const String kycPending = '/kyc-pending';

  // Main
  static const String home = '/home';

  // Chat — extra: JobModel
  static const String chat = '/chat';
}

// ── Router ────────────────────────────────────────────────────────────────────

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      pageBuilder: (context, state) => _page(state, const SplashScreen()),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      pageBuilder: (context, state) => _page(state, const OnboardingScreen()),
    ),

    // ── Auth ──────────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.signIn,
      pageBuilder: (context, state) => _page(state, const DriverSignInScreen()),
    ),
    // Legacy /login alias → sign-in
    GoRoute(
      path: AppRoutes.login,
      redirect: (context, state) => AppRoutes.signIn,
    ),
    GoRoute(
      path: AppRoutes.driverOtp,
      // Guard: if no contact was passed, go back to sign-in
      redirect: (context, state) =>
          state.extra == null ? AppRoutes.signIn : null,
      pageBuilder: (context, state) => _page(
        state,
        DriverOtpScreen(contact: state.extra! as String),
      ),
    ),
    GoRoute(
      path: AppRoutes.register,
      pageBuilder: (context, state) =>
          _page(state, const DriverRegisterScreen()),
    ),
    GoRoute(
      path: AppRoutes.verified,
      pageBuilder: (context, state) =>
          _page(state, const DriverVerifiedScreen()),
    ),

    // ── KYC ───────────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.kyc,
      pageBuilder: (context, state) => _page(state, const DriverKycScreen()),
    ),
    GoRoute(
      path: AppRoutes.kycPending,
      pageBuilder: (context, state) =>
          _page(state, const KycPendingScreen()),
    ),

    // ── Main ──────────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.home,
      pageBuilder: (context, state) =>
          _page(state, const DriverHomeScreen()),
    ),

    // ── Chat ──────────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.chat,
      redirect: (context, state) =>
          state.extra == null ? AppRoutes.home : null,
      pageBuilder: (context, state) => _page(
        state,
        DriverChatScreen(job: state.extra! as JobModel),
      ),
    ),
  ],
);
