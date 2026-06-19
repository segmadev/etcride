import 'package:flutter/foundation.dart';

/// Mutable booking draft shared across the booking flow.
/// Stored in bookingDraftProvider.
@immutable
class BookingDraft {
  const BookingDraft({
    this.bookingType       = 'ride',
    this.pickupAddress     = '',
    this.pickupLat         = 0,
    this.pickupLng         = 0,
    this.destinationAddress = '',
    this.destinationLat    = 0,
    this.destinationLng    = 0,
    this.vehicleTypeId     = '',
    this.vehicleTypeName   = '',
    this.estimatedFare     = 0,
    this.distanceKm        = 0,
    this.recipientName,
    this.recipientPhone,
    this.senderPhone,
    this.packageDescription,
  });

  final String bookingType;         // 'ride' | 'delivery'
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
  final String vehicleTypeId;
  final String vehicleTypeName;
  final double estimatedFare;
  final double distanceKm;
  final String? recipientName;
  final String? recipientPhone;
  final String? senderPhone;
  final String? packageDescription;

  bool get hasPickup      => pickupLat != 0 && pickupLng != 0;
  bool get hasDestination => destinationLat != 0 && destinationLng != 0;
  bool get hasVehicle     => vehicleTypeId.isNotEmpty;

  BookingDraft copyWith({
    String? bookingType,
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
    String? destinationAddress,
    double? destinationLat,
    double? destinationLng,
    String? vehicleTypeId,
    String? vehicleTypeName,
    double? estimatedFare,
    double? distanceKm,
    String? recipientName,
    String? recipientPhone,
    String? senderPhone,
    String? packageDescription,
  }) =>
      BookingDraft(
        bookingType:         bookingType         ?? this.bookingType,
        pickupAddress:       pickupAddress       ?? this.pickupAddress,
        pickupLat:           pickupLat           ?? this.pickupLat,
        pickupLng:           pickupLng           ?? this.pickupLng,
        destinationAddress:  destinationAddress  ?? this.destinationAddress,
        destinationLat:      destinationLat      ?? this.destinationLat,
        destinationLng:      destinationLng      ?? this.destinationLng,
        vehicleTypeId:       vehicleTypeId       ?? this.vehicleTypeId,
        vehicleTypeName:     vehicleTypeName     ?? this.vehicleTypeName,
        estimatedFare:       estimatedFare       ?? this.estimatedFare,
        distanceKm:          distanceKm          ?? this.distanceKm,
        recipientName:       recipientName       ?? this.recipientName,
        recipientPhone:      recipientPhone      ?? this.recipientPhone,
        senderPhone:         senderPhone         ?? this.senderPhone,
        packageDescription:  packageDescription  ?? this.packageDescription,
      );
}
