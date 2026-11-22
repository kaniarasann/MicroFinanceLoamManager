// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invite.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Invite {

@JsonKey(includeToJson: false) String get id; String get companyId; String get companyName; String? get companyCity; Role get role; String get inviteeName; String get inviteePhoneE164; String get createdBy; String get createdByName; DateTime get createdAt;/// createdAt + 7 days.
 DateTime get expiresAt; InviteStatus get status; String? get acceptedBy; DateTime? get acceptedAt; int get schemaVersion;
/// Create a copy of Invite
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InviteCopyWith<Invite> get copyWith => _$InviteCopyWithImpl<Invite>(this as Invite, _$identity);

  /// Serializes this Invite to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Invite&&(identical(other.id, id) || other.id == id)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.companyCity, companyCity) || other.companyCity == companyCity)&&(identical(other.role, role) || other.role == role)&&(identical(other.inviteeName, inviteeName) || other.inviteeName == inviteeName)&&(identical(other.inviteePhoneE164, inviteePhoneE164) || other.inviteePhoneE164 == inviteePhoneE164)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdByName, createdByName) || other.createdByName == createdByName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.acceptedBy, acceptedBy) || other.acceptedBy == acceptedBy)&&(identical(other.acceptedAt, acceptedAt) || other.acceptedAt == acceptedAt)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,companyId,companyName,companyCity,role,inviteeName,inviteePhoneE164,createdBy,createdByName,createdAt,expiresAt,status,acceptedBy,acceptedAt,schemaVersion);

@override
String toString() {
  return 'Invite(id: $id, companyId: $companyId, companyName: $companyName, companyCity: $companyCity, role: $role, inviteeName: $inviteeName, inviteePhoneE164: $inviteePhoneE164, createdBy: $createdBy, createdByName: $createdByName, createdAt: $createdAt, expiresAt: $expiresAt, status: $status, acceptedBy: $acceptedBy, acceptedAt: $acceptedAt, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class $InviteCopyWith<$Res>  {
  factory $InviteCopyWith(Invite value, $Res Function(Invite) _then) = _$InviteCopyWithImpl;
@useResult
$Res call({
@JsonKey(includeToJson: false) String id, String companyId, String companyName, String? companyCity, Role role, String inviteeName, String inviteePhoneE164, String createdBy, String createdByName, DateTime createdAt, DateTime expiresAt, InviteStatus status, String? acceptedBy, DateTime? acceptedAt, int schemaVersion
});




}
/// @nodoc
class _$InviteCopyWithImpl<$Res>
    implements $InviteCopyWith<$Res> {
  _$InviteCopyWithImpl(this._self, this._then);

  final Invite _self;
  final $Res Function(Invite) _then;

/// Create a copy of Invite
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? companyId = null,Object? companyName = null,Object? companyCity = freezed,Object? role = null,Object? inviteeName = null,Object? inviteePhoneE164 = null,Object? createdBy = null,Object? createdByName = null,Object? createdAt = null,Object? expiresAt = null,Object? status = null,Object? acceptedBy = freezed,Object? acceptedAt = freezed,Object? schemaVersion = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as String,companyName: null == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String,companyCity: freezed == companyCity ? _self.companyCity : companyCity // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as Role,inviteeName: null == inviteeName ? _self.inviteeName : inviteeName // ignore: cast_nullable_to_non_nullable
as String,inviteePhoneE164: null == inviteePhoneE164 ? _self.inviteePhoneE164 : inviteePhoneE164 // ignore: cast_nullable_to_non_nullable
as String,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdByName: null == createdByName ? _self.createdByName : createdByName // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as InviteStatus,acceptedBy: freezed == acceptedBy ? _self.acceptedBy : acceptedBy // ignore: cast_nullable_to_non_nullable
as String?,acceptedAt: freezed == acceptedAt ? _self.acceptedAt : acceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Invite].
extension InvitePatterns on Invite {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Invite value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Invite() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Invite value)  $default,){
final _that = this;
switch (_that) {
case _Invite():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Invite value)?  $default,){
final _that = this;
switch (_that) {
case _Invite() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String id,  String companyId,  String companyName,  String? companyCity,  Role role,  String inviteeName,  String inviteePhoneE164,  String createdBy,  String createdByName,  DateTime createdAt,  DateTime expiresAt,  InviteStatus status,  String? acceptedBy,  DateTime? acceptedAt,  int schemaVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Invite() when $default != null:
return $default(_that.id,_that.companyId,_that.companyName,_that.companyCity,_that.role,_that.inviteeName,_that.inviteePhoneE164,_that.createdBy,_that.createdByName,_that.createdAt,_that.expiresAt,_that.status,_that.acceptedBy,_that.acceptedAt,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String id,  String companyId,  String companyName,  String? companyCity,  Role role,  String inviteeName,  String inviteePhoneE164,  String createdBy,  String createdByName,  DateTime createdAt,  DateTime expiresAt,  InviteStatus status,  String? acceptedBy,  DateTime? acceptedAt,  int schemaVersion)  $default,) {final _that = this;
switch (_that) {
case _Invite():
return $default(_that.id,_that.companyId,_that.companyName,_that.companyCity,_that.role,_that.inviteeName,_that.inviteePhoneE164,_that.createdBy,_that.createdByName,_that.createdAt,_that.expiresAt,_that.status,_that.acceptedBy,_that.acceptedAt,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(includeToJson: false)  String id,  String companyId,  String companyName,  String? companyCity,  Role role,  String inviteeName,  String inviteePhoneE164,  String createdBy,  String createdByName,  DateTime createdAt,  DateTime expiresAt,  InviteStatus status,  String? acceptedBy,  DateTime? acceptedAt,  int schemaVersion)?  $default,) {final _that = this;
switch (_that) {
case _Invite() when $default != null:
return $default(_that.id,_that.companyId,_that.companyName,_that.companyCity,_that.role,_that.inviteeName,_that.inviteePhoneE164,_that.createdBy,_that.createdByName,_that.createdAt,_that.expiresAt,_that.status,_that.acceptedBy,_that.acceptedAt,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Invite extends Invite {
  const _Invite({@JsonKey(includeToJson: false) required this.id, required this.companyId, required this.companyName, this.companyCity, required this.role, required this.inviteeName, required this.inviteePhoneE164, required this.createdBy, required this.createdByName, required this.createdAt, required this.expiresAt, this.status = InviteStatus.pending, this.acceptedBy, this.acceptedAt, this.schemaVersion = 1}): super._();
  factory _Invite.fromJson(Map<String, dynamic> json) => _$InviteFromJson(json);

@override@JsonKey(includeToJson: false) final  String id;
@override final  String companyId;
@override final  String companyName;
@override final  String? companyCity;
@override final  Role role;
@override final  String inviteeName;
@override final  String inviteePhoneE164;
@override final  String createdBy;
@override final  String createdByName;
@override final  DateTime createdAt;
/// createdAt + 7 days.
@override final  DateTime expiresAt;
@override@JsonKey() final  InviteStatus status;
@override final  String? acceptedBy;
@override final  DateTime? acceptedAt;
@override@JsonKey() final  int schemaVersion;

/// Create a copy of Invite
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InviteCopyWith<_Invite> get copyWith => __$InviteCopyWithImpl<_Invite>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InviteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Invite&&(identical(other.id, id) || other.id == id)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.companyCity, companyCity) || other.companyCity == companyCity)&&(identical(other.role, role) || other.role == role)&&(identical(other.inviteeName, inviteeName) || other.inviteeName == inviteeName)&&(identical(other.inviteePhoneE164, inviteePhoneE164) || other.inviteePhoneE164 == inviteePhoneE164)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdByName, createdByName) || other.createdByName == createdByName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.acceptedBy, acceptedBy) || other.acceptedBy == acceptedBy)&&(identical(other.acceptedAt, acceptedAt) || other.acceptedAt == acceptedAt)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,companyId,companyName,companyCity,role,inviteeName,inviteePhoneE164,createdBy,createdByName,createdAt,expiresAt,status,acceptedBy,acceptedAt,schemaVersion);

