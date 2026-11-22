// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Invite _$InviteFromJson(Map<String, dynamic> json) => _Invite(
  id: json['id'] as String,
  companyId: json['companyId'] as String,
  companyName: json['companyName'] as String,
  companyCity: json['companyCity'] as String?,
  role: $enumDecode(_$RoleEnumMap, json['role']),
  inviteeName: json['inviteeName'] as String,
  inviteePhoneE164: json['inviteePhoneE164'] as String,
  createdBy: json['createdBy'] as String,
  createdByName: json['createdByName'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  status:
      $enumDecodeNullable(_$InviteStatusEnumMap, json['status']) ??
      InviteStatus.pending,
  acceptedBy: json['acceptedBy'] as String?,
  acceptedAt: json['acceptedAt'] == null
      ? null
      : DateTime.parse(json['acceptedAt'] as String),
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$InviteToJson(_Invite instance) => <String, dynamic>{
  'companyId': instance.companyId,
  'companyName': instance.companyName,
  'companyCity': instance.companyCity,
  'role': _$RoleEnumMap[instance.role]!,
  'inviteeName': instance.inviteeName,
  'inviteePhoneE164': instance.inviteePhoneE164,
  'createdBy': instance.createdBy,
  'createdByName': instance.createdByName,
  'createdAt': instance.createdAt.toIso8601String(),
  'expiresAt': instance.expiresAt.toIso8601String(),
  'status': _$InviteStatusEnumMap[instance.status]!,
  'acceptedBy': instance.acceptedBy,
  'acceptedAt': instance.acceptedAt?.toIso8601String(),
  'schemaVersion': instance.schemaVersion,
};

const _$RoleEnumMap = {Role.owner: 'owner', Role.collector: 'collector'};

const _$InviteStatusEnumMap = {
  InviteStatus.pending: 'pending',
  InviteStatus.accepted: 'accepted',
  InviteStatus.revoked: 'revoked',
};
