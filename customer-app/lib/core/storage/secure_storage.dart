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

  // ── Token ────────────────────────────────────────────────────────────────
  Future<void> saveToken(String token) =>
      _storage.write(key: AppConfig.tokenKey, value: token);

  Future<String?> getToken() =>
      _storage.read(key: AppConfig.tokenKey);

  Future<void> deleteToken() =>
      _storage.delete(key: AppConfig.tokenKey);

  // ── User JSON ─────────────────────────────────────────────────────────────
  Future<void> saveUser(String json) =>
      _storage.write(key: AppConfig.userKey, value: json);

  Future<String?> getUser() =>
      _storage.read(key: AppConfig.userKey);

  Future<void> deleteUser() =>
      _storage.delete(key: AppConfig.userKey);

  // ── Nuke everything (logout) ──────────────────────────────────────────────
  Future<void> clearAll() => _storage.deleteAll();

  Future<bool> get isLoggedIn async =>
      (await getToken()) != null;
}
