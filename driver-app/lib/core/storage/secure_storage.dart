import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

/// Thin wrapper around FlutterSecureStorage.
/// All token / user data goes through here so the storage backend
/// can be swapped without touching the rest of the codebase.
class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // In-memory cache — eliminates the async storage read on every request,
  // which can return null intermittently on Android causing spurious 401s.
  String? _cachedToken;

  /// True only when a token is confirmed in memory.
  /// Use this to guard auth-validation calls before the cache is warm.
  bool get hasToken => _cachedToken != null;

  // ── Token ────────────────────────────────────────────────────────────────
  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: AppConfig.tokenKey, value: token);
  }

  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final token = await _storage.read(key: AppConfig.tokenKey);
    _cachedToken = token;
    return token;
  }

  Future<void> deleteToken() async {
    _cachedToken = null;
    await _storage.delete(key: AppConfig.tokenKey);
  }

  // ── User JSON ─────────────────────────────────────────────────────────────
  Future<void> saveUser(String json) =>
      _storage.write(key: AppConfig.userKey, value: json);

  Future<String?> getUser() =>
      _storage.read(key: AppConfig.userKey);

  Future<void> deleteUser() =>
      _storage.delete(key: AppConfig.userKey);

  // ── Device-level flags (survive logout) ──────────────────────────────────
  Future<bool> get hasSeenOnboarding async =>
      (await _storage.read(key: AppConfig.hasSeenOnboardingKey)) == 'true';

  Future<void> setHasSeenOnboarding() =>
      _storage.write(key: AppConfig.hasSeenOnboardingKey, value: 'true');

  Future<bool> get hasLoggedInBefore async =>
      (await _storage.read(key: AppConfig.hasLoggedInBeforeKey)) == 'true';

  Future<void> setHasLoggedInBefore() =>
      _storage.write(key: AppConfig.hasLoggedInBeforeKey, value: 'true');

  Future<bool> get biometricsEnabled async =>
      (await _storage.read(key: AppConfig.biometricsEnabledKey)) == 'true';

  Future<void> setBiometricsEnabled({required bool enabled}) =>
      _storage.write(
        key: AppConfig.biometricsEnabledKey,
        value: enabled ? 'true' : 'false',
      );

  // ── Logout — clears auth data but preserves device flags ─────────────────
  Future<void> clearAll() async {
    _cachedToken = null;
    await Future.wait([
      _storage.delete(key: AppConfig.tokenKey),
      _storage.delete(key: AppConfig.userKey),
    ]);
  }

  Future<bool> get isLoggedIn async =>
      (await getToken()) != null;
}
