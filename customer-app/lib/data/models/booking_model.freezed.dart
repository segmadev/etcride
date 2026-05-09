// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'booking_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

BookingModel _$BookingModelFromJson(Map<String, dynamic> json) {
  return _BookingModel.fromJson(json);
}

/// @nodoc
mixin _$BookingModel {
  String get id => throw _privateConstructorUsedError;
  String get bookingCode => throw _privateConstructorUsedError;
  BookingStatus get status => throw _privateConstructorUsedError;
  BookingType get bookingType => throw _privateConstructorUsedError;
  String get pickupAddress => throw _privateConstructorUsedError;
  String get destinationAddress => throw _privateConstructorUsedError;
  double get pickupLat => throw _privateConstructorUsedError;
  double get pickupLng => throw _privateConstructorUsedError;
  double get destinationLat => throw _privateConstructorUsedError;
  double get destinationLng => throw _privateConstructorUsedError;
  double get estimatedFare => throw _privateConstructorUsedError;
  double get finalFare => throw _privateConstructorUsedError;
  String get paymentStatus => throw _privateConstructorUsedError;
  PaymentMethod? get paymentMethod => throw _privateConstructorUsedError;
  String? get driverId => throw _privateConstructorUsedError;
  String? get driverName => throw _privateConstructorUsedError;
  String? get driverPhone => throw _privateConstructorUsedError;
  String? get driverAvatar => throw _privateConstructorUsedError;
  double get driverRating => throw _privateConstructorUsedError;
  String? get vehicleTypeName => throw _privateConstructorUsedError;
  String? get vehiclePlate => throw _privateConstructorUsedError;
  String? get vehicleColor => throw _privateConstructorUsedError;
  int get numStops => throw _privateConstructorUsedError;
  int get durationMinutes => throw _privateConstructorUsedError;
  double get distanceKm => throw _privateConstructorUsedError;
  String? get cancellationReason => throw _privateConstructorUsedError;
  String? get createdAt => throw _privateConstructorUsedError;
  String? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this BookingModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BookingModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BookingModelCopyWith<BookingModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BookingModelCopyWith<$Res> {
  factory $BookingModelCopyWith(
          BookingModel value, $Res Function(BookingModel) then) =
      _$BookingModelCopyWithImpl<$Res, BookingModel>;
  @useResult
  $Res call(
      {String id,
      String bookingCode,
      BookingStatus status,
      BookingType bookingType,
      String pickupAddress,
      String destinationAddress,
      double pickupLat,
      double pickupLng,
      double destinationLat,
      double destinationLng,
      double estimatedFare,
      double finalFare,
      String paymentStatus,
      PaymentMethod? paymentMethod,
      String? driverId,
      String? driverName,
      String? driverPhone,
      String? driverAvatar,
      double driverRating,
      String? vehicleTypeName,
      String? vehiclePlate,
      String? vehicleColor,
      int numStops,
      int durationMinutes,
      double distanceKm,
      String? cancellationReason,
      String? createdAt,
      String? updatedAt});
}

/// @nodoc
class _$BookingModelCopyWithImpl<$Res, $Val extends BookingModel>
    implements $BookingModelCopyWith<$Res> {
  _$BookingModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BookingModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? bookingCode = null,
    Object? status = null,
    Object? bookingType = null,
    Object? pickupAddress = null,
    Object? destinationAddress = null,
    Object? pickupLat = null,
    Object? pickupLng = null,
    Object? destinationLat = null,
    Object? destinationLng = null,
    Object? estimatedFare = null,
    Object? finalFare = null,
    Object? paymentStatus = null,
    Object? paymentMethod = freezed,
    Object? driverId = freezed,
    Object? driverName = freezed,
    Object? driverPhone = freezed,
    Object? driverAvatar = freezed,
    Object? driverRating = null,
    Object? vehicleTypeName = freezed,
    Object? vehiclePlate = freezed,
    Object? vehicleColor = freezed,
    Object? numStops = null,
    Object? durationMinutes = null,
    Object? distanceKm = null,
    Object? cancellationReason = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      bookingCode: null == bookingCode
          ? _value.bookingCode
          : bookingCode // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as BookingStatus,
      bookingType: null == bookingType
          ? _value.bookingType
          : bookingType // ignore: cast_nullable_to_non_nullable
              as BookingType,
      pickupAddress: null == pickupAddress
          ? _value.pickupAddress
          : pickupAddress // ignore: cast_nullable_to_non_nullable
              as String,
      destinationAddress: null == destinationAddress
          ? _value.destinationAddress
          : destinationAddress // ignore: cast_nullable_to_non_nullable
              as String,
      pickupLat: null == pickupLat
          ? _value.pickupLat
          : pickupLat // ignore: cast_nullable_to_non_nullable
              as double,
      pickupLng: null == pickupLng
          ? _value.pickupLng
          : pickupLng // ignore: cast_nullable_to_non_nullable
              as double,
      destinationLat: null == destinationLat
          ? _value.destinationLat
          : destinationLat // ignore: cast_nullable_to_non_nullable
              as double,
      destinationLng: null == destinationLng
          ? _value.destinationLng
          : destinationLng // ignore: cast_nullable_to_non_nullable
              as double,
      estimatedFare: null == estimatedFare
          ? _value.estimatedFare
          : estimatedFare // ignore: cast_nullable_to_non_nullable
              as double,
      finalFare: null == finalFare
          ? _value.finalFare
          : finalFare // ignore: cast_nullable_to_non_nullable
              as double,
      paymentStatus: null == paymentStatus
          ? _value.paymentStatus
          : paymentStatus // ignore: cast_nullable_to_non_nullable
              as String,
      paymentMethod: freezed == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as PaymentMethod?,
      driverId: freezed == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String?,
      driverName: freezed == driverName
          ? _value.driverName
          : driverName // ignore: cast_nullable_to_non_nullable
              as String?,
      driverPhone: freezed == driverPhone
          ? _value.driverPhone
          : driverPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      driverAvatar: freezed == driverAvatar
          ? _value.driverAvatar
          : driverAvatar // ignore: cast_nullable_to_non_nullable
              as String?,
      driverRating: null == driverRating
          ? _value.driverRating
          : driverRating // ignore: cast_nullable_to_non_nullable
              as double,
      vehicleTypeName: freezed == vehicleTypeName
          ? _value.vehicleTypeName
          : vehicleTypeName // ignore: cast_nullable_to_non_nullable
              as String?,
      vehiclePlate: freezed == vehiclePlate
          ? _value.vehiclePlate
          : vehiclePlate // ignore: cast_nullable_to_non_nullable
              as String?,
      vehicleColor: freezed == vehicleColor
          ? _value.vehicleColor
          : vehicleColor // ignore: cast_nullable_to_non_nullable
              as String?,
      numStops: null == numStops
          ? _value.numStops
          : numStops // ignore: cast_nullable_to_non_nullable
              as int,
      durationMinutes: null == durationMinutes
          ? _value.durationMinutes
          : durationMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      distanceKm: null == distanceKm
          ? _value.distanceKm
          : distanceKm // ignore: cast_nullable_to_non_nullable
              as double,
      cancellationReason: freezed == cancellationReason
          ? _value.cancellationReason
          : cancellationReason // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BookingModelImplCopyWith<$Res>
    implements $BookingModelCopyWith<$Res> {
  factory _$$BookingModelImplCopyWith(
          _$BookingModelImpl value, $Res Function(_$BookingModelImpl) then) =
      __$$BookingModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String bookingCode,
      BookingStatus status,
      BookingType bookingType,
      String pickupAddress,
      String destinationAddress,
      double pickupLat,
      double pickupLng,
      double destinationLat,
      double destinationLng,
      double estimatedFare,
      double finalFare,
      String paymentStatus,
      PaymentMethod? paymentMethod,
      String? driverId,
      String? driverName,
      String? driverPhone,
      String? driverAvatar,
      double driverRating,
      String? vehicleTypeName,
      String? vehiclePlate,
      String? vehicleColor,
      int numStops,
      int durationMinutes,
      double distanceKm,
      String? cancellationReason,
      String? createdAt,
      String? updatedAt});
}

