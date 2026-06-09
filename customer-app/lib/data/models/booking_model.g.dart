// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BookingModelImpl _$$BookingModelImplFromJson(Map<String, dynamic> json) =>
    _$BookingModelImpl(
      id: json['id'] as String,
      bookingCode: json['bookingCode'] as String,
      status: $enumDecode(_$BookingStatusEnumMap, json['status']),
      bookingType: $enumDecode(_$BookingTypeEnumMap, json['bookingType']),
      pickupAddress: json['pickupAddress'] as String,
      destinationAddress: json['destinationAddress'] as String,
      pickupLat: (json['pickupLat'] as num).toDouble(),
      pickupLng: (json['pickupLng'] as num).toDouble(),
      destinationLat: (json['destinationLat'] as num).toDouble(),
      destinationLng: (json['destinationLng'] as num).toDouble(),
      estimatedFare: (json['estimatedFare'] as num?)?.toDouble() ?? 0.0,
      finalFare: (json['finalFare'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['paymentStatus'] as String? ?? 'pending',
      paymentMethod:
          $enumDecodeNullable(_$PaymentMethodEnumMap, json['paymentMethod']),
      driverId: json['driverId'] as String?,
      driverName: json['driverName'] as String?,
      driverPhone: json['driverPhone'] as String?,
      driverAvatar: json['driverAvatar'] as String?,
      driverRating: (json['driverRating'] as num?)?.toDouble() ?? 0.0,
      vehicleTypeName: json['vehicleTypeName'] as String?,
      vehiclePlate: json['vehiclePlate'] as String?,
      vehicleColor: json['vehicleColor'] as String?,
      numStops: (json['numStops'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      routePolyline: json['routePolyline'] as String?,
      routeDistanceMeters: (json['routeDistanceMeters'] as num?)?.toInt() ?? 0,
      routeDurationSeconds:
          (json['routeDurationSeconds'] as num?)?.toInt() ?? 0,
      cancellationReason: json['cancellationReason'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      driverEtaMinutes: (json['driverEtaMinutes'] as num?)?.toInt() ?? 0,
      driverDistanceKm: (json['driverDistanceKm'] as num?)?.toDouble() ?? 0.0,
      lastEvent: json['lastEvent'] as String?,
      alternativeTypes: json['alternativeTypes'] as List<dynamic>? ?? const [],
      arrivedAt: json['arrivedAt'] as String?,
      freeWaitingMinutes: (json['freeWaitingMinutes'] as num?)?.toInt() ?? 3,
      waitingChargePerMin: (json['waitingChargePerMin'] as num?)?.toDouble() ?? 0.0,
      waitingExtraCharge: (json['waitingExtraCharge'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$$BookingModelImplToJson(_$BookingModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'bookingCode': instance.bookingCode,
      'status': _$BookingStatusEnumMap[instance.status]!,
      'bookingType': _$BookingTypeEnumMap[instance.bookingType]!,
      'pickupAddress': instance.pickupAddress,
      'destinationAddress': instance.destinationAddress,
      'pickupLat': instance.pickupLat,
      'pickupLng': instance.pickupLng,
      'destinationLat': instance.destinationLat,
      'destinationLng': instance.destinationLng,
      'estimatedFare': instance.estimatedFare,
      'finalFare': instance.finalFare,
      'paymentStatus': instance.paymentStatus,
      'paymentMethod': _$PaymentMethodEnumMap[instance.paymentMethod],
      'driverId': instance.driverId,
      'driverName': instance.driverName,
      'driverPhone': instance.driverPhone,
      'driverAvatar': instance.driverAvatar,
      'driverRating': instance.driverRating,
      'vehicleTypeName': instance.vehicleTypeName,
      'vehiclePlate': instance.vehiclePlate,
      'vehicleColor': instance.vehicleColor,
      'numStops': instance.numStops,
      'durationMinutes': instance.durationMinutes,
      'distanceKm': instance.distanceKm,
      'routePolyline': instance.routePolyline,
      'routeDistanceMeters': instance.routeDistanceMeters,
      'routeDurationSeconds': instance.routeDurationSeconds,
      'cancellationReason': instance.cancellationReason,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'driverEtaMinutes': instance.driverEtaMinutes,
      'driverDistanceKm': instance.driverDistanceKm,
      'lastEvent': instance.lastEvent,
      'alternativeTypes': instance.alternativeTypes,
      'arrivedAt': instance.arrivedAt,
      'freeWaitingMinutes': instance.freeWaitingMinutes,
      'waitingChargePerMin': instance.waitingChargePerMin,
      'waitingExtraCharge': instance.waitingExtraCharge,
    };

const _$BookingStatusEnumMap = {
  BookingStatus.pending: 'pending',
  BookingStatus.assigned: 'assigned',
  BookingStatus.accepted: 'accepted',
  BookingStatus.arrived: 'arrived',
  BookingStatus.inProgress: 'inProgress',
  BookingStatus.completed: 'completed',
  BookingStatus.cancelled: 'cancelled',
  BookingStatus.rejected: 'rejected',
  BookingStatus.paymentPending: 'paymentPending',
  BookingStatus.paid: 'paid',
};

const _$BookingTypeEnumMap = {
  BookingType.ride: 'ride',
  BookingType.delivery: 'delivery',
};

const _$PaymentMethodEnumMap = {
  PaymentMethod.cash: 'cash',
  PaymentMethod.bankTransfer: 'bankTransfer',
  PaymentMethod.flutterwave: 'flutterwave',
};
