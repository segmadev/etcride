import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/storage/secure_storage.dart';
import '../models/driver_model.dart';

class DriverAuthRepository {
  const DriverAuthRepository(this._client, this._storage);

  final ApiClient      _client;
  final SecureStorage  _storage;

  static String _encodePassword(String pw) => base64Encode(utf8.encode(pw));

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<DriverModel> login({
    required String login,
    required String password,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.driverLogin,
      body: {'login': login, 'password': _encodePassword(password)},
    );
    if (data == null) throw const FormatException('Empty response.');
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const FormatException('Missing token in response.');
    }
    final driver = DriverModel.fromJson(data);
    await _saveSession(token, driver);
    return driver;
  }

  // ── Register ───────────────────────────────────────────────────────────────

  Future<void> register({
    required String name,
    required String phone,
    required String password,
    String?  email,
    String?  state,
    String?  lga,
  }) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.driverRegister,
      body: {
        'name':     name,
        'phone':    phone,
        'password': _encodePassword(password),
        if (email != null && email.isNotEmpty) 'email': email,
        if (state != null && state.isNotEmpty) 'state': state,
        if (lga   != null && lga.isNotEmpty)   'lga':   lga,
      },
    );
  }

  // ── OTP ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendOtp({required String contact}) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.driverSendOtp,
      body: {'contact': contact},
    );
    return data ?? {};
  }

  Future<DriverModel> verifyOtp({
    required String contact,
    required String otp,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.driverVerifyOtp,
      body: {'contact': contact, 'otp': otp},
    );
    if (data == null) throw const FormatException('Empty response.');
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const FormatException('Missing token in response.');
    }
    final driver = DriverModel.fromJson(data);
    await _saveSession(token, driver);
    return driver;
  }

  // ── KYC ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> submitKyc({
    required String idType,
    required String idNumber,
    required XFile  frontFile,
    XFile?          backFile,
  }) async {
    // Use readAsBytes() + fromBytes() — works on all platforms (Image.file /
    // MultipartFile.fromFile both assert !kIsWeb at runtime).
    final frontBytes = await frontFile.readAsBytes();
    final formData = FormData.fromMap({
      'kyc_id_type':   idType,
      'kyc_id_number': idNumber,
      'kyc_id_front':  MultipartFile.fromBytes(
        frontBytes,
        filename: frontFile.name,
      ),
      if (backFile != null)
        'kyc_id_back': MultipartFile.fromBytes(
          await backFile.readAsBytes(),
          filename: backFile.name,
        ),
    });

    final data = await _client.postFormData<Map<String, dynamic>>(
      ApiEndpoints.driverKycSubmit,
      formData: formData,
    );
    return data ?? {};
  }

  // ── Profile (live from backend) ───────────────────────────────────────────

  /// Fetches the driver's current profile from the server, updates the local
  /// cache, and returns the fresh [DriverModel].  Always hits the network —
  /// use this for "check status" / pull-to-refresh flows.
  Future<DriverModel> getProfile() async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.driverGetProfile,
    );
    if (data == null) throw const FormatException('Empty response.');
    final driver = DriverModel.fromJson(data);
    // Persist fresh data so the next app launch reflects the latest status.
    await _storage.saveUser(jsonEncode(driver.toJson()));
    return driver;
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _client.post<void>(ApiEndpoints.driverLogout);
    } catch (_) {}
    await _storage.clearAll();
  }

  // ── Session cache ──────────────────────────────────────────────────────────

  Future<DriverModel?> getCachedDriver() async {
    final raw = await _storage.getUser();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return DriverModel.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateCachedDriver(DriverModel driver) async {
    await _storage.saveUser(jsonEncode(driver.toJson()));
  }

  Future<void> _saveSession(String token, DriverModel driver) async {
    await _storage.saveToken(token);
    await _storage.saveUser(jsonEncode(driver.toJson()));
  }
}
