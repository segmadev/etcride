import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/otp_extra.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/phone_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/complete_profile_screen.dart';
import '../../features/auth/set_password_screen.dart';
import '../../features/location_permission/location_permission_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/booking/search_destination_screen.dart';
import '../../features/booking/confirm_pickup_screen.dart';
import '../../features/booking/select_ride_screen.dart';
import '../../features/booking/payment_methods_screen.dart';
import '../../features/booking/requesting_screen.dart';
import '../../features/booking/driver_assigned_screen.dart';
import '../../features/booking/driver_chat_screen.dart';
import '../../features/chat/chat_history_screen.dart';
import '../../features/trip/trip_in_progress_screen.dart';
import '../../features/trip/trip_completed_screen.dart';
import '../../features/trip/payment_screen.dart';
import '../../features/trip/trip_history_screen.dart';
import '../../features/trip/trip_details_screen.dart';
import '../../features/trip/trip_receipt_screen.dart';
import '../../features/courier/courier_screen.dart';
import '../../features/courier/courier_receive_details_screen.dart';
import '../../features/courier/courier_select_vehicle_screen.dart';
import '../../features/courier/delivery_rules_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/reports/reports_history_screen.dart';
import '../../features/help/help_screen.dart';
import '../../features/help/contact_support_screen.dart';
import '../../features/help/report_issue_screen.dart';
import '../../features/help/legal_documents_screen.dart';
import '../../features/help/common_topics_screen.dart';
import '../../features/help/common_topic_detail_screen.dart';

CustomTransitionPage<void> _appPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.02, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Named route paths — always use these constants, never raw strings.
abstract final class AppRoutes {
  // ── Pre-auth ───────────────────────────────────────────────────────────────
  static const String splash             = '/';
  static const String onboarding         = '/onboarding';
  static const String phone              = '/phone';        // contact entry (email or phone)
  static const String login              = '/login';
  static const String otp                = '/otp';          // extra: OtpExtra
  static const String completeProfile    = '/complete-profile';
  static const String setPassword        = '/set-password';
  static const String locationPermission = '/location-permission';

  // ── Main ──────────────────────────────────────────────────────────────────
  static const String home               = '/home';

  // ── Booking flow ──────────────────────────────────────────────────────────
  static const String searchDestination  = '/search-destination';
  static const String confirmPickup      = '/confirm-pickup';
  static const String selectRide         = '/select-ride';
  static const String paymentMethods     = '/payment-methods';
  static const String requesting         = '/requesting';    // extra: bookingId (String)
  static const String driverAssigned     = '/driver-assigned'; // extra: bookingId (String)
  static const String driverChat         = '/driver-chat'; // extra: bookingId (String)
  static const String chatHistory        = '/chat-history';

  // ── Trip ──────────────────────────────────────────────────────────────────
  static const String payment            = '/payment';           // extra: bookingId
  static const String tripInProgress     = '/trip-in-progress';  // extra: bookingId
  static const String tripCompleted      = '/trip-completed';    // extra: bookingId
  static const String tripHistory        = '/trip-history';
  static const String tripDetails        = '/trip-details';      // extra: bookingId
  static const String tripReceipt        = '/trip-receipt';      // extra: bookingId

  // ── Courier ───────────────────────────────────────────────────────────────
  static const String courier               = '/courier';
  static const String courierSelectVehicle  = '/courier-select-vehicle';
  static const String courierReceiveDetails = '/courier-receive-details';
  static const String deliveryRules         = '/delivery-rules';

  // ── Profile & settings ────────────────────────────────────────────────────
  static const String profile            = '/profile';
  static const String settings           = '/settings';
  static const String notifications      = '/notifications';
  static const String reportsHistory      = '/reports-history';

