// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_gateway_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PaymentGatewayModelImpl _$$PaymentGatewayModelImplFromJson(
        Map<String, dynamic> json) =>
    _$PaymentGatewayModelImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      displayName: json['displayName'] as String,
      logoUrl: json['logoUrl'] as String?,
      isEnabled: json['isEnabled'] as bool? ?? true,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      minAmount: (json['minAmount'] as num?)?.toDouble() ?? 0,
      maxAmount: (json['maxAmount'] as num?)?.toDouble() ?? 999999.99,
      transactionFeePercent:
          (json['transactionFeePercent'] as num?)?.toDouble() ?? 0,
      transactionFeeFixed:
          (json['transactionFeeFixed'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$$PaymentGatewayModelImplToJson(
        _$PaymentGatewayModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'displayName': instance.displayName,
      'logoUrl': instance.logoUrl,
      'isEnabled': instance.isEnabled,
      'priority': instance.priority,
      'minAmount': instance.minAmount,
      'maxAmount': instance.maxAmount,
      'transactionFeePercent': instance.transactionFeePercent,
      'transactionFeeFixed': instance.transactionFeeFixed,
    };
