import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/payment_gateway_model.dart';
import '../../data/repositories/booking_repository.dart';
import 'providers.dart';

/// Provider for fetching available payment gateways
final paymentGatewaysProvider =
    FutureProvider.autoDispose<List<PaymentGatewayModel>>((ref) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getPaymentGateways();
});

/// Local state for last used gateway preference
final lastUsedGatewayProvider = StateProvider<String?>((ref) {
  // Initialized from SharedPreferences when app loads
  return null;
});

/// Provider for selected gateway with fallback to last used
final selectedPaymentGatewayProvider =
    StateProvider<String?>((ref) {
  return ref.watch(lastUsedGatewayProvider);
});

/// Provider to save and retrieve last used gateway
class GatewayPreferences {
  static const _key = 'last_payment_gateway';

  static Future<void> saveLastUsedGateway(String gatewayName) async {
    // Save to SharedPreferences (implementation will be in preferences.dart)
  }

  static Future<String?> getLastUsedGateway() async {
    // Retrieve from SharedPreferences
    return null;
  }

  static Future<void> clearPreference() async {
    // Clear preference from SharedPreferences
  }
}
