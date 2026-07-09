// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_gateway_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PaymentGatewayModel _$PaymentGatewayModelFromJson(Map<String, dynamic> json) {
  return _PaymentGatewayModel.fromJson(json);
}

/// @nodoc
mixin _$PaymentGatewayModel {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String? get logoUrl => throw _privateConstructorUsedError;
  bool get isEnabled => throw _privateConstructorUsedError;
  int get priority => throw _privateConstructorUsedError;
  double get minAmount => throw _privateConstructorUsedError;
  double get maxAmount => throw _privateConstructorUsedError;
  double get transactionFeePercent => throw _privateConstructorUsedError;
  double get transactionFeeFixed => throw _privateConstructorUsedError;

  /// Serializes this PaymentGatewayModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PaymentGatewayModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PaymentGatewayModelCopyWith<PaymentGatewayModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentGatewayModelCopyWith<$Res> {
  factory $PaymentGatewayModelCopyWith(
          PaymentGatewayModel value, $Res Function(PaymentGatewayModel) then) =
      _$PaymentGatewayModelCopyWithImpl<$Res, PaymentGatewayModel>;
  @useResult
  $Res call(
      {int id,
      String name,
      String displayName,
      String? logoUrl,
      bool isEnabled,
      int priority,
      double minAmount,
      double maxAmount,
      double transactionFeePercent,
      double transactionFeeFixed});
}

/// @nodoc
class _$PaymentGatewayModelCopyWithImpl<$Res, $Val extends PaymentGatewayModel>
    implements $PaymentGatewayModelCopyWith<$Res> {
  _$PaymentGatewayModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaymentGatewayModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? displayName = null,
    Object? logoUrl = freezed,
    Object? isEnabled = null,
    Object? priority = null,
    Object? minAmount = null,
    Object? maxAmount = null,
    Object? transactionFeePercent = null,
    Object? transactionFeeFixed = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      logoUrl: freezed == logoUrl
          ? _value.logoUrl
          : logoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      isEnabled: null == isEnabled
          ? _value.isEnabled
          : isEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int,
      minAmount: null == minAmount
          ? _value.minAmount
          : minAmount // ignore: cast_nullable_to_non_nullable
              as double,
      maxAmount: null == maxAmount
          ? _value.maxAmount
          : maxAmount // ignore: cast_nullable_to_non_nullable
              as double,
      transactionFeePercent: null == transactionFeePercent
          ? _value.transactionFeePercent
          : transactionFeePercent // ignore: cast_nullable_to_non_nullable
              as double,
      transactionFeeFixed: null == transactionFeeFixed
          ? _value.transactionFeeFixed
          : transactionFeeFixed // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PaymentGatewayModelImplCopyWith<$Res>
    implements $PaymentGatewayModelCopyWith<$Res> {
  factory _$$PaymentGatewayModelImplCopyWith(_$PaymentGatewayModelImpl value,
          $Res Function(_$PaymentGatewayModelImpl) then) =
      __$$PaymentGatewayModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      String name,
      String displayName,
      String? logoUrl,
      bool isEnabled,
      int priority,
      double minAmount,
      double maxAmount,
      double transactionFeePercent,
      double transactionFeeFixed});
}

