import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/verified_screen.dart';
import '../../data/models/job_model.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chat/chat_history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/kyc/kyc_pending_screen.dart' show KycPendingScreen;
import '../../features/kyc/kyc_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/driver_profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/account_deletion_screen.dart';
import '../../features/settings/account_deletion_status_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/support/help_support_screen.dart';
import '../../features/help/terms_and_policy_screen.dart';
import '../../features/help/legal_documents_screen.dart';
import '../../features/vehicle/assigned_vehicle_screen.dart';

CustomTransitionPage<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

abstract final class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signIn = '/login'; // alias — same destination as login
  static const String register = '/register';
  static const String driverOtp = '/otp';
  static const String home = '/home';
  static const String kyc = '/kyc';
  static const String kycPending = '/kyc-pending';
  static const String verified = '/verified';
  static const String driverProfile = '/driver-profile';
  static const String assignedVehicle = '/assigned-vehicle';
  static const String notifications = '/notifications';
  static const String help = '/help';
  static const String settings = '/settings';
  static const String accountDeletion = '/account-deletion';
  static const String accountDeletionStatus = '/account-deletion-status';
  static const String termsAndPolicy = '/terms-and-policy';
  static const String legalDocuments = '/legal-documents';
  static const String chat        = '/chat';
  static const String chatHistory = '/chat-history';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      pageBuilder: (_, state) => _page(state, const SplashScreen()),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      pageBuilder: (_, state) => _page(state, const OnboardingScreen()),
    ),
    GoRoute(
      path: AppRoutes.login,
      pageBuilder: (_, state) => _page(state, const DriverSignInScreen()),
    ),
    GoRoute(
      path: AppRoutes.register,
      pageBuilder: (_, state) => _page(state, const DriverRegisterScreen()),
    ),
    GoRoute(
      path: AppRoutes.driverOtp,
      pageBuilder: (_, state) {
        final contact = state.extra as String? ?? '';
        return _page(state, DriverOtpScreen(contact: contact));
      },
    ),
    GoRoute(
      path: AppRoutes.home,
      pageBuilder: (_, state) => _page(state, const DriverHomeScreen()),
    ),
    GoRoute(
      path: AppRoutes.kyc,
      pageBuilder: (_, state) => _page(state, const DriverKycScreen()),
    ),
    GoRoute(
      path: AppRoutes.kycPending,
      pageBuilder: (_, state) => _page(state, const KycPendingScreen()),
    ),
    GoRoute(
      path: AppRoutes.verified,
      pageBuilder: (_, state) => _page(state, const DriverVerifiedScreen()),
    ),
    GoRoute(
      path: AppRoutes.driverProfile,
      pageBuilder: (_, state) => _page(state, const DriverProfileScreen()),
    ),
    GoRoute(
      path: AppRoutes.assignedVehicle,
      pageBuilder: (_, state) => _page(state, const AssignedVehicleScreen()),
    ),
    GoRoute(
      path: AppRoutes.notifications,
      pageBuilder: (_, state) => _page(state, const DriverNotificationsScreen()),
    ),
    GoRoute(
      path: AppRoutes.help,
      pageBuilder: (_, state) => _page(state, const HelpSupportScreen()),
    ),
    GoRoute(
      path: AppRoutes.termsAndPolicy,
      pageBuilder: (_, state) => _page(
        state,
        TermsAndPolicyScreen(tab: state.extra as String? ?? 'terms'),
      ),
    ),
    GoRoute(
      path: AppRoutes.legalDocuments,
      pageBuilder: (_, state) => _page(state, const LegalDocumentsScreen()),
    ),
    GoRoute(
      path: AppRoutes.settings,
      pageBuilder: (_, state) => _page(state, const DriverSettingsScreen()),
    ),
    GoRoute(
      path: AppRoutes.accountDeletion,
      pageBuilder: (_, state) => _page(state, const AccountDeletionScreen()),
    ),
    GoRoute(
      path: AppRoutes.accountDeletionStatus,
      pageBuilder: (_, state) => _page(state, const AccountDeletionStatusScreen()),
    ),
    GoRoute(
      path: AppRoutes.chat,
      pageBuilder: (_, state) {
        final job = state.extra as JobModel;
        return _page(state, DriverChatScreen(job: job));
      },
    ),
    GoRoute(
      path: AppRoutes.chatHistory,
      pageBuilder: (_, state) => _page(state, const DriverChatHistoryScreen()),
    ),
  ],
);
