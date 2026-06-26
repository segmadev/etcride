/// Single source of truth for environment / API configuration.
/// To point the app at a different server, change [baseUrl] here only.
abstract final class AppConfig {
  // ── API ─────────────────────────────────────────────────────────────────
  /// Base URL for the PHP backend.  No trailing slash.
  // static const String baseUrl = 'https://testapi.eksuth.org.ng/api/';
  // static const String baseUrl = 'http://10.159.5.20:8055/';
  static const String baseUrl = 'http://localhost:8055/';

  /// Request timeout in seconds.
  static const int connectTimeout = 15;
  static const int receiveTimeout = 30;

  // ── Map ──────────────────────────────────────────────────────────────────
  /// Google Maps API key for the customer app.
  /// In production, inject via --dart-define or a build-config file.
  static const String googleMapsKey =
      String.fromEnvironment('GOOGLE_MAPS_KEY', defaultValue: 'AIzaSyBRl4mOt5pz5B1cw8ndOHlgMV-WC4XjKdo');

  // ── Storage keys ─────────────────────────────────────────────────────────
  static const String tokenKey              = 'etc_driver_token';
  static const String userKey               = 'etc_driver_user';
  // Device-level flags — NOT cleared on logout
  static const String hasSeenOnboardingKey  = 'etc_driver_has_seen_onboarding';
  static const String hasLoggedInBeforeKey  = 'etc_driver_has_logged_in';
  static const String biometricsEnabledKey  = 'etc_driver_biometrics';

  // ── Misc ─────────────────────────────────────────────────────────────────
  static const String appVersion = '1.0.0';
  static const int otpLength     = 6;
  static const int otpResendSecs = 30;
}