/// @nodoc
class __$$PaymentGatewayModelImplCopyWithImpl<$Res>
    extends _$PaymentGatewayModelCopyWithImpl<$Res, _$PaymentGatewayModelImpl>
    implements _$$PaymentGatewayModelImplCopyWith<$Res> {
  __$$PaymentGatewayModelImplCopyWithImpl(_$PaymentGatewayModelImpl _value,
      $Res Function(_$PaymentGatewayModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentGatewayModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? displayName = null,
    Object? logoUrl = freezed,
    Object? isEnabled = null,
    Object? priority = null,
    Object? minAmount = null,
    Object? maxAmount = null,
    Object? transactionFeePercent = null,
    Object? transactionFeeFixed = null,
  }) {
    return _then(_$PaymentGatewayModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      logoUrl: freezed == logoUrl
          ? _value.logoUrl
          : logoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      isEnabled: null == isEnabled
          ? _value.isEnabled
          : isEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int,
      minAmount: null == minAmount
          ? _value.minAmount
          : minAmount // ignore: cast_nullable_to_non_nullable
              as double,
      maxAmount: null == maxAmount
          ? _value.maxAmount
          : maxAmount // ignore: cast_nullable_to_non_nullable
              as double,
      transactionFeePercent: null == transactionFeePercent
          ? _value.transactionFeePercent
          : transactionFeePercent // ignore: cast_nullable_to_non_nullable
              as double,
      transactionFeeFixed: null == transactionFeeFixed
          ? _value.transactionFeeFixed
          : transactionFeeFixed // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PaymentGatewayModelImpl extends _PaymentGatewayModel {
  const _$PaymentGatewayModelImpl(
      {required this.id,
      required this.name,
      required this.displayName,
      this.logoUrl,
      this.isEnabled = true,
      this.priority = 0,
      this.minAmount = 0,
      this.maxAmount = 999999.99,
      this.transactionFeePercent = 0,
      this.transactionFeeFixed = 0})
      : super._();

  factory _$PaymentGatewayModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaymentGatewayModelImplFromJson(json);

  @override
  final int id;
  @override
  final String name;
  @override
  final String displayName;
  @override
  final String? logoUrl;
  @override
  @JsonKey()
  final bool isEnabled;
  @override
  @JsonKey()
  final int priority;
  @override
  @JsonKey()
  final double minAmount;
  @override
  @JsonKey()
  final double maxAmount;
  @override
  @JsonKey()
  final double transactionFeePercent;
  @override
  @JsonKey()
  final double transactionFeeFixed;

  @override
  String toString() {
    return 'PaymentGatewayModel(id: $id, name: $name, displayName: $displayName, logoUrl: $logoUrl, isEnabled: $isEnabled, priority: $priority, minAmount: $minAmount, maxAmount: $maxAmount, transactionFeePercent: $transactionFeePercent, transactionFeeFixed: $transactionFeeFixed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentGatewayModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl) &&
            (identical(other.isEnabled, isEnabled) ||
                other.isEnabled == isEnabled) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.minAmount, minAmount) ||
                other.minAmount == minAmount) &&
            (identical(other.maxAmount, maxAmount) ||
                other.maxAmount == maxAmount) &&
            (identical(other.transactionFeePercent, transactionFeePercent) ||
                other.transactionFeePercent == transactionFeePercent) &&
            (identical(other.transactionFeeFixed, transactionFeeFixed) ||
                other.transactionFeeFixed == transactionFeeFixed));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      displayName,
      logoUrl,
      isEnabled,
      priority,
      minAmount,
      maxAmount,
      transactionFeePercent,
      transactionFeeFixed);

  /// Create a copy of PaymentGatewayModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentGatewayModelImplCopyWith<_$PaymentGatewayModelImpl> get copyWith =>
      __$$PaymentGatewayModelImplCopyWithImpl<_$PaymentGatewayModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PaymentGatewayModelImplToJson(
      this,
    );
  }
}

abstract class _PaymentGatewayModel extends PaymentGatewayModel {
  const factory _PaymentGatewayModel(
      {required final int id,
      required final String name,
      required final String displayName,
      final String? logoUrl,
      final bool isEnabled,
      final int priority,
      final double minAmount,
      final double maxAmount,
      final double transactionFeePercent,
      final double transactionFeeFixed}) = _$PaymentGatewayModelImpl;
  const _PaymentGatewayModel._() : super._();

  factory _PaymentGatewayModel.fromJson(Map<String, dynamic> json) =
      _$PaymentGatewayModelImpl.fromJson;

  @override
  int get id;
  @override
  String get name;
  @override
  String get displayName;
  @override
  String? get logoUrl;
  @override
  bool get isEnabled;
  @override
  int get priority;
  @override
  double get minAmount;
  @override
  double get maxAmount;
  @override
  double get transactionFeePercent;
  @override
  double get transactionFeeFixed;

  /// Create a copy of PaymentGatewayModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentGatewayModelImplCopyWith<_$PaymentGatewayModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
