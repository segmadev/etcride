// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserModelImpl _$$UserModelImplFromJson(Map<String, dynamic> json) =>
    _$UserModelImpl(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profilePhoto: json['profilePhoto'] as String? ?? '',
      isVerified: json['isVerified'] as bool? ?? false,
      hasPassword: json['hasPassword'] as bool? ?? false,
      twoFaEnabled: json['twoFaEnabled'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      emailTripCompleted: json['email_trip_completed'] == null
          ? true
          : (json['email_trip_completed'] is bool
              ? json['email_trip_completed'] as bool
              : (json['email_trip_completed'] as num).toInt() != 0),
      createdAt: json['createdAt'] as String?,
    );

Map<String, dynamic> _$$UserModelImplToJson(_$UserModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'phone': instance.phone,
      'name': instance.name,
      'email': instance.email,
      'profilePhoto': instance.profilePhoto,
      'isVerified': instance.isVerified,
      'hasPassword': instance.hasPassword,
      'twoFaEnabled': instance.twoFaEnabled,
      'rating': instance.rating,
      'email_trip_completed': instance.emailTripCompleted,
      'createdAt': instance.createdAt,
    };
