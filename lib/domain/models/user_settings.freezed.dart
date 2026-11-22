// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationPrefs {

 bool get digestEnabled;/// `'HH:mm'`, IST.
 String get digestTime; bool get perInstallmentEnabled; bool get overdueNudgeEnabled;
/// Create a copy of NotificationPrefs
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPrefsCopyWith<NotificationPrefs> get copyWith => _$NotificationPrefsCopyWithImpl<NotificationPrefs>(this as NotificationPrefs, _$identity);

  /// Serializes this NotificationPrefs to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPrefs&&(identical(other.digestEnabled, digestEnabled) || other.digestEnabled == digestEnabled)&&(identical(other.digestTime, digestTime) || other.digestTime == digestTime)&&(identical(other.perInstallmentEnabled, perInstallmentEnabled) || other.perInstallmentEnabled == perInstallmentEnabled)&&(identical(other.overdueNudgeEnabled, overdueNudgeEnabled) || other.overdueNudgeEnabled == overdueNudgeEnabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,digestEnabled,digestTime,perInstallmentEnabled,overdueNudgeEnabled);

@override
String toString() {
  return 'NotificationPrefs(digestEnabled: $digestEnabled, digestTime: $digestTime, perInstallmentEnabled: $perInstallmentEnabled, overdueNudgeEnabled: $overdueNudgeEnabled)';
}


}