/// @nodoc
class __$$BookingModelImplCopyWithImpl<$Res>
    extends _$BookingModelCopyWithImpl<$Res, _$BookingModelImpl>
    implements _$$BookingModelImplCopyWith<$Res> {
  __$$BookingModelImplCopyWithImpl(
      _$BookingModelImpl _value, $Res Function(_$BookingModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of BookingModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? bookingCode = null,
    Object? status = null,
    Object? bookingType = null,
    Object? pickupAddress = null,
    Object? destinationAddress = null,
    Object? pickupLat = null,
    Object? pickupLng = null,
    Object? destinationLat = null,
    Object? destinationLng = null,
    Object? estimatedFare = null,
    Object? finalFare = null,
    Object? paymentStatus = null,
    Object? paymentMethod = freezed,
    Object? driverId = freezed,
    Object? driverName = freezed,
    Object? driverPhone = freezed,
    Object? driverAvatar = freezed,
    Object? driverRating = null,
    Object? vehicleTypeName = freezed,
    Object? vehiclePlate = freezed,
    Object? vehicleColor = freezed,
    Object? numStops = null,
    Object? durationMinutes = null,
    Object? distanceKm = null,
    Object? cancellationReason = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$BookingModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      bookingCode: null == bookingCode
          ? _value.bookingCode
          : bookingCode // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as BookingStatus,
      bookingType: null == bookingType
          ? _value.bookingType
          : bookingType // ignore: cast_nullable_to_non_nullable
              as BookingType,
      pickupAddress: null == pickupAddress
          ? _value.pickupAddress
          : pickupAddress // ignore: cast_nullable_to_non_nullable
              as String,
      destinationAddress: null == destinationAddress
          ? _value.destinationAddress
          : destinationAddress // ignore: cast_nullable_to_non_nullable
              as String,
      pickupLat: null == pickupLat
          ? _value.pickupLat
          : pickupLat // ignore: cast_nullable_to_non_nullable
              as double,
      pickupLng: null == pickupLng
          ? _value.pickupLng
          : pickupLng // ignore: cast_nullable_to_non_nullable
              as double,
      destinationLat: null == destinationLat
          ? _value.destinationLat
          : destinationLat // ignore: cast_nullable_to_non_nullable
              as double,
      destinationLng: null == destinationLng
          ? _value.destinationLng
          : destinationLng // ignore: cast_nullable_to_non_nullable
              as double,
      estimatedFare: null == estimatedFare
          ? _value.estimatedFare
          : estimatedFare // ignore: cast_nullable_to_non_nullable
              as double,
      finalFare: null == finalFare
          ? _value.finalFare
          : finalFare // ignore: cast_nullable_to_non_nullable
              as double,
      paymentStatus: null == paymentStatus
          ? _value.paymentStatus
          : paymentStatus // ignore: cast_nullable_to_non_nullable
              as String,
      paymentMethod: freezed == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as PaymentMethod?,
      driverId: freezed == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String?,
      driverName: freezed == driverName
          ? _value.driverName
          : driverName // ignore: cast_nullable_to_non_nullable
              as String?,
      driverPhone: freezed == driverPhone
          ? _value.driverPhone
          : driverPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      driverAvatar: freezed == driverAvatar
          ? _value.driverAvatar
          : driverAvatar // ignore: cast_nullable_to_non_nullable
              as String?,
      driverRating: null == driverRating
          ? _value.driverRating
          : driverRating // ignore: cast_nullable_to_non_nullable
              as double,
      vehicleTypeName: freezed == vehicleTypeName
          ? _value.vehicleTypeName
          : vehicleTypeName // ignore: cast_nullable_to_non_nullable
              as String?,
      vehiclePlate: freezed == vehiclePlate
          ? _value.vehiclePlate
          : vehiclePlate // ignore: cast_nullable_to_non_nullable
              as String?,
      vehicleColor: freezed == vehicleColor
          ? _value.vehicleColor
          : vehicleColor // ignore: cast_nullable_to_non_nullable
              as String?,
      numStops: null == numStops
          ? _value.numStops
          : numStops // ignore: cast_nullable_to_non_nullable
              as int,
      durationMinutes: null == durationMinutes
          ? _value.durationMinutes
          : durationMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      distanceKm: null == distanceKm
          ? _value.distanceKm
          : distanceKm // ignore: cast_nullable_to_non_nullable
              as double,
      cancellationReason: freezed == cancellationReason
          ? _value.cancellationReason
          : cancellationReason // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BookingModelImpl implements _BookingModel {
  const _$BookingModelImpl(
      {required this.id,
      required this.bookingCode,
      required this.status,
      required this.bookingType,
      required this.pickupAddress,
      required this.destinationAddress,
      required this.pickupLat,
      required this.pickupLng,
      required this.destinationLat,
      required this.destinationLng,
      this.estimatedFare = 0.0,
      this.finalFare = 0.0,
      this.paymentStatus = 'pending',
      this.paymentMethod,
      this.driverId,
      this.driverName,
      this.driverPhone,
      this.driverAvatar,
      this.driverRating = 0.0,
      this.vehicleTypeName,
      this.vehiclePlate,
      this.vehicleColor,
      this.numStops = 0,
      this.durationMinutes = 0,
      this.distanceKm = 0.0,
      this.cancellationReason,
      this.createdAt,
      this.updatedAt});

  factory _$BookingModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$BookingModelImplFromJson(json);

  @override
  final String id;
  @override
  final String bookingCode;
  @override
  final BookingStatus status;
  @override
  final BookingType bookingType;
  @override
  final String pickupAddress;
  @override
  final String destinationAddress;
  @override
  final double pickupLat;
  @override
  final double pickupLng;
  @override
  final double destinationLat;
  @override
  final double destinationLng;
  @override
  @JsonKey()
  final double estimatedFare;
  @override
  @JsonKey()
  final double finalFare;
  @override
  @JsonKey()
  final String paymentStatus;
  @override
  final PaymentMethod? paymentMethod;
  @override
  final String? driverId;
  @override
  final String? driverName;
  @override
  final String? driverPhone;
  @override
  final String? driverAvatar;
  @override
  @JsonKey()
  final double driverRating;
  @override
  final String? vehicleTypeName;
  @override
  final String? vehiclePlate;
  @override
  final String? vehicleColor;
  @override
  @JsonKey()
  final int numStops;
  @override
  @JsonKey()
  final int durationMinutes;
  @override
  @JsonKey()
  final double distanceKm;
  @override
  final String? cancellationReason;
  @override
  final String? createdAt;
  @override
  final String? updatedAt;

  @override
  String toString() {
    return 'BookingModel(id: $id, bookingCode: $bookingCode, status: $status, bookingType: $bookingType, pickupAddress: $pickupAddress, destinationAddress: $destinationAddress, pickupLat: $pickupLat, pickupLng: $pickupLng, destinationLat: $destinationLat, destinationLng: $destinationLng, estimatedFare: $estimatedFare, finalFare: $finalFare, paymentStatus: $paymentStatus, paymentMethod: $paymentMethod, driverId: $driverId, driverName: $driverName, driverPhone: $driverPhone, driverAvatar: $driverAvatar, driverRating: $driverRating, vehicleTypeName: $vehicleTypeName, vehiclePlate: $vehiclePlate, vehicleColor: $vehicleColor, numStops: $numStops, durationMinutes: $durationMinutes, distanceKm: $distanceKm, cancellationReason: $cancellationReason, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BookingModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.bookingCode, bookingCode) ||
                other.bookingCode == bookingCode) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.bookingType, bookingType) ||
                other.bookingType == bookingType) &&
            (identical(other.pickupAddress, pickupAddress) ||
                other.pickupAddress == pickupAddress) &&
            (identical(other.destinationAddress, destinationAddress) ||
                other.destinationAddress == destinationAddress) &&
            (identical(other.pickupLat, pickupLat) ||
                other.pickupLat == pickupLat) &&
            (identical(other.pickupLng, pickupLng) ||
                other.pickupLng == pickupLng) &&
            (identical(other.destinationLat, destinationLat) ||
                other.destinationLat == destinationLat) &&
            (identical(other.destinationLng, destinationLng) ||
                other.destinationLng == destinationLng) &&
            (identical(other.estimatedFare, estimatedFare) ||
                other.estimatedFare == estimatedFare) &&
            (identical(other.finalFare, finalFare) ||
                other.finalFare == finalFare) &&
            (identical(other.paymentStatus, paymentStatus) ||
                other.paymentStatus == paymentStatus) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.driverId, driverId) ||
                other.driverId == driverId) &&
            (identical(other.driverName, driverName) ||
                other.driverName == driverName) &&
            (identical(other.driverPhone, driverPhone) ||
                other.driverPhone == driverPhone) &&
            (identical(other.driverAvatar, driverAvatar) ||
                other.driverAvatar == driverAvatar) &&
            (identical(other.driverRating, driverRating) ||
                other.driverRating == driverRating) &&
            (identical(other.vehicleTypeName, vehicleTypeName) ||
                other.vehicleTypeName == vehicleTypeName) &&
            (identical(other.vehiclePlate, vehiclePlate) ||
                other.vehiclePlate == vehiclePlate) &&
            (identical(other.vehicleColor, vehicleColor) ||
                other.vehicleColor == vehicleColor) &&
            (identical(other.numStops, numStops) ||
                other.numStops == numStops) &&
            (identical(other.durationMinutes, durationMinutes) ||
                other.durationMinutes == durationMinutes) &&
            (identical(other.distanceKm, distanceKm) ||
                other.distanceKm == distanceKm) &&
            (identical(other.cancellationReason, cancellationReason) ||
                other.cancellationReason == cancellationReason) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        bookingCode,
        status,
        bookingType,
        pickupAddress,
        destinationAddress,
        pickupLat,
        pickupLng,
        destinationLat,
        destinationLng,
        estimatedFare,
        finalFare,
        paymentStatus,
        paymentMethod,
        driverId,
        driverName,
        driverPhone,
        driverAvatar,
        driverRating,
        vehicleTypeName,
        vehiclePlate,
        vehicleColor,
        numStops,
        durationMinutes,
        distanceKm,
        cancellationReason,
        createdAt,
        updatedAt
      ]);

  /// Create a copy of BookingModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BookingModelImplCopyWith<_$BookingModelImpl> get copyWith =>
      __$$BookingModelImplCopyWithImpl<_$BookingModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BookingModelImplToJson(
      this,
    );
  }
}