  // ── Help ──────────────────────────────────────────────────────────────────
  static const String help               = '/help';
  static const String contactSupport     = '/contact-support';
  static const String reportIssue        = '/report-issue';
  static const String legalDocuments     = '/legal-documents';
  static const String commonTopics       = '/common-topics';       // extra: category (String)
  static const String commonTopicDetail  = '/common-topic-detail'; // extra: {category, topic}
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: false,
  routes: [
    // ── Pre-auth ──────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.splash,
      pageBuilder: (_, state) => _appPage(state, const SplashScreen()),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      pageBuilder: (_, state) => _appPage(state, const OnboardingScreen()),
    ),
    GoRoute(
      path: AppRoutes.phone,
      pageBuilder: (_, state) => _appPage(state, const PhoneScreen()),
    ),
    GoRoute(
      path: AppRoutes.login,
      pageBuilder: (_, state) => _appPage(state, const LoginScreen()),
    ),
    GoRoute(
      path: AppRoutes.otp,
      pageBuilder: (_, state) {
        final extra = state.extra as OtpExtra;
        return _appPage(
          state,
          OtpScreen(
            contact: extra.contact,
            contactType: extra.contactType,
            isRegistration: extra.isRegistration,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.setPassword,
      pageBuilder: (_, state) => _appPage(state, const SetPasswordScreen()),
    ),
    GoRoute(
      path: AppRoutes.completeProfile,
      pageBuilder: (_, state) => _appPage(state, const CompleteProfileScreen()),
    ),
    GoRoute(
      path: AppRoutes.locationPermission,
      pageBuilder: (_, state) => _appPage(state, const LocationPermissionScreen()),
    ),

    // ── Main ─────────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.home,
      pageBuilder: (_, state) => _appPage(state, const HomeScreen()),
    ),

    // ── Booking flow ──────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.searchDestination,
      pageBuilder: (_, state) => _appPage(state, const SearchDestinationScreen()),
    ),
    GoRoute(
      path: AppRoutes.confirmPickup,
      pageBuilder: (_, state) => _appPage(state, const ConfirmPickupScreen()),
    ),
    GoRoute(
      path: AppRoutes.selectRide,
      pageBuilder: (_, state) => _appPage(state, const SelectRideScreen()),
    ),
    GoRoute(
      path: AppRoutes.paymentMethods,
      pageBuilder: (_, state) => _appPage(
        state,
        PaymentMethodsScreen(selected: (state.extra as String?) ?? 'cash'),
      ),
    ),
    GoRoute(
      path: AppRoutes.requesting,
      redirect: (_, s) => s.extra == null ? AppRoutes.home : null,
      pageBuilder: (_, state) =>
          _appPage(state, RequestingScreen(bookingId: state.extra! as String)),
    ),
    GoRoute(
      path: AppRoutes.driverAssigned,
      redirect: (_, s) => s.extra == null ? AppRoutes.home : null,
      pageBuilder: (_, state) =>
          _appPage(state, DriverAssignedScreen(bookingId: state.extra! as String)),
    ),
    GoRoute(
      path: AppRoutes.driverChat,
      redirect: (_, s) => s.extra == null ? AppRoutes.home : null,
      pageBuilder: (_, state) =>
          _appPage(state, DriverChatScreen(bookingId: state.extra! as String)),
    ),
    GoRoute(
      path: AppRoutes.chatHistory,
      pageBuilder: (_, state) => _appPage(state, const ChatHistoryScreen()),
    ),

    // ── Trip ─────────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.payment,
      redirect: (_, s) => s.extra == null ? AppRoutes.home : null,
      pageBuilder: (_, state) =>
          _appPage(state, PaymentScreen(bookingId: state.extra! as String)),
    ),
    GoRoute(
      path: AppRoutes.tripInProgress,
      redirect: (_, s) => s.extra == null ? AppRoutes.home : null,
      pageBuilder: (_, state) =>
          _appPage(state, TripInProgressScreen(bookingId: state.extra! as String)),
    ),
    GoRoute(
      path: AppRoutes.tripCompleted,
      redirect: (_, s) => s.extra == null ? AppRoutes.home : null,
      pageBuilder: (_, state) =>
          _appPage(state, TripCompletedScreen(bookingId: state.extra! as String)),
    ),
    GoRoute(
      path: AppRoutes.tripHistory,
      pageBuilder: (_, state) => _appPage(state, const TripHistoryScreen()),
    ),
    GoRoute(
      path: AppRoutes.tripDetails,
      redirect: (_, s) => s.extra == null ? AppRoutes.home : null,
      pageBuilder: (_, state) =>
          _appPage(state, TripDetailsScreen(bookingId: state.extra! as String)),
    ),
    GoRoute(
      path: AppRoutes.tripReceipt,
      redirect: (_, s) => s.extra == null ? AppRoutes.home : null,
      pageBuilder: (_, state) =>
          _appPage(state, TripReceiptScreen(bookingId: state.extra! as String)),
    ),

    // ── Courier ───────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.courier,
      pageBuilder: (_, state) => _appPage(state, const CourierScreen()),
    ),
    GoRoute(
      path: AppRoutes.deliveryRules,
      pageBuilder: (_, state) => _appPage(state, const DeliveryRulesScreen()),
    ),
    GoRoute(
      path: AppRoutes.courierSelectVehicle,
      pageBuilder: (_, state) => _appPage(state, const CourierSelectVehicleScreen()),
    ),
    GoRoute(
      path: AppRoutes.courierReceiveDetails,
      pageBuilder: (_, state) => _appPage(state, const CourierReceiveDetailsScreen()),
    ),

    // ── Profile & settings ────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.profile,
      pageBuilder: (_, state) => _appPage(state, const ProfileScreen()),
    ),
    GoRoute(
      path: AppRoutes.settings,
      pageBuilder: (_, state) => _appPage(state, const SettingsScreen()),
    ),
    GoRoute(
      path: AppRoutes.notifications,
      pageBuilder: (_, state) => _appPage(state, const NotificationsScreen()),
    ),
    GoRoute(
      path: AppRoutes.reportsHistory,
      pageBuilder: (_, state) => _appPage(state, const ReportsHistoryScreen()),
    ),

    // ── Help ──────────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.help,
      pageBuilder: (_, state) => _appPage(state, const HelpScreen()),
    ),
    GoRoute(
      path: AppRoutes.contactSupport,
      pageBuilder: (_, state) => _appPage(state, const ContactSupportScreen()),
    ),
    GoRoute(
      path: AppRoutes.reportIssue,
      pageBuilder: (_, state) => _appPage(state, const ReportIssueScreen()),
    ),
    GoRoute(
      path: AppRoutes.legalDocuments,
      pageBuilder: (_, state) => _appPage(state, const LegalDocumentsScreen()),
    ),
    GoRoute(
      path: AppRoutes.commonTopics,
      redirect: (_, s) => s.extra == null ? AppRoutes.help : null,
      pageBuilder: (_, state) => _appPage(
        state,
        CommonTopicsScreen(category: state.extra! as String),
      ),
    ),
    GoRoute(
      path: AppRoutes.commonTopicDetail,
      redirect: (_, s) => s.extra == null ? AppRoutes.help : null,
      pageBuilder: (_, state) {
        final extra = state.extra as Map;
        return _appPage(
          state,
          CommonTopicDetailScreen(
            category: extra['category']?.toString() ?? '',
            topic: extra['topic']?.toString() ?? '',
          ),
        );
      },
    ),
  ],
);
