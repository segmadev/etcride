import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for last used payment gateway preference
final lastUsedGatewayPreferenceProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('last_payment_gateway');
});

/// Helper class for managing payment preferences
class PaymentPreferences {
  static const _lastGatewayKey = 'last_payment_gateway';
  static const _defaultGateway = 'flutterwave';

  /// Save the last used payment gateway
  static Future<void> saveLastUsedGateway(String gatewayName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastGatewayKey, gatewayName);
  }

  /// Get the last used payment gateway
  static Future<String> getLastUsedGateway() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastGatewayKey) ?? _defaultGateway;
  }

  /// Clear the saved gateway preference
  static Future<void> clearPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastGatewayKey);
  }

  /// Set a new default gateway
  static Future<void> setDefaultGateway(String gatewayName) async {
    await saveLastUsedGateway(gatewayName);
  }
}