abstract class _BookingModel implements BookingModel {
  const factory _BookingModel(
      {required final String id,
      required final String bookingCode,
      required final BookingStatus status,
      required final BookingType bookingType,
      required final String pickupAddress,
      required final String destinationAddress,
      required final double pickupLat,
      required final double pickupLng,
      required final double destinationLat,
      required final double destinationLng,
      final double estimatedFare,
      final double finalFare,
      final String paymentStatus,
      final PaymentMethod? paymentMethod,
      final String? driverId,
      final String? driverName,
      final String? driverPhone,
      final String? driverAvatar,
      final double driverRating,
      final String? vehicleTypeName,
      final String? vehiclePlate,
      final String? vehicleColor,
      final int numStops,
      final int durationMinutes,
      final double distanceKm,
      final String? cancellationReason,
      final String? createdAt,
      final String? updatedAt}) = _$BookingModelImpl;

  factory _BookingModel.fromJson(Map<String, dynamic> json) =
      _$BookingModelImpl.fromJson;

  @override
  String get id;
  @override
  String get bookingCode;
  @override
  BookingStatus get status;
  @override
  BookingType get bookingType;
  @override
  String get pickupAddress;
  @override
  String get destinationAddress;
  @override
  double get pickupLat;
  @override
  double get pickupLng;
  @override
  double get destinationLat;
  @override
  double get destinationLng;
  @override
  double get estimatedFare;
  @override
  double get finalFare;
  @override
  String get paymentStatus;
  @override
  PaymentMethod? get paymentMethod;
  @override
  String? get driverId;
  @override
  String? get driverName;
  @override
  String? get driverPhone;
  @override
  String? get driverAvatar;
  @override
  double get driverRating;
  @override
  String? get vehicleTypeName;
  @override
  String? get vehiclePlate;
  @override
  String? get vehicleColor;
  @override
  int get numStops;
  @override
  int get durationMinutes;
  @override
  double get distanceKm;
  @override
  String? get cancellationReason;
  @override
  String? get createdAt;
  @override
  String? get updatedAt;

  /// Create a copy of BookingModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BookingModelImplCopyWith<_$BookingModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
