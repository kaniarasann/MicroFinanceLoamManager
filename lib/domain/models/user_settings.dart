import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_settings.freezed.dart';
part 'user_settings.g.dart';

/// Notification preferences embedded in [UserSettings.notifications].
@freezed
abstract class NotificationPrefs with _$NotificationPrefs {
  const factory NotificationPrefs({
    @Default(true) bool digestEnabled,

    /// `'HH:mm'`, IST.
    @Default('08:00') String digestTime,
    @Default(false) bool perInstallmentEnabled,
    @Default(true) bool overdueNudgeEnabled,
  }) = _NotificationPrefs;

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) =>
      _$NotificationPrefsFromJson(json);
}

/// `user_settings/{uid}`. [id] is the uid.
///
/// MPIN hash/salt, biometric flag and lockout counter are device-local and
/// deliberately absent here.
@freezed
abstract class UserSettings with _$UserSettings {
  const factory UserSettings({
    @JsonKey(includeToJson: false) required String id,
    String? activeCompanyId,
    @Default(NotificationPrefs()) NotificationPrefs notifications,
    @Default(1) int autoLockMinutes,

    /// Server-stamped on every write; `null` while the write is pending.
    DateTime? updatedAt,
    @Default(1) int schemaVersion,
  }) = _UserSettings;

  const UserSettings._();

  /// Defaults for a new user: 08:00 digest on, per-installment off,
  /// overdue nudge on, auto-lock after 1 minute.
  factory UserSettings.defaults(String uid) => UserSettings(id: uid);

  factory UserSettings.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsFromJson(json);
}
