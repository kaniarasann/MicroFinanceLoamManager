// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationPrefs _$NotificationPrefsFromJson(Map<String, dynamic> json) =>
    _NotificationPrefs(
      digestEnabled: json['digestEnabled'] as bool? ?? true,
      digestTime: json['digestTime'] as String? ?? '08:00',
      perInstallmentEnabled: json['perInstallmentEnabled'] as bool? ?? false,
      overdueNudgeEnabled: json['overdueNudgeEnabled'] as bool? ?? true,
    );

Map<String, dynamic> _$NotificationPrefsToJson(_NotificationPrefs instance) =>
    <String, dynamic>{
      'digestEnabled': instance.digestEnabled,
      'digestTime': instance.digestTime,
      'perInstallmentEnabled': instance.perInstallmentEnabled,
      'overdueNudgeEnabled': instance.overdueNudgeEnabled,
    };

_UserSettings _$UserSettingsFromJson(Map<String, dynamic> json) =>
    _UserSettings(
      id: json['id'] as String,
      activeCompanyId: json['activeCompanyId'] as String?,
      notifications: json['notifications'] == null
          ? const NotificationPrefs()
          : NotificationPrefs.fromJson(
              json['notifications'] as Map<String, dynamic>,
            ),
      autoLockMinutes: (json['autoLockMinutes'] as num?)?.toInt() ?? 1,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$UserSettingsToJson(_UserSettings instance) =>
    <String, dynamic>{
      'activeCompanyId': instance.activeCompanyId,
      'notifications': instance.notifications.toJson(),
      'autoLockMinutes': instance.autoLockMinutes,
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'schemaVersion': instance.schemaVersion,
    };
