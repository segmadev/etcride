import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../storage/secure_storage.dart';

class BiometricException implements Exception {
  final String message;
  BiometricException(this.message);
  @override
  String toString() => message;
}

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final _auth = LocalAuthentication();

  /// True if the device has biometric hardware and at least one enrolled credential.
  Future<bool> get isAvailable async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> get isEnabled => SecureStorage.instance.biometricsEnabled;

  Future<void> setEnabled({required bool enabled}) =>
      SecureStorage.instance.setBiometricsEnabled(enabled: enabled);

  /// Prompt the user to authenticate. Returns true on success.
  /// Throws an exception with a descriptive message on failure.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to enable biometric sign-in',
        options: const AuthenticationOptions(
          biometricOnly: true, // require biometric, no PIN fallback
          stickyAuth: false,
        ),
      );
    } on PlatformException catch (e) {
      throw BiometricException(_getErrorMessage(e.code));
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'NotAvailable':
        return 'Biometric authentication is not available on this device.';
      case 'NotEnrolled':
        return 'No biometrics are enrolled. Please add a fingerprint or face in Settings.';
      case 'LockedOut':
        return 'Too many failed attempts. Please try again later.';
      case 'PermanentlyLockedOut':
        return 'Biometric authentication is disabled due to too many failed attempts.';
      case 'UserCanceled':
        return 'Authentication canceled by user.';
      case 'SystemNotSupported':
        return 'This device does not support biometric authentication.';
      default:
        return 'Biometric authentication failed: $code. Make sure you have fingerprints or face enrolled in Settings.';
    }
  }
}
