// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppUser _$AppUserFromJson(Map<String, dynamic> json) => _AppUser(
  id: json['id'] as String,
  displayName: json['displayName'] as String,
  email: json['email'] as String,
  photoUrl: json['photoUrl'] as String?,
  phoneE164: json['phoneE164'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$AppUserToJson(_AppUser instance) => <String, dynamic>{
  'displayName': instance.displayName,
  'email': instance.email,
  'photoUrl': instance.photoUrl,
  'phoneE164': instance.phoneE164,
  'createdAt': instance.createdAt.toIso8601String(),
  'schemaVersion': instance.schemaVersion,
};