/// @nodoc
abstract mixin class $NotificationPrefsCopyWith<$Res>  {
  factory $NotificationPrefsCopyWith(NotificationPrefs value, $Res Function(NotificationPrefs) _then) = _$NotificationPrefsCopyWithImpl;
@useResult
$Res call({
 bool digestEnabled, String digestTime, bool perInstallmentEnabled, bool overdueNudgeEnabled
});




}
/// @nodoc
class _$NotificationPrefsCopyWithImpl<$Res>
    implements $NotificationPrefsCopyWith<$Res> {
  _$NotificationPrefsCopyWithImpl(this._self, this._then);

  final NotificationPrefs _self;
  final $Res Function(NotificationPrefs) _then;

/// Create a copy of NotificationPrefs
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? digestEnabled = null,Object? digestTime = null,Object? perInstallmentEnabled = null,Object? overdueNudgeEnabled = null,}) {
  return _then(_self.copyWith(
digestEnabled: null == digestEnabled ? _self.digestEnabled : digestEnabled // ignore: cast_nullable_to_non_nullable
as bool,digestTime: null == digestTime ? _self.digestTime : digestTime // ignore: cast_nullable_to_non_nullable
as String,perInstallmentEnabled: null == perInstallmentEnabled ? _self.perInstallmentEnabled : perInstallmentEnabled // ignore: cast_nullable_to_non_nullable
as bool,overdueNudgeEnabled: null == overdueNudgeEnabled ? _self.overdueNudgeEnabled : overdueNudgeEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationPrefs].
extension NotificationPrefsPatterns on NotificationPrefs {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationPrefs value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationPrefs() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationPrefs value)  $default,){
final _that = this;
switch (_that) {
case _NotificationPrefs():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationPrefs value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationPrefs() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool digestEnabled,  String digestTime,  bool perInstallmentEnabled,  bool overdueNudgeEnabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationPrefs() when $default != null:
return $default(_that.digestEnabled,_that.digestTime,_that.perInstallmentEnabled,_that.overdueNudgeEnabled);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool digestEnabled,  String digestTime,  bool perInstallmentEnabled,  bool overdueNudgeEnabled)  $default,) {final _that = this;
switch (_that) {
case _NotificationPrefs():
return $default(_that.digestEnabled,_that.digestTime,_that.perInstallmentEnabled,_that.overdueNudgeEnabled);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool digestEnabled,  String digestTime,  bool perInstallmentEnabled,  bool overdueNudgeEnabled)?  $default,) {final _that = this;
switch (_that) {
case _NotificationPrefs() when $default != null:
return $default(_that.digestEnabled,_that.digestTime,_that.perInstallmentEnabled,_that.overdueNudgeEnabled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationPrefs implements NotificationPrefs {
  const _NotificationPrefs({this.digestEnabled = true, this.digestTime = '08:00', this.perInstallmentEnabled = false, this.overdueNudgeEnabled = true});
  factory _NotificationPrefs.fromJson(Map<String, dynamic> json) => _$NotificationPrefsFromJson(json);

@override@JsonKey() final  bool digestEnabled;
/// `'HH:mm'`, IST.
@override@JsonKey() final  String digestTime;
@override@JsonKey() final  bool perInstallmentEnabled;
@override@JsonKey() final  bool overdueNudgeEnabled;

/// Create a copy of NotificationPrefs
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationPrefsCopyWith<_NotificationPrefs> get copyWith => __$NotificationPrefsCopyWithImpl<_NotificationPrefs>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationPrefsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationPrefs&&(identical(other.digestEnabled, digestEnabled) || other.digestEnabled == digestEnabled)&&(identical(other.digestTime, digestTime) || other.digestTime == digestTime)&&(identical(other.perInstallmentEnabled, perInstallmentEnabled) || other.perInstallmentEnabled == perInstallmentEnabled)&&(identical(other.overdueNudgeEnabled, overdueNudgeEnabled) || other.overdueNudgeEnabled == overdueNudgeEnabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,digestEnabled,digestTime,perInstallmentEnabled,overdueNudgeEnabled);

@override
String toString() {
  return 'NotificationPrefs(digestEnabled: $digestEnabled, digestTime: $digestTime, perInstallmentEnabled: $perInstallmentEnabled, overdueNudgeEnabled: $overdueNudgeEnabled)';
}


}

/// @nodoc
abstract mixin class _$NotificationPrefsCopyWith<$Res> implements $NotificationPrefsCopyWith<$Res> {
  factory _$NotificationPrefsCopyWith(_NotificationPrefs value, $Res Function(_NotificationPrefs) _then) = __$NotificationPrefsCopyWithImpl;
@override @useResult
$Res call({
 bool digestEnabled, String digestTime, bool perInstallmentEnabled, bool overdueNudgeEnabled
});




}
/// @nodoc
class __$NotificationPrefsCopyWithImpl<$Res>
    implements _$NotificationPrefsCopyWith<$Res> {
  __$NotificationPrefsCopyWithImpl(this._self, this._then);

  final _NotificationPrefs _self;
  final $Res Function(_NotificationPrefs) _then;

/// Create a copy of NotificationPrefs
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? digestEnabled = null,Object? digestTime = null,Object? perInstallmentEnabled = null,Object? overdueNudgeEnabled = null,}) {
  return _then(_NotificationPrefs(
digestEnabled: null == digestEnabled ? _self.digestEnabled : digestEnabled // ignore: cast_nullable_to_non_nullable
as bool,digestTime: null == digestTime ? _self.digestTime : digestTime // ignore: cast_nullable_to_non_nullable
as String,perInstallmentEnabled: null == perInstallmentEnabled ? _self.perInstallmentEnabled : perInstallmentEnabled // ignore: cast_nullable_to_non_nullable
as bool,overdueNudgeEnabled: null == overdueNudgeEnabled ? _self.overdueNudgeEnabled : overdueNudgeEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$UserSettings {

@JsonKey(includeToJson: false) String get id; String? get activeCompanyId; NotificationPrefs get notifications; int get autoLockMinutes;/// Server-stamped on every write; `null` while the write is pending.
 DateTime? get updatedAt; int get schemaVersion;
/// Create a copy of UserSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserSettingsCopyWith<UserSettings> get copyWith => _$UserSettingsCopyWithImpl<UserSettings>(this as UserSettings, _$identity);

  /// Serializes this UserSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserSettings&&(identical(other.id, id) || other.id == id)&&(identical(other.activeCompanyId, activeCompanyId) || other.activeCompanyId == activeCompanyId)&&(identical(other.notifications, notifications) || other.notifications == notifications)&&(identical(other.autoLockMinutes, autoLockMinutes) || other.autoLockMinutes == autoLockMinutes)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,activeCompanyId,notifications,autoLockMinutes,updatedAt,schemaVersion);

@override
String toString() {
  return 'UserSettings(id: $id, activeCompanyId: $activeCompanyId, notifications: $notifications, autoLockMinutes: $autoLockMinutes, updatedAt: $updatedAt, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class $UserSettingsCopyWith<$Res>  {
  factory $UserSettingsCopyWith(UserSettings value, $Res Function(UserSettings) _then) = _$UserSettingsCopyWithImpl;
@useResult
$Res call({
@JsonKey(includeToJson: false) String id, String? activeCompanyId, NotificationPrefs notifications, int autoLockMinutes, DateTime? updatedAt, int schemaVersion
});


$NotificationPrefsCopyWith<$Res> get notifications;

}
/// @nodoc
class _$UserSettingsCopyWithImpl<$Res>
    implements $UserSettingsCopyWith<$Res> {
  _$UserSettingsCopyWithImpl(this._self, this._then);

  final UserSettings _self;
  final $Res Function(UserSettings) _then;

/// Create a copy of UserSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? activeCompanyId = freezed,Object? notifications = null,Object? autoLockMinutes = null,Object? updatedAt = freezed,Object? schemaVersion = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activeCompanyId: freezed == activeCompanyId ? _self.activeCompanyId : activeCompanyId // ignore: cast_nullable_to_non_nullable
as String?,notifications: null == notifications ? _self.notifications : notifications // ignore: cast_nullable_to_non_nullable
as NotificationPrefs,autoLockMinutes: null == autoLockMinutes ? _self.autoLockMinutes : autoLockMinutes // ignore: cast_nullable_to_non_nullable
as int,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of UserSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationPrefsCopyWith<$Res> get notifications {
  
  return $NotificationPrefsCopyWith<$Res>(_self.notifications, (value) {
    return _then(_self.copyWith(notifications: value));
  });
}
}


/// Adds pattern-matching-related methods to [UserSettings].
extension UserSettingsPatterns on UserSettings {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserSettings() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserSettings value)  $default,){
final _that = this;
switch (_that) {
case _UserSettings():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserSettings value)?  $default,){
final _that = this;
switch (_that) {
case _UserSettings() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String id,  String? activeCompanyId,  NotificationPrefs notifications,  int autoLockMinutes,  DateTime? updatedAt,  int schemaVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserSettings() when $default != null:
return $default(_that.id,_that.activeCompanyId,_that.notifications,_that.autoLockMinutes,_that.updatedAt,_that.schemaVersion);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String id,  String? activeCompanyId,  NotificationPrefs notifications,  int autoLockMinutes,  DateTime? updatedAt,  int schemaVersion)  $default,) {final _that = this;
switch (_that) {
case _UserSettings():
return $default(_that.id,_that.activeCompanyId,_that.notifications,_that.autoLockMinutes,_that.updatedAt,_that.schemaVersion);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(includeToJson: false)  String id,  String? activeCompanyId,  NotificationPrefs notifications,  int autoLockMinutes,  DateTime? updatedAt,  int schemaVersion)?  $default,) {final _that = this;
switch (_that) {
case _UserSettings() when $default != null:
return $default(_that.id,_that.activeCompanyId,_that.notifications,_that.autoLockMinutes,_that.updatedAt,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserSettings extends UserSettings {
  const _UserSettings({@JsonKey(includeToJson: false) required this.id, this.activeCompanyId, this.notifications = const NotificationPrefs(), this.autoLockMinutes = 1, this.updatedAt, this.schemaVersion = 1}): super._();
  factory _UserSettings.fromJson(Map<String, dynamic> json) => _$UserSettingsFromJson(json);

@override@JsonKey(includeToJson: false) final  String id;
@override final  String? activeCompanyId;
@override@JsonKey() final  NotificationPrefs notifications;
@override@JsonKey() final  int autoLockMinutes;
/// Server-stamped on every write; `null` while the write is pending.
@override final  DateTime? updatedAt;
@override@JsonKey() final  int schemaVersion;

/// Create a copy of UserSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserSettingsCopyWith<_UserSettings> get copyWith => __$UserSettingsCopyWithImpl<_UserSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserSettings&&(identical(other.id, id) || other.id == id)&&(identical(other.activeCompanyId, activeCompanyId) || other.activeCompanyId == activeCompanyId)&&(identical(other.notifications, notifications) || other.notifications == notifications)&&(identical(other.autoLockMinutes, autoLockMinutes) || other.autoLockMinutes == autoLockMinutes)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,activeCompanyId,notifications,autoLockMinutes,updatedAt,schemaVersion);

@override
String toString() {
  return 'UserSettings(id: $id, activeCompanyId: $activeCompanyId, notifications: $notifications, autoLockMinutes: $autoLockMinutes, updatedAt: $updatedAt, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class _$UserSettingsCopyWith<$Res> implements $UserSettingsCopyWith<$Res> {
  factory _$UserSettingsCopyWith(_UserSettings value, $Res Function(_UserSettings) _then) = __$UserSettingsCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(includeToJson: false) String id, String? activeCompanyId, NotificationPrefs notifications, int autoLockMinutes, DateTime? updatedAt, int schemaVersion
});


@override $NotificationPrefsCopyWith<$Res> get notifications;

}
/// @nodoc
class __$UserSettingsCopyWithImpl<$Res>
    implements _$UserSettingsCopyWith<$Res> {
  __$UserSettingsCopyWithImpl(this._self, this._then);

  final _UserSettings _self;
  final $Res Function(_UserSettings) _then;

/// Create a copy of UserSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? activeCompanyId = freezed,Object? notifications = null,Object? autoLockMinutes = null,Object? updatedAt = freezed,Object? schemaVersion = null,}) {
  return _then(_UserSettings(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activeCompanyId: freezed == activeCompanyId ? _self.activeCompanyId : activeCompanyId // ignore: cast_nullable_to_non_nullable
as String?,notifications: null == notifications ? _self.notifications : notifications // ignore: cast_nullable_to_non_nullable
as NotificationPrefs,autoLockMinutes: null == autoLockMinutes ? _self.autoLockMinutes : autoLockMinutes // ignore: cast_nullable_to_non_nullable
as int,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of UserSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationPrefsCopyWith<$Res> get notifications {
  
  return $NotificationPrefsCopyWith<$Res>(_self.notifications, (value) {
    return _then(_self.copyWith(notifications: value));
  });
}
}

// dart format on
