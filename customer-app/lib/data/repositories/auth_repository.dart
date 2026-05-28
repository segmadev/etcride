import 'dart:convert';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/storage/secure_storage.dart';
import '../models/user_model.dart';

class AuthRepository {
  const AuthRepository(this._client, this._storage);

  final ApiClient _client;
  final SecureStorage _storage;

  static String _encodePassword(String password) =>
      base64Encode(utf8.encode(password));

  UserModel _mapUser(Map<String, dynamic> json) {
    final first = json['first_name']?.toString() ?? '';
    final last = json['last_name']?.toString() ?? '';
    final fullFromParts = '${first.trim()} ${last.trim()}'.trim();
    final name = (json['name'] ??
            json['full_name'] ??
            json['fullname'] ??
            (fullFromParts.isNotEmpty ? fullFromParts : null))
        ?.toString() ??
        '';

    final phone =
        (json['phone'] ?? json['phone_number'] ?? json['mobile'])?.toString() ??
            '';

    final email = (json['email'] ?? json['mail'])?.toString() ?? '';

    final photo = (json['profilePhoto'] ??
            json['profile_photo'] ??
            json['photo'] ??
            json['avatar'])
        ?.toString() ??
        '';

    return UserModel(
      id: json['id']?.toString() ?? '',
      phone: phone,
      name: name,
      email: email,
      profilePhoto: photo,
      isVerified: (json['status']?.toString() ?? '') == '1',
      createdAt: json['created_at']?.toString(),
    );
  }

  // ── OTP flow ──────────────────────────────────────────────────────────────

  /// Send OTP to [contact] (email or phone). Returns contact_type.
  Future<String> sendOtp(String contact) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.sendOtp,
      body: {'contact': contact},
    );
    return data?['contact_type']?.toString() ?? 'email';
  }

  /// Verify OTP — logs in / registers the user. Returns authenticated user.
  Future<UserModel> verifyOtp({
    required String contact,
    required String otp,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.verifyOtp,
      body: {'contact': contact, 'otp': otp},
    );

    if (data == null) throw const FormatException('Empty response.');

    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const FormatException('Missing token in response.');
    }

    final user = _mapUser(data);
    await _storage.saveToken(token);
    await _storage.saveUser(jsonEncode(user.toJson()));
    return user;
  }

  // ── Password login (fallback for users who have set a password) ───────────

  Future<UserModel> login({
    required String login,
    required String password,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      body: {
        'login':    login,
        'password': _encodePassword(password),
      },
    );
    if (data == null) throw const FormatException('Empty response.');

    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const FormatException('Missing token in response.');
    }

    final user = _mapUser(data);
    await _storage.saveToken(token);
    await _storage.saveUser(jsonEncode(user.toJson()));
    return user;
  }

  Future<void> forgotPassword(String email) async {
    await _client.post<void>(
      ApiEndpoints.forgotPassword,
      body: {'email': email},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    await _client.post<void>(
      ApiEndpoints.resetPassword,
      body: {
        'email': email,
        'code': code,
        'password': _encodePassword(password),
      },
    );
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  /// Complete / update user profile. All fields optional; send only what changed.
  Future<UserModel> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? password,
    String? fcmToken,
  }) async {
    final body = <String, dynamic>{};
    if (name     != null && name.isNotEmpty)     body['name']      = name;
    if (email    != null && email.isNotEmpty)    body['email']     = email;
    if (phone    != null && phone.isNotEmpty)    body['phone']     = phone;
    if (password != null && password.isNotEmpty) body['password']  = _encodePassword(password);
    if (fcmToken != null && fcmToken.isNotEmpty) body['fcm_token'] = fcmToken;

    final data = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.updateProfile,
      body: body,
    );

    final cached = await getCachedUser();
    final updated = data != null
        ? _mapUser(data)
        : UserModel(
            id:        cached?.id ?? '',
            phone:     phone ?? cached?.phone ?? '',
            name:      name  ?? cached?.name  ?? '',
            email:     email ?? cached?.email ?? '',
            isVerified: cached?.isVerified ?? false,
            rating:    cached?.rating ?? 0.0,
            createdAt: cached?.createdAt,
          );

    await _storage.saveUser(jsonEncode(updated.toJson()));
    return updated;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<UserModel?> getCachedUser() async {
    final json = await _storage.getUser();
    if (json == null) return null;
    return UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> logout() => _storage.clearAll();

  Future<void> logoutRemote() async {
    await _client.post<void>(ApiEndpoints.logout);
    await _storage.clearAll();
  }

  Future<bool> get isLoggedIn => _storage.isLoggedIn;
}
