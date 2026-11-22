// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'borrower.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Borrower _$BorrowerFromJson(Map<String, dynamic> json) => _Borrower(
  id: json['id'] as String,
  name: json['name'] as String,
  nameLower: json['nameLower'] as String,
  phoneE164: json['phoneE164'] as String,
  locality: json['locality'] as String?,
  notes: json['notes'] as String?,
  archived: json['archived'] as bool? ?? false,
  createdBy: json['createdBy'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$BorrowerToJson(_Borrower instance) => <String, dynamic>{
  'name': instance.name,
  'nameLower': instance.nameLower,
  'phoneE164': instance.phoneE164,
  'locality': instance.locality,
  'notes': instance.notes,
  'archived': instance.archived,
  'createdBy': instance.createdBy,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'schemaVersion': instance.schemaVersion,
};
