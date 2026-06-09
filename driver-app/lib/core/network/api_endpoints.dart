/// All API endpoint paths in one place.
/// Prefix every path with the baseUrl from AppConfig at call time.
abstract final class ApiEndpoints {
  // ── Public ────────────────────────────────────────────────────────────────
  static const String health        = '/health';
  static const String contentCommon = '/content/common';
  static const String contentTcp    = '/content/tcp';
  static const String mapSettings   = '/content/map-settings';
  static const String driverAuthConfig = '/content/driver-auth-config';
  static const String driverLocations  = '/content/driver-locations';

  // ── Content ───────────────────────────────────────────────────────────────
  static const String vehicleTypes         = '/content/vehicle-types';

  // ── Google Maps proxy (server-side, avoids CORS + hides API key) ─────────────
  static const String placesAutocomplete   = '/content/places';
  static const String placeDetails         = '/content/place-details';
  static const String geocode              = '/content/geocode';
  static const String reverseGeocode       = '/content/reverse-geocode';

  // ── Driver auth ───────────────────────────────────────────────────────────
  static const String driverLogin         = '/driver/auth/login';
  static const String driverRegister      = '/driver/auth/register';
  static const String driverSendOtp       = '/driver/auth/send-otp';
  static const String driverVerifyOtp     = '/driver/auth/verify-otp';
  static const String driverLogout        = '/driver/auth/logout';
  static const String driverGetProfile    = '/driver/auth/profile';  // GET — fresh from DB
  static const String driverUpdateProfile = '/driver/auth/profile';  // PUT

  // ── Driver availability & location ────────────────────────────────────────
  static const String driverAvailability  = '/driver/availability';
  static const String driverLocationPing  = '/driver/location';
  static const String driverKycSubmit     = '/driver/kyc';

  // ── Driver jobs ───────────────────────────────────────────────────────────
  static const String driverJobs            = '/driver/jobs';
  static String driverJobById(String id)    => '/driver/jobs/$id';
  static String acceptJob(String id)        => '/driver/jobs/$id/accept';
  static String rejectJob(String id)        => '/driver/jobs/$id/reject';
  static String cancelJob(String id)        => '/driver/jobs/$id/cancel';
  static String arriveJob(String id)        => '/driver/jobs/$id/arrive';
  static String startJob(String id)         => '/driver/jobs/$id/start';
  static String completeJob(String id)      => '/driver/jobs/$id/complete';
  static String confirmPayment(String id)   => '/driver/jobs/$id/confirm-payment';
  static String reachStop(String id, String stopId) => '/driver/jobs/$id/stops/$stopId/reach';
  static String updateJobPaymentMethod(String id)   => '/driver/jobs/$id/payment-method';
}
