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
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
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
      'rating': instance.rating,
      'createdAt': instance.createdAt,
    };
