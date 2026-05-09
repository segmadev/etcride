/// All API endpoint paths in one place.
/// Prefix every path with the baseUrl from AppConfig at call time.
abstract final class ApiEndpoints {
  // ── Public ────────────────────────────────────────────────────────────────
  static const String health      = '/health';
  static const String contentCommon = '/content/common';
  static const String contentTcp    = '/content/tcp';
  static const String mapSettings   = '/content/map-settings';

  // ── Customer auth ─────────────────────────────────────────────────────────
  static const String register             = '/auth/register';
  static const String verifyEmail          = '/auth/verify-email';
  static const String resendVerification   = '/auth/resend-verification';
  static const String login                = '/auth/login';
  static const String forgotPassword       = '/auth/forgot-password';
  static const String resetPassword        = '/auth/reset-password';
  static const String logout               = '/auth/logout';
  static const String updateProfile        = '/auth/profile';

  // ── Bookings ──────────────────────────────────────────────────────────────
  static const String bookings             = '/bookings';
  static String bookingById(String id)    => '/bookings/$id';
  static String cancelBooking(String id)  => '/bookings/$id/cancel';
  static String trackBooking(String id)   => '/bookings/$id/track';
  static String confirmDelivery(String id)=> '/bookings/$id/confirm-delivery';
  static String initiatePayment(String id)=> '/bookings/$id/pay';
  static String paymentStatus(String id)  => '/bookings/$id/payment-status';

  // ── Notifications ─────────────────────────────────────────────────────────
  static const String notifications        = '/notifications';
  static String markNotifRead(String id)  => '/notifications/$id/read';
  static const String markAllNotifRead    = '/notifications/read-all';

  // ── OTP auth (new flow) ───────────────────────────────────────────────────
  static const String sendOtp   = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';

  // ── Content ───────────────────────────────────────────────────────────────
  static const String vehicleTypes         = '/content/vehicle-types';
  static const String driverAvailability   = '/content/driver-availability';
  static const String directions           = '/content/directions';

  // ── Google Maps proxy (server-side, avoids CORS + hides API key) ─────────────
  static const String placesAutocomplete   = '/content/places';
  static const String placeDetails         = '/content/place-details';
  static const String geocode              = '/content/geocode';

  // ── Fare ──────────────────────────────────────────────────────────────────
  static const String fareEstimate         = '/fare/estimate';

  // ── Booking extras ────────────────────────────────────────────────────────
  static String updatePaymentMethod(String id) => '/bookings/$id/payment-method';
  static String rateDriver(String id)          => '/bookings/$id/rate';
}
