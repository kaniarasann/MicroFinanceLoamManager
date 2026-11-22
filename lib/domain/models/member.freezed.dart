// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'member.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Member {

@JsonKey(includeToJson: false) String get id; String get uid; Role get role; String get displayName; String? get phoneE164;/// Always `'active'` in schema v1.
 String get status; String? get inviteCode; String? get invitedBy; DateTime get joinedAt; int get schemaVersion;
/// Create a copy of Member
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MemberCopyWith<Member> get copyWith => _$MemberCopyWithImpl<Member>(this as Member, _$identity);

  /// Serializes this Member to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Member&&(identical(other.id, id) || other.id == id)&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.role, role) || other.role == role)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.phoneE164, phoneE164) || other.phoneE164 == phoneE164)&&(identical(other.status, status) || other.status == status)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&(identical(other.invitedBy, invitedBy) || other.invitedBy == invitedBy)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,uid,role,displayName,phoneE164,status,inviteCode,invitedBy,joinedAt,schemaVersion);

@override
String toString() {
  return 'Member(id: $id, uid: $uid, role: $role, displayName: $displayName, phoneE164: $phoneE164, status: $status, inviteCode: $inviteCode, invitedBy: $invitedBy, joinedAt: $joinedAt, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class $MemberCopyWith<$Res>  {
  factory $MemberCopyWith(Member value, $Res Function(Member) _then) = _$MemberCopyWithImpl;
@useResult
$Res call({
@JsonKey(includeToJson: false) String id, String uid, Role role, String displayName, String? phoneE164, String status, String? inviteCode, String? invitedBy, DateTime joinedAt, int schemaVersion
});




}
/// @nodoc
class _$MemberCopyWithImpl<$Res>
    implements $MemberCopyWith<$Res> {
  _$MemberCopyWithImpl(this._self, this._then);

  final Member _self;
  final $Res Function(Member) _then;

/// Create a copy of Member
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? uid = null,Object? role = null,Object? displayName = null,Object? phoneE164 = freezed,Object? status = null,Object? inviteCode = freezed,Object? invitedBy = freezed,Object? joinedAt = null,Object? schemaVersion = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as Role,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,phoneE164: freezed == phoneE164 ? _self.phoneE164 : phoneE164 // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,inviteCode: freezed == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String?,invitedBy: freezed == invitedBy ? _self.invitedBy : invitedBy // ignore: cast_nullable_to_non_nullable
as String?,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Member].
extension MemberPatterns on Member {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Member value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Member() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Member value)  $default,){
final _that = this;
switch (_that) {
case _Member():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Member value)?  $default,){
final _that = this;
switch (_that) {
case _Member() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String id,  String uid,  Role role,  String displayName,  String? phoneE164,  String status,  String? inviteCode,  String? invitedBy,  DateTime joinedAt,  int schemaVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Member() when $default != null:
return $default(_that.id,_that.uid,_that.role,_that.displayName,_that.phoneE164,_that.status,_that.inviteCode,_that.invitedBy,_that.joinedAt,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String id,  String uid,  Role role,  String displayName,  String? phoneE164,  String status,  String? inviteCode,  String? invitedBy,  DateTime joinedAt,  int schemaVersion)  $default,) {final _that = this;
switch (_that) {
case _Member():
return $default(_that.id,_that.uid,_that.role,_that.displayName,_that.phoneE164,_that.status,_that.inviteCode,_that.invitedBy,_that.joinedAt,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(includeToJson: false)  String id,  String uid,  Role role,  String displayName,  String? phoneE164,  String status,  String? inviteCode,  String? invitedBy,  DateTime joinedAt,  int schemaVersion)?  $default,) {final _that = this;
switch (_that) {
case _Member() when $default != null:
return $default(_that.id,_that.uid,_that.role,_that.displayName,_that.phoneE164,_that.status,_that.inviteCode,_that.invitedBy,_that.joinedAt,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Member implements Member {
  const _Member({@JsonKey(includeToJson: false) required this.id, required this.uid, required this.role, required this.displayName, this.phoneE164, this.status = 'active', this.inviteCode, this.invitedBy, required this.joinedAt, this.schemaVersion = 1});
  factory _Member.fromJson(Map<String, dynamic> json) => _$MemberFromJson(json);

@override@JsonKey(includeToJson: false) final  String id;
@override final  String uid;
@override final  Role role;
@override final  String displayName;
@override final  String? phoneE164;
/// Always `'active'` in schema v1.
@override@JsonKey() final  String status;
@override final  String? inviteCode;
@override final  String? invitedBy;
@override final  DateTime joinedAt;
@override@JsonKey() final  int schemaVersion;

/// Create a copy of Member
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MemberCopyWith<_Member> get copyWith => __$MemberCopyWithImpl<_Member>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MemberToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Member&&(identical(other.id, id) || other.id == id)&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.role, role) || other.role == role)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.phoneE164, phoneE164) || other.phoneE164 == phoneE164)&&(identical(other.status, status) || other.status == status)&&(identical(other.inviteCode, inviteCode) || other.inviteCode == inviteCode)&&(identical(other.invitedBy, invitedBy) || other.invitedBy == invitedBy)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,uid,role,displayName,phoneE164,status,inviteCode,invitedBy,joinedAt,schemaVersion);

@override
String toString() {
  return 'Member(id: $id, uid: $uid, role: $role, displayName: $displayName, phoneE164: $phoneE164, status: $status, inviteCode: $inviteCode, invitedBy: $invitedBy, joinedAt: $joinedAt, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class _$MemberCopyWith<$Res> implements $MemberCopyWith<$Res> {
  factory _$MemberCopyWith(_Member value, $Res Function(_Member) _then) = __$MemberCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(includeToJson: false) String id, String uid, Role role, String displayName, String? phoneE164, String status, String? inviteCode, String? invitedBy, DateTime joinedAt, int schemaVersion
});




}
/// @nodoc
class __$MemberCopyWithImpl<$Res>
    implements _$MemberCopyWith<$Res> {
  __$MemberCopyWithImpl(this._self, this._then);

  final _Member _self;
  final $Res Function(_Member) _then;

/// Create a copy of Member
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? uid = null,Object? role = null,Object? displayName = null,Object? phoneE164 = freezed,Object? status = null,Object? inviteCode = freezed,Object? invitedBy = freezed,Object? joinedAt = null,Object? schemaVersion = null,}) {
  return _then(_Member(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as Role,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,phoneE164: freezed == phoneE164 ? _self.phoneE164 : phoneE164 // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,inviteCode: freezed == inviteCode ? _self.inviteCode : inviteCode // ignore: cast_nullable_to_non_nullable
as String?,invitedBy: freezed == invitedBy ? _self.invitedBy : invitedBy // ignore: cast_nullable_to_non_nullable
as String?,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
