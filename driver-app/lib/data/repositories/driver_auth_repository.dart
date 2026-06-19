import 'dart:convert';
import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/storage/secure_storage.dart';
import '../models/driver_model.dart';

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
  }) async {
    final data = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.driverUpdateProfile,
      body: {
        'name': name.trim(),
        'email': email?.trim() ?? '',
      },
    );
    if (data == null) throw const FormatException('Empty response.');
    final driver = DriverModel.fromJson(data);
    await _storage.saveUser(jsonEncode(driver.toJson()));
    return driver;
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

  Future<void> logout() async {
    try {
      await _client.post<void>(ApiEndpoints.driverLogout);
    } catch (_) {}
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
