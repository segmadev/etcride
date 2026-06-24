import '../../core/network/api_client.dart';

class TermsAndConditionsData {
  final String termsAndConditions;
  final String privacyPolicy;
  final String termsVersion;

  TermsAndConditionsData({
    required this.termsAndConditions,
    required this.privacyPolicy,
    required this.termsVersion,
  });

  factory TermsAndConditionsData.fromJson(Map<String, dynamic> json) {
    return TermsAndConditionsData(
      termsAndConditions: json['terms_and_conditions']?.toString() ?? '',
      privacyPolicy: json['privacy_policy']?.toString() ?? '',
      termsVersion: json['terms_version']?.toString() ?? '',
    );
  }
}

class TermsStatus {
  final bool hasAcceptedLatest;
  final String currentVersion;
  final String? acceptedVersion;
  final String? acceptedAt;

  TermsStatus({
    required this.hasAcceptedLatest,
    required this.currentVersion,
    this.acceptedVersion,
    this.acceptedAt,
  });

  factory TermsStatus.fromJson(Map<String, dynamic> json) {
    return TermsStatus(
      hasAcceptedLatest: json['has_accepted_latest'] == true,
      currentVersion: json['current_version']?.toString() ?? '',
      acceptedVersion: json['accepted_version']?.toString(),
      acceptedAt: json['accepted_at']?.toString(),
    );
  }
}

class TermsRepository {
  const TermsRepository(this._client);

  final ApiClient _client;

  // Cache to prevent repeated API calls
  static TermsAndConditionsData? _cachedTerms;
  static int _cacheAttempts = 0;
  static const int _maxCacheAttempts = 2;

  /// Fetch current Terms & Conditions and Privacy Policy (with caching)
  Future<TermsAndConditionsData> getTermsAndConditions() async {
    // Return cached data if available
    if (_cachedTerms != null) {
      return _cachedTerms!;
    }

    // Prevent infinite loop - only attempt 2 times max
    if (_cacheAttempts >= _maxCacheAttempts) {
      return TermsAndConditionsData(
        termsAndConditions: 'Terms & Conditions unavailable. Please try again later.',
        privacyPolicy: 'Privacy Policy unavailable. Please try again later.',
        termsVersion: DateTime.now().toIso8601String(),
      );
    }

    _cacheAttempts++;
    try {
      final data = await _client.get<Map<String, dynamic>>(
        '/content/terms-conditions',
      );
      if (data == null) throw const FormatException('Empty response.');
      _cachedTerms = TermsAndConditionsData.fromJson(data);
      return _cachedTerms!;
    } catch (e) {
      rethrow;
    }
  }

  /// Clear the cache (call after logout)
  static void clearCache() {
    _cachedTerms = null;
    _cacheAttempts = 0;
  }

  /// Accept current Terms & Conditions (driver)
  Future<void> acceptTerms() async {
    await _client.post<Map<String, dynamic>>(
      '/driver/auth/accept-terms',
      body: {},
    );
  }

  /// Get driver's T&C acceptance status
  Future<TermsStatus> getTermsStatus() async {
    final data = await _client.get<Map<String, dynamic>>(
      '/driver/auth/terms-status',
    );
    if (data == null) throw const FormatException('Empty response.');
    return TermsStatus.fromJson(data);
  }
}
