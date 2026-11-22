// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Member _$MemberFromJson(Map<String, dynamic> json) => _Member(
  id: json['id'] as String,
  uid: json['uid'] as String,
  role: $enumDecode(_$RoleEnumMap, json['role']),
  displayName: json['displayName'] as String,
  phoneE164: json['phoneE164'] as String?,
  status: json['status'] as String? ?? 'active',
  inviteCode: json['inviteCode'] as String?,
  invitedBy: json['invitedBy'] as String?,
  joinedAt: DateTime.parse(json['joinedAt'] as String),
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$MemberToJson(_Member instance) => <String, dynamic>{
  'uid': instance.uid,
  'role': _$RoleEnumMap[instance.role]!,
  'displayName': instance.displayName,
  'phoneE164': instance.phoneE164,
  'status': instance.status,
  'inviteCode': instance.inviteCode,
  'invitedBy': instance.invitedBy,
  'joinedAt': instance.joinedAt.toIso8601String(),
  'schemaVersion': instance.schemaVersion,
};

const _$RoleEnumMap = {Role.owner: 'owner', Role.collector: 'collector'};
