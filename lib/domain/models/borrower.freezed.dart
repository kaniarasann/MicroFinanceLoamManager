// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'borrower.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Borrower {

@JsonKey(includeToJson: false) String get id; String get name; String get nameLower; String get phoneE164; String? get locality; String? get notes; bool get archived; String get createdBy; DateTime get createdAt; DateTime get updatedAt; int get schemaVersion;
/// Create a copy of Borrower
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BorrowerCopyWith<Borrower> get copyWith => _$BorrowerCopyWithImpl<Borrower>(this as Borrower, _$identity);

  /// Serializes this Borrower to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Borrower&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.nameLower, nameLower) || other.nameLower == nameLower)&&(identical(other.phoneE164, phoneE164) || other.phoneE164 == phoneE164)&&(identical(other.locality, locality) || other.locality == locality)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.archived, archived) || other.archived == archived)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,nameLower,phoneE164,locality,notes,archived,createdBy,createdAt,updatedAt,schemaVersion);

@override
String toString() {
  return 'Borrower(id: $id, name: $name, nameLower: $nameLower, phoneE164: $phoneE164, locality: $locality, notes: $notes, archived: $archived, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class $BorrowerCopyWith<$Res>  {
  factory $BorrowerCopyWith(Borrower value, $Res Function(Borrower) _then) = _$BorrowerCopyWithImpl;
@useResult
$Res call({
@JsonKey(includeToJson: false) String id, String name, String nameLower, String phoneE164, String? locality, String? notes, bool archived, String createdBy, DateTime createdAt, DateTime updatedAt, int schemaVersion
});




}
/// @nodoc
class _$BorrowerCopyWithImpl<$Res>
    implements $BorrowerCopyWith<$Res> {
  _$BorrowerCopyWithImpl(this._self, this._then);

  final Borrower _self;
  final $Res Function(Borrower) _then;

/// Create a copy of Borrower
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? nameLower = null,Object? phoneE164 = null,Object? locality = freezed,Object? notes = freezed,Object? archived = null,Object? createdBy = null,Object? createdAt = null,Object? updatedAt = null,Object? schemaVersion = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nameLower: null == nameLower ? _self.nameLower : nameLower // ignore: cast_nullable_to_non_nullable
as String,phoneE164: null == phoneE164 ? _self.phoneE164 : phoneE164 // ignore: cast_nullable_to_non_nullable
as String,locality: freezed == locality ? _self.locality : locality // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Borrower].
extension BorrowerPatterns on Borrower {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Borrower value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Borrower() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Borrower value)  $default,){
final _that = this;
switch (_that) {
case _Borrower():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Borrower value)?  $default,){
final _that = this;
switch (_that) {
case _Borrower() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String id,  String name,  String nameLower,  String phoneE164,  String? locality,  String? notes,  bool archived,  String createdBy,  DateTime createdAt,  DateTime updatedAt,  int schemaVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Borrower() when $default != null:
return $default(_that.id,_that.name,_that.nameLower,_that.phoneE164,_that.locality,_that.notes,_that.archived,_that.createdBy,_that.createdAt,_that.updatedAt,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String id,  String name,  String nameLower,  String phoneE164,  String? locality,  String? notes,  bool archived,  String createdBy,  DateTime createdAt,  DateTime updatedAt,  int schemaVersion)  $default,) {final _that = this;
switch (_that) {
case _Borrower():
return $default(_that.id,_that.name,_that.nameLower,_that.phoneE164,_that.locality,_that.notes,_that.archived,_that.createdBy,_that.createdAt,_that.updatedAt,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(includeToJson: false)  String id,  String name,  String nameLower,  String phoneE164,  String? locality,  String? notes,  bool archived,  String createdBy,  DateTime createdAt,  DateTime updatedAt,  int schemaVersion)?  $default,) {final _that = this;
switch (_that) {
case _Borrower() when $default != null:
return $default(_that.id,_that.name,_that.nameLower,_that.phoneE164,_that.locality,_that.notes,_that.archived,_that.createdBy,_that.createdAt,_that.updatedAt,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Borrower implements Borrower {
  const _Borrower({@JsonKey(includeToJson: false) required this.id, required this.name, required this.nameLower, required this.phoneE164, this.locality, this.notes, this.archived = false, required this.createdBy, required this.createdAt, required this.updatedAt, this.schemaVersion = 1});
  factory _Borrower.fromJson(Map<String, dynamic> json) => _$BorrowerFromJson(json);

@override@JsonKey(includeToJson: false) final  String id;
@override final  String name;
@override final  String nameLower;
@override final  String phoneE164;
@override final  String? locality;
@override final  String? notes;
@override@JsonKey() final  bool archived;
@override final  String createdBy;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override@JsonKey() final  int schemaVersion;

/// Create a copy of Borrower
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BorrowerCopyWith<_Borrower> get copyWith => __$BorrowerCopyWithImpl<_Borrower>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BorrowerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Borrower&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.nameLower, nameLower) || other.nameLower == nameLower)&&(identical(other.phoneE164, phoneE164) || other.phoneE164 == phoneE164)&&(identical(other.locality, locality) || other.locality == locality)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.archived, archived) || other.archived == archived)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,nameLower,phoneE164,locality,notes,archived,createdBy,createdAt,updatedAt,schemaVersion);

@override
String toString() {
  return 'Borrower(id: $id, name: $name, nameLower: $nameLower, phoneE164: $phoneE164, locality: $locality, notes: $notes, archived: $archived, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class _$BorrowerCopyWith<$Res> implements $BorrowerCopyWith<$Res> {
  factory _$BorrowerCopyWith(_Borrower value, $Res Function(_Borrower) _then) = __$BorrowerCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(includeToJson: false) String id, String name, String nameLower, String phoneE164, String? locality, String? notes, bool archived, String createdBy, DateTime createdAt, DateTime updatedAt, int schemaVersion
});




}
/// @nodoc
class __$BorrowerCopyWithImpl<$Res>
    implements _$BorrowerCopyWith<$Res> {
  __$BorrowerCopyWithImpl(this._self, this._then);

  final _Borrower _self;
  final $Res Function(_Borrower) _then;

/// Create a copy of Borrower
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? nameLower = null,Object? phoneE164 = null,Object? locality = freezed,Object? notes = freezed,Object? archived = null,Object? createdBy = null,Object? createdAt = null,Object? updatedAt = null,Object? schemaVersion = null,}) {
  return _then(_Borrower(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nameLower: null == nameLower ? _self.nameLower : nameLower // ignore: cast_nullable_to_non_nullable
as String,phoneE164: null == phoneE164 ? _self.phoneE164 : phoneE164 // ignore: cast_nullable_to_non_nullable
as String,locality: freezed == locality ? _self.locality : locality // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
