import 'dart:convert';
import 'package:dio/dio.dart' show DioException, FormData, MultipartFile;
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/storage/secure_storage.dart';
import '../models/driver_model.dart';
import 'terms_repository.dart';

class DriverAuthRepository {
  const DriverAuthRepository(this._client, this._storage);

  final ApiClient _client;
  final SecureStorage _storage;

  static String _encodePassword(String password) =>
      base64Encode(utf8.encode(password));

  Future<void> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    String? state,
    String? lga,
  }) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.driverRegister,
      body: {
        'name':     name,
        'phone':    phone,
        'email':    email,
        'password': _encodePassword(password),
        // ignore: use_null_aware_elements
        if (state != null) 'state': state,
        // ignore: use_null_aware_elements
        if (lga   != null) 'lga':   lga,
      },
    );
  }

  Future<void> sendOtp({required String contact}) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.driverSendOtp,
      body: {'contact': contact},
    );
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
    await _storage.saveToken(token);
    await _storage.saveUser(jsonEncode(driver.toJson()));
    return driver;
  }

  Future<DriverModel> getProfile() async {
    final data = await _client.get<Map<String, dynamic>>(ApiEndpoints.driverGetProfile);
    if (data == null) throw const FormatException('Empty response.');
    final driver = DriverModel.fromJson(data);
    await _storage.saveUser(jsonEncode(driver.toJson()));
    return driver;
  }

  Future<DriverModel> updateProfile({
    required String name,
    String? email,
    String? emailToken,
  }) async {
    final body = <String, dynamic>{
      'name': name.trim(),
      'email': email?.trim() ?? '',
    };
    if (emailToken != null && emailToken.isNotEmpty) body['email_token'] = emailToken;
    final data = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.driverUpdateProfile,
      body: body,
    );
    if (data == null) throw const FormatException('Empty response.');
    final driver = DriverModel.fromJson(data);
    await _storage.saveUser(jsonEncode(driver.toJson()));
    return driver;
  }

  Future<void> sendContactOtp({required String contact, required String type}) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.driverSendContactOtp,
      body: {'contact': contact, 'type': type},
    );
  }

  Future<String> verifyContactOtp({
    required String contact,
    required String type,
    required String otp,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.driverVerifyContactOtp,
      body: {'contact': contact, 'type': type, 'otp': otp},
    );
    return data?['verification_token']?.toString() ?? '';
  }

  Future<DriverModel> login({
    required String login,
    required String password,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.driverLogin,
      body: {
        'phone': login,
        'password': _encodePassword(password),
      },
    );
    if (data == null) throw const FormatException('Empty response.');

    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const FormatException('Missing token in response.');
    }

    final driver = DriverModel.fromJson(data);
    await _storage.saveToken(token);
    await _storage.saveUser(jsonEncode(driver.toJson()));
    return driver;
  }

  /// Validates if the current auth token is still valid.
  /// Throws an exception if the token is invalid or expired.
  Future<bool> validateAuth() async {
    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) return false;
      // Call a simple endpoint that requires auth to verify token is valid
      await _client.get<Map<String, dynamic>>(ApiEndpoints.driverGetProfile);
      return true;
    } on DioException catch (e) {
      // Only consider 401 Unauthorized as invalid auth
      // Network errors, timeouts, etc. should not cause logout
      if (e.response?.statusCode == 401) {
        return false;
      }
      // For other errors, rethrow to be handled gracefully
      rethrow;
    } catch (e) {
      // Network or other errors - rethrow to avoid unexpected logout
      rethrow;
    }
  }

  Future<void> updateFcmToken(String token) async {
    try {
      await _client.put<void>(
        ApiEndpoints.driverUpdateProfile,
        body: {'fcm_token': token},
      );
    } catch (_) {}
  }

  Future<void> logout() async {
    try {
      await _client.post<void>(ApiEndpoints.driverLogout);
    } catch (_) {}
    TermsRepository.clearCache();
    await _storage.clearAll();
  }

  Future<DriverModel?> getCachedDriver() async {
    final raw = await _storage.getUser();
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return DriverModel.fromJson(decoded);
  }

  Future<void> updateCachedDriver(DriverModel driver) async {
    await _storage.saveUser(jsonEncode(driver.toJson()));
  }

  Future<void> submitKyc({
    required XFile frontFile,
    required XFile backFile,
    required XFile profilePhoto,
    required String drivingExperience,
    String idType = "Driver's License",
    String? idNumber,
  }) async {
    final frontBytes = await frontFile.readAsBytes();
    final form = FormData.fromMap({
      'kyc_id_type': idType,
      if (idNumber != null && idNumber.trim().isNotEmpty) 'kyc_id_number': idNumber.trim(),
      'driving_experience': drivingExperience,
      'kyc_id_front': MultipartFile.fromBytes(
        frontBytes,
        filename: frontFile.name,
      ),
      'kyc_id_back': MultipartFile.fromBytes(
        await backFile.readAsBytes(),
        filename: backFile.name,
      ),
      'profile_photo': MultipartFile.fromBytes(
        await profilePhoto.readAsBytes(),
        filename: profilePhoto.name,
      ),
    });
    await _client.postFormData<Map<String, dynamic>>(
      ApiEndpoints.driverKycSubmit,
      formData: form,
    );
  }
}
