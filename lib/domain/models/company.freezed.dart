// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'company.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Company {

@JsonKey(includeToJson: false) String get id; String get name; String get nameLower; String? get city; String? get phoneE164; List<String> get ownerUids;/// Display counter, only ever `increment(1)`-ed per contract.
 int get nextLoanNo; String get createdBy; DateTime get createdAt; int get schemaVersion;
/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanyCopyWith<Company> get copyWith => _$CompanyCopyWithImpl<Company>(this as Company, _$identity);

  /// Serializes this Company to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Company&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.nameLower, nameLower) || other.nameLower == nameLower)&&(identical(other.city, city) || other.city == city)&&(identical(other.phoneE164, phoneE164) || other.phoneE164 == phoneE164)&&const DeepCollectionEquality().equals(other.ownerUids, ownerUids)&&(identical(other.nextLoanNo, nextLoanNo) || other.nextLoanNo == nextLoanNo)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,nameLower,city,phoneE164,const DeepCollectionEquality().hash(ownerUids),nextLoanNo,createdBy,createdAt,schemaVersion);

@override
String toString() {
  return 'Company(id: $id, name: $name, nameLower: $nameLower, city: $city, phoneE164: $phoneE164, ownerUids: $ownerUids, nextLoanNo: $nextLoanNo, createdBy: $createdBy, createdAt: $createdAt, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class $CompanyCopyWith<$Res>  {
  factory $CompanyCopyWith(Company value, $Res Function(Company) _then) = _$CompanyCopyWithImpl;
@useResult
$Res call({
@JsonKey(includeToJson: false) String id, String name, String nameLower, String? city, String? phoneE164, List<String> ownerUids, int nextLoanNo, String createdBy, DateTime createdAt, int schemaVersion
});




}
/// @nodoc
class _$CompanyCopyWithImpl<$Res>
    implements $CompanyCopyWith<$Res> {
  _$CompanyCopyWithImpl(this._self, this._then);

  final Company _self;
  final $Res Function(Company) _then;

/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? nameLower = null,Object? city = freezed,Object? phoneE164 = freezed,Object? ownerUids = null,Object? nextLoanNo = null,Object? createdBy = null,Object? createdAt = null,Object? schemaVersion = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nameLower: null == nameLower ? _self.nameLower : nameLower // ignore: cast_nullable_to_non_nullable
as String,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,phoneE164: freezed == phoneE164 ? _self.phoneE164 : phoneE164 // ignore: cast_nullable_to_non_nullable
as String?,ownerUids: null == ownerUids ? _self.ownerUids : ownerUids // ignore: cast_nullable_to_non_nullable
as List<String>,nextLoanNo: null == nextLoanNo ? _self.nextLoanNo : nextLoanNo // ignore: cast_nullable_to_non_nullable
as int,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Company].
extension CompanyPatterns on Company {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Company value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Company() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Company value)  $default,){
final _that = this;
switch (_that) {
case _Company():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Company value)?  $default,){
final _that = this;
switch (_that) {
case _Company() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String id,  String name,  String nameLower,  String? city,  String? phoneE164,  List<String> ownerUids,  int nextLoanNo,  String createdBy,  DateTime createdAt,  int schemaVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Company() when $default != null:
return $default(_that.id,_that.name,_that.nameLower,_that.city,_that.phoneE164,_that.ownerUids,_that.nextLoanNo,_that.createdBy,_that.createdAt,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String id,  String name,  String nameLower,  String? city,  String? phoneE164,  List<String> ownerUids,  int nextLoanNo,  String createdBy,  DateTime createdAt,  int schemaVersion)  $default,) {final _that = this;
switch (_that) {
case _Company():
return $default(_that.id,_that.name,_that.nameLower,_that.city,_that.phoneE164,_that.ownerUids,_that.nextLoanNo,_that.createdBy,_that.createdAt,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(includeToJson: false)  String id,  String name,  String nameLower,  String? city,  String? phoneE164,  List<String> ownerUids,  int nextLoanNo,  String createdBy,  DateTime createdAt,  int schemaVersion)?  $default,) {final _that = this;
switch (_that) {
case _Company() when $default != null:
return $default(_that.id,_that.name,_that.nameLower,_that.city,_that.phoneE164,_that.ownerUids,_that.nextLoanNo,_that.createdBy,_that.createdAt,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Company implements Company {
  const _Company({@JsonKey(includeToJson: false) required this.id, required this.name, required this.nameLower, this.city, this.phoneE164, required final  List<String> ownerUids, this.nextLoanNo = 1, required this.createdBy, required this.createdAt, this.schemaVersion = 1}): _ownerUids = ownerUids;
  factory _Company.fromJson(Map<String, dynamic> json) => _$CompanyFromJson(json);

@override@JsonKey(includeToJson: false) final  String id;
@override final  String name;
@override final  String nameLower;
@override final  String? city;
@override final  String? phoneE164;
 final  List<String> _ownerUids;
@override List<String> get ownerUids {
  if (_ownerUids is EqualUnmodifiableListView) return _ownerUids;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ownerUids);
}

/// Display counter, only ever `increment(1)`-ed per contract.
@override@JsonKey() final  int nextLoanNo;
@override final  String createdBy;
@override final  DateTime createdAt;
@override@JsonKey() final  int schemaVersion;

/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompanyCopyWith<_Company> get copyWith => __$CompanyCopyWithImpl<_Company>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompanyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Company&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.nameLower, nameLower) || other.nameLower == nameLower)&&(identical(other.city, city) || other.city == city)&&(identical(other.phoneE164, phoneE164) || other.phoneE164 == phoneE164)&&const DeepCollectionEquality().equals(other._ownerUids, _ownerUids)&&(identical(other.nextLoanNo, nextLoanNo) || other.nextLoanNo == nextLoanNo)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,nameLower,city,phoneE164,const DeepCollectionEquality().hash(_ownerUids),nextLoanNo,createdBy,createdAt,schemaVersion);

@override
String toString() {
  return 'Company(id: $id, name: $name, nameLower: $nameLower, city: $city, phoneE164: $phoneE164, ownerUids: $ownerUids, nextLoanNo: $nextLoanNo, createdBy: $createdBy, createdAt: $createdAt, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class _$CompanyCopyWith<$Res> implements $CompanyCopyWith<$Res> {
  factory _$CompanyCopyWith(_Company value, $Res Function(_Company) _then) = __$CompanyCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(includeToJson: false) String id, String name, String nameLower, String? city, String? phoneE164, List<String> ownerUids, int nextLoanNo, String createdBy, DateTime createdAt, int schemaVersion
});




}
/// @nodoc
class __$CompanyCopyWithImpl<$Res>
    implements _$CompanyCopyWith<$Res> {
  __$CompanyCopyWithImpl(this._self, this._then);

  final _Company _self;
  final $Res Function(_Company) _then;

/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? nameLower = null,Object? city = freezed,Object? phoneE164 = freezed,Object? ownerUids = null,Object? nextLoanNo = null,Object? createdBy = null,Object? createdAt = null,Object? schemaVersion = null,}) {
  return _then(_Company(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nameLower: null == nameLower ? _self.nameLower : nameLower // ignore: cast_nullable_to_non_nullable
as String,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,phoneE164: freezed == phoneE164 ? _self.phoneE164 : phoneE164 // ignore: cast_nullable_to_non_nullable
as String?,ownerUids: null == ownerUids ? _self._ownerUids : ownerUids // ignore: cast_nullable_to_non_nullable
as List<String>,nextLoanNo: null == nextLoanNo ? _self.nextLoanNo : nextLoanNo // ignore: cast_nullable_to_non_nullable
as int,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
