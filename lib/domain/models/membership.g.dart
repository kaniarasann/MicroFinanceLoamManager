// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'membership.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Membership _$MembershipFromJson(Map<String, dynamic> json) => _Membership(
  id: json['id'] as String,
  companyId: json['companyId'] as String,
  companyName: json['companyName'] as String,
  role: $enumDecode(_$RoleEnumMap, json['role']),
  joinedAt: DateTime.parse(json['joinedAt'] as String),
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$MembershipToJson(_Membership instance) =>
    <String, dynamic>{
      'companyId': instance.companyId,
      'companyName': instance.companyName,
      'role': _$RoleEnumMap[instance.role]!,
      'joinedAt': instance.joinedAt.toIso8601String(),
      'schemaVersion': instance.schemaVersion,
    };

const _$RoleEnumMap = {Role.owner: 'owner', Role.collector: 'collector'};
