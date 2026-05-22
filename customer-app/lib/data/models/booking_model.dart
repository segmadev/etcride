import 'package:freezed_annotation/freezed_annotation.dart';

part 'booking_model.freezed.dart';
part 'booking_model.g.dart';

enum BookingStatus {
  pending, assigned, accepted, arrived, inProgress, completed, cancelled, rejected, paymentPending, paid;

  static BookingStatus fromString(String s) => switch (s) {
    'pending'          => BookingStatus.pending,
    'assigned'         => BookingStatus.assigned,
    'accepted'         => BookingStatus.accepted,
    'arrived'          => BookingStatus.arrived,
    'in_progress'      => BookingStatus.inProgress,
    'inProgress'       => BookingStatus.inProgress,
    'completed'        => BookingStatus.completed,
    'cancelled'        => BookingStatus.cancelled,
    'rejected'         => BookingStatus.rejected,
    'payment_pending'  => BookingStatus.paymentPending,
    'paymentPending'   => BookingStatus.paymentPending,
    'paid'             => BookingStatus.paid,
    _                  => BookingStatus.pending,
  };

  bool get isActive => const {
    BookingStatus.pending, BookingStatus.assigned, BookingStatus.accepted,
    BookingStatus.arrived, BookingStatus.inProgress, BookingStatus.paymentPending,
  }.contains(this);

  bool get isCompleted => this == BookingStatus.completed || this == BookingStatus.paid;
  bool get isCancelled => this == BookingStatus.cancelled;
  bool get canCancel => const {
    BookingStatus.pending, BookingStatus.assigned,
    BookingStatus.accepted, BookingStatus.arrived,
  }.contains(this);
  bool get needsPayment => this == BookingStatus.paymentPending;
  bool get canRate => const {
    BookingStatus.completed, BookingStatus.paid, BookingStatus.paymentPending,
  }.contains(this);
}

enum BookingType {
  ride, delivery;

  static BookingType fromString(String s) =>
      s == 'delivery' ? BookingType.delivery : BookingType.ride;

  String get apiValue => this == BookingType.delivery ? 'delivery' : 'ride';
}

enum PaymentMethod {
  cash, bankTransfer, flutterwave;

  static PaymentMethod fromString(String s) => switch (s) {
    'cash'          => PaymentMethod.cash,
    'bank_transfer' => PaymentMethod.bankTransfer,
    'flutterwave'   => PaymentMethod.flutterwave,
    _               => PaymentMethod.cash,
  };

  String get apiValue => switch (this) {
    PaymentMethod.cash          => 'cash',
    PaymentMethod.bankTransfer  => 'bank_transfer',
    PaymentMethod.flutterwave   => 'flutterwave',
  };

  String get displayName => switch (this) {
    PaymentMethod.cash          => 'Cash',
    PaymentMethod.bankTransfer  => 'Bank Transfer',
    PaymentMethod.flutterwave   => 'Flutterwave',
  };
}

@freezed
class BookingModel with _$BookingModel {
  const factory BookingModel({
    required String id,
    required String bookingCode,
    required BookingStatus status,
    required BookingType bookingType,
    required String pickupAddress,
    required String destinationAddress,
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
    @Default(0.0) double estimatedFare,
    @Default(0.0) double finalFare,
    @Default('pending') String paymentStatus,
    PaymentMethod? paymentMethod,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? driverAvatar,
    @Default(0.0) double driverRating,
    String? vehicleTypeName,
    String? vehiclePlate,
    String? vehicleColor,
    @Default(0) int numStops,
    @Default(0) int durationMinutes,
    @Default(0.0) double distanceKm,
    String? routePolyline,
    @Default(0) int routeDistanceMeters,
    @Default(0) int routeDurationSeconds,
    String? cancellationReason,
    String? createdAt,
    String? updatedAt,
  }) = _BookingModel;

  factory BookingModel.fromJson(Map<String, dynamic> json) =>
      _$BookingModelFromJson(json);
}
