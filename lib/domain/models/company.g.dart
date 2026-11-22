// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Company _$CompanyFromJson(Map<String, dynamic> json) => _Company(
  id: json['id'] as String,
  name: json['name'] as String,
  nameLower: json['nameLower'] as String,
  city: json['city'] as String?,
  phoneE164: json['phoneE164'] as String?,
  ownerUids: (json['ownerUids'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  nextLoanNo: (json['nextLoanNo'] as num?)?.toInt() ?? 1,
  createdBy: json['createdBy'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$CompanyToJson(_Company instance) => <String, dynamic>{
  'name': instance.name,
  'nameLower': instance.nameLower,
  'city': instance.city,
  'phoneE164': instance.phoneE164,
  'ownerUids': instance.ownerUids,
  'nextLoanNo': instance.nextLoanNo,
  'createdBy': instance.createdBy,
  'createdAt': instance.createdAt.toIso8601String(),
  'schemaVersion': instance.schemaVersion,
};