@override
String toString() {
  return 'Invite(id: $id, companyId: $companyId, companyName: $companyName, companyCity: $companyCity, role: $role, inviteeName: $inviteeName, inviteePhoneE164: $inviteePhoneE164, createdBy: $createdBy, createdByName: $createdByName, createdAt: $createdAt, expiresAt: $expiresAt, status: $status, acceptedBy: $acceptedBy, acceptedAt: $acceptedAt, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class _$InviteCopyWith<$Res> implements $InviteCopyWith<$Res> {
  factory _$InviteCopyWith(_Invite value, $Res Function(_Invite) _then) = __$InviteCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(includeToJson: false) String id, String companyId, String companyName, String? companyCity, Role role, String inviteeName, String inviteePhoneE164, String createdBy, String createdByName, DateTime createdAt, DateTime expiresAt, InviteStatus status, String? acceptedBy, DateTime? acceptedAt, int schemaVersion
});




}
/// @nodoc
class __$InviteCopyWithImpl<$Res>
    implements _$InviteCopyWith<$Res> {
  __$InviteCopyWithImpl(this._self, this._then);

  final _Invite _self;
  final $Res Function(_Invite) _then;

/// Create a copy of Invite
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? companyId = null,Object? companyName = null,Object? companyCity = freezed,Object? role = null,Object? inviteeName = null,Object? inviteePhoneE164 = null,Object? createdBy = null,Object? createdByName = null,Object? createdAt = null,Object? expiresAt = null,Object? status = null,Object? acceptedBy = freezed,Object? acceptedAt = freezed,Object? schemaVersion = null,}) {
  return _then(_Invite(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as String,companyName: null == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String,companyCity: freezed == companyCity ? _self.companyCity : companyCity // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as Role,inviteeName: null == inviteeName ? _self.inviteeName : inviteeName // ignore: cast_nullable_to_non_nullable
as String,inviteePhoneE164: null == inviteePhoneE164 ? _self.inviteePhoneE164 : inviteePhoneE164 // ignore: cast_nullable_to_non_nullable
as String,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdByName: null == createdByName ? _self.createdByName : createdByName // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as InviteStatus,acceptedBy: freezed == acceptedBy ? _self.acceptedBy : acceptedBy // ignore: cast_nullable_to_non_nullable
as String?,acceptedAt: freezed == acceptedAt ? _self.acceptedAt : acceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
