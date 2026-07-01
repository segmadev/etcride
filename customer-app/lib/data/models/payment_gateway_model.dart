import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_gateway_model.freezed.dart';
part 'payment_gateway_model.g.dart';

@freezed
class PaymentGatewayModel with _$PaymentGatewayModel {
  const factory PaymentGatewayModel({
    required int id,
    required String name,
    required String displayName,
    @Default(true) bool isEnabled,
    @Default(0) int priority,
    @Default(0) double minAmount,
    @Default(999999.99) double maxAmount,
    @Default(0) double transactionFeePercent,
    @Default(0) double transactionFeeFixed,
  }) = _PaymentGatewayModel;

  factory PaymentGatewayModel.fromJson(Map<String, dynamic> json) =>
      _$PaymentGatewayModelFromJson(json);

  /// Calculate transaction fee for given amount
  double calculateFee(double amount) {
    final percentFee = (amount * (transactionFeePercent / 100));
    return percentFee + transactionFeeFixed;
  }

  /// Get icon for gateway
  String get icon => switch (name) {
    'flutterwave' => '💳',
    'korapay' => '🏦',
    'monnify' => '💰',
    _ => '💳',
  };
}
