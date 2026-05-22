import 'package:go_router/go_router.dart';
import '../../data/models/otp_extra.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/phone_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/complete_profile_screen.dart';
import '../../features/location_permission/location_permission_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/booking/search_destination_screen.dart';
import '../../features/booking/confirm_pickup_screen.dart';
import '../../features/booking/select_ride_screen.dart';
import '../../features/booking/requesting_screen.dart';
import '../../features/booking/driver_assigned_screen.dart';
import '../../features/trip/trip_in_progress_screen.dart';
import '../../features/trip/trip_completed_screen.dart';
import '../../features/trip/payment_screen.dart';
import '../../features/trip/trip_history_screen.dart';
import '../../features/trip/trip_details_screen.dart';
import '../../features/trip/trip_receipt_screen.dart';
import '../../features/courier/courier_screen.dart';
import '../../features/courier/courier_receive_details_screen.dart';
import '../../features/courier/delivery_rules_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/help/help_screen.dart';
import '../../features/help/contact_support_screen.dart';
import '../../features/help/report_issue_screen.dart';
import '../../features/help/legal_documents_screen.dart';

/// Named route paths — always use these constants, never raw strings.
abstract final class AppRoutes {
  // ── Pre-auth ───────────────────────────────────────────────────────────────
  static const String splash             = '/';
  static const String onboarding         = '/onboarding';
  static const String phone              = '/phone';        // contact entry (email or phone)
  static const String otp                = '/otp';          // extra: OtpExtra
  static const String completeProfile    = '/complete-profile';
  static const String locationPermission = '/location-permission';

  // ── Main ──────────────────────────────────────────────────────────────────
  static const String home               = '/home';

  // ── Booking flow ──────────────────────────────────────────────────────────
  static const String searchDestination  = '/search-destination';
  static const String confirmPickup      = '/confirm-pickup';
  static const String selectRide         = '/select-ride';
  static const String requesting         = '/requesting';    // extra: bookingId (String)
  static const String driverAssigned     = '/driver-assigned'; // extra: bookingId (String)

  // ── Trip ──────────────────────────────────────────────────────────────────
  static const String payment            = '/payment';           // extra: bookingId
  static const String tripInProgress     = '/trip-in-progress';  // extra: bookingId
  static const String tripCompleted      = '/trip-completed';    // extra: bookingId
  static const String tripHistory        = '/trip-history';
  static const String tripDetails        = '/trip-details';      // extra: bookingId
  static const String tripReceipt        = '/trip-receipt';      // extra: bookingId

  // ── Courier ───────────────────────────────────────────────────────────────
  static const String courier            = '/courier';
  static const String courierReceiveDetails = '/courier-receive-details';
  static const String deliveryRules      = '/delivery-rules';

  // ── Profile & settings ────────────────────────────────────────────────────
  static const String profile            = '/profile';
  static const String settings           = '/settings';
  static const String notifications      = '/notifications';

  // ── Help ──────────────────────────────────────────────────────────────────
  static const String help               = '/help';
  static const String contactSupport     = '/contact-support';
  static const String reportIssue        = '/report-issue';
  static const String legalDocuments     = '/legal-documents';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: false,
  routes: [
    // ── Pre-auth ──────────────────────────────────────────────────────────
    GoRoute(path: AppRoutes.splash,             builder: (_, __) => const SplashScreen()),
    GoRoute(path: AppRoutes.onboarding,         builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: AppRoutes.phone,              builder: (_, __) => const PhoneScreen()),
    GoRoute(
      path: AppRoutes.otp,
      builder: (_, state) {
        final extra = state.extra as OtpExtra;
        return OtpScreen(contact: extra.contact, contactType: extra.contactType);
      },
    ),
    GoRoute(path: AppRoutes.completeProfile,    builder: (_, __) => const CompleteProfileScreen()),
    GoRoute(path: AppRoutes.locationPermission, builder: (_, __) => const LocationPermissionScreen()),

    // ── Main ─────────────────────────────────────────────────────────────
    GoRoute(path: AppRoutes.home,               builder: (_, __) => const HomeScreen()),

    // ── Booking flow ──────────────────────────────────────────────────────
    GoRoute(path: AppRoutes.searchDestination,  builder: (_, __) => const SearchDestinationScreen()),
    GoRoute(path: AppRoutes.confirmPickup,      builder: (_, __) => const ConfirmPickupScreen()),
    GoRoute(path: AppRoutes.selectRide,         builder: (_, __) => const SelectRideScreen()),
    GoRoute(
      path: AppRoutes.requesting,
      redirect: (_, s) => s.extra == null ? AppRoutes.home : null,
      builder: (_, state) => RequestingScreen(bookingId: state.extra! as String),
    ),
    GoRoute(
      path: AppRoutes.driverAssigned,
      redirect: (_, s) => s.extra == null ? AppRoutes.home : null,
      builder: (_, state) => DriverAssignedScreen(bookingId: state.extra! as String),
    ),

    // ── Trip ─────────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.payment,
      redirect: (_, s) => s.extra == null ? AppRoutes.home : null,
      builder: (_, state) => PaymentScreen(bookingId: state.extra! as String),
    ),
    GoRoute(
      path: AppRoutes.tripInProgress,
      redirect: (_, s) => s.extra == null ? AppRoutes.home : null,
      builder: (_, state) => TripInProgressScreen(bookingId: state.extra! as String),
    ),
    GoRoute(
      path: AppRoutes.tripCompleted,
      redirect: (_, s) => s.extra == null ? AppRoutes.home : null,
      builder: (_, state) => TripCompletedScreen(bookingId: state.extra! as String),
    ),
    GoRoute(path: AppRoutes.tripHistory,        builder: (_, __) => const TripHistoryScreen()),
    GoRoute(
      path: AppRoutes.tripDetails,
      redirect: (_, s) => s.extra == null ? AppRoutes.home : null,
      builder: (_, state) => TripDetailsScreen(bookingId: state.extra! as String),
    ),
    GoRoute(
      path: AppRoutes.tripReceipt,
      redirect: (_, s) => s.extra == null ? AppRoutes.home : null,
      builder: (_, state) => TripReceiptScreen(bookingId: state.extra! as String),
    ),

    // ── Courier ───────────────────────────────────────────────────────────
    GoRoute(path: AppRoutes.courier,            builder: (_, __) => const CourierScreen()),
    GoRoute(path: AppRoutes.courierReceiveDetails, builder: (_, __) => const CourierReceiveDetailsScreen()),
    GoRoute(path: AppRoutes.deliveryRules,      builder: (_, __) => const DeliveryRulesScreen()),

    // ── Profile & settings ────────────────────────────────────────────────
    GoRoute(path: AppRoutes.profile,            builder: (_, __) => const ProfileScreen()),
    GoRoute(path: AppRoutes.settings,           builder: (_, __) => const SettingsScreen()),
    GoRoute(path: AppRoutes.notifications,      builder: (_, __) => const NotificationsScreen()),

    // ── Help ──────────────────────────────────────────────────────────────
    GoRoute(path: AppRoutes.help,               builder: (_, __) => const HelpScreen()),
    GoRoute(path: AppRoutes.contactSupport,     builder: (_, __) => const ContactSupportScreen()),
    GoRoute(path: AppRoutes.reportIssue,        builder: (_, __) => const ReportIssueScreen()),
    GoRoute(path: AppRoutes.legalDocuments,     builder: (_, __) => const LegalDocumentsScreen()),
  ],
);
