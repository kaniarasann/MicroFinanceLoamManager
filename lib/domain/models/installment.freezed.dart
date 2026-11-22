// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'installment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Installment {

@JsonKey(includeToJson: false) String get id; String get contractId; String get borrowerId; String get borrowerName; int get loanNo; bool get contractActive;/// 1..n; rescheduled rows take the next seq.
 int get seq; InstallmentKind get kind;@CivilDateConverter() CivilDate get dueDate;@MoneyPaiseConverter()@JsonKey(name: 'amountDuePaise') Money get amountDue;@MoneyPaiseConverter()@JsonKey(name: 'rescheduledOutPaise') Money get rescheduledOut; List<String> get rescheduledToIds; String? get rescheduledFromId; String get createdBy; DateTime get createdAt; int get schemaVersion;
/// Create a copy of Installment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstallmentCopyWith<Installment> get copyWith => _$InstallmentCopyWithImpl<Installment>(this as Installment, _$identity);

  /// Serializes this Installment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Installment&&(identical(other.id, id) || other.id == id)&&(identical(other.contractId, contractId) || other.contractId == contractId)&&(identical(other.borrowerId, borrowerId) || other.borrowerId == borrowerId)&&(identical(other.borrowerName, borrowerName) || other.borrowerName == borrowerName)&&(identical(other.loanNo, loanNo) || other.loanNo == loanNo)&&(identical(other.contractActive, contractActive) || other.contractActive == contractActive)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.amountDue, amountDue) || other.amountDue == amountDue)&&(identical(other.rescheduledOut, rescheduledOut) || other.rescheduledOut == rescheduledOut)&&const DeepCollectionEquality().equals(other.rescheduledToIds, rescheduledToIds)&&(identical(other.rescheduledFromId, rescheduledFromId) || other.rescheduledFromId == rescheduledFromId)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,contractId,borrowerId,borrowerName,loanNo,contractActive,seq,kind,dueDate,amountDue,rescheduledOut,const DeepCollectionEquality().hash(rescheduledToIds),rescheduledFromId,createdBy,createdAt,schemaVersion);

@override
String toString() {
  return 'Installment(id: $id, contractId: $contractId, borrowerId: $borrowerId, borrowerName: $borrowerName, loanNo: $loanNo, contractActive: $contractActive, seq: $seq, kind: $kind, dueDate: $dueDate, amountDue: $amountDue, rescheduledOut: $rescheduledOut, rescheduledToIds: $rescheduledToIds, rescheduledFromId: $rescheduledFromId, createdBy: $createdBy, createdAt: $createdAt, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class $InstallmentCopyWith<$Res>  {
  factory $InstallmentCopyWith(Installment value, $Res Function(Installment) _then) = _$InstallmentCopyWithImpl;
@useResult
$Res call({
@JsonKey(includeToJson: false) String id, String contractId, String borrowerId, String borrowerName, int loanNo, bool contractActive, int seq, InstallmentKind kind,@CivilDateConverter() CivilDate dueDate,@MoneyPaiseConverter()@JsonKey(name: 'amountDuePaise') Money amountDue,@MoneyPaiseConverter()@JsonKey(name: 'rescheduledOutPaise') Money rescheduledOut, List<String> rescheduledToIds, String? rescheduledFromId, String createdBy, DateTime createdAt, int schemaVersion
});




}
/// @nodoc
class _$InstallmentCopyWithImpl<$Res>
    implements $InstallmentCopyWith<$Res> {
  _$InstallmentCopyWithImpl(this._self, this._then);

  final Installment _self;
  final $Res Function(Installment) _then;

/// Create a copy of Installment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? contractId = null,Object? borrowerId = null,Object? borrowerName = null,Object? loanNo = null,Object? contractActive = null,Object? seq = null,Object? kind = null,Object? dueDate = null,Object? amountDue = null,Object? rescheduledOut = null,Object? rescheduledToIds = null,Object? rescheduledFromId = freezed,Object? createdBy = null,Object? createdAt = null,Object? schemaVersion = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,contractId: null == contractId ? _self.contractId : contractId // ignore: cast_nullable_to_non_nullable
as String,borrowerId: null == borrowerId ? _self.borrowerId : borrowerId // ignore: cast_nullable_to_non_nullable
as String,borrowerName: null == borrowerName ? _self.borrowerName : borrowerName // ignore: cast_nullable_to_non_nullable
as String,loanNo: null == loanNo ? _self.loanNo : loanNo // ignore: cast_nullable_to_non_nullable
as int,contractActive: null == contractActive ? _self.contractActive : contractActive // ignore: cast_nullable_to_non_nullable
as bool,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as InstallmentKind,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as CivilDate,amountDue: null == amountDue ? _self.amountDue : amountDue // ignore: cast_nullable_to_non_nullable
as Money,rescheduledOut: null == rescheduledOut ? _self.rescheduledOut : rescheduledOut // ignore: cast_nullable_to_non_nullable
as Money,rescheduledToIds: null == rescheduledToIds ? _self.rescheduledToIds : rescheduledToIds // ignore: cast_nullable_to_non_nullable
as List<String>,rescheduledFromId: freezed == rescheduledFromId ? _self.rescheduledFromId : rescheduledFromId // ignore: cast_nullable_to_non_nullable
as String?,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Installment].
extension InstallmentPatterns on Installment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Installment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Installment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Installment value)  $default,){
final _that = this;
switch (_that) {
case _Installment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Installment value)?  $default,){
final _that = this;
switch (_that) {
case _Installment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String id,  String contractId,  String borrowerId,  String borrowerName,  int loanNo,  bool contractActive,  int seq,  InstallmentKind kind, @CivilDateConverter()  CivilDate dueDate, @MoneyPaiseConverter()@JsonKey(name: 'amountDuePaise')  Money amountDue, @MoneyPaiseConverter()@JsonKey(name: 'rescheduledOutPaise')  Money rescheduledOut,  List<String> rescheduledToIds,  String? rescheduledFromId,  String createdBy,  DateTime createdAt,  int schemaVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Installment() when $default != null:
return $default(_that.id,_that.contractId,_that.borrowerId,_that.borrowerName,_that.loanNo,_that.contractActive,_that.seq,_that.kind,_that.dueDate,_that.amountDue,_that.rescheduledOut,_that.rescheduledToIds,_that.rescheduledFromId,_that.createdBy,_that.createdAt,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String id,  String contractId,  String borrowerId,  String borrowerName,  int loanNo,  bool contractActive,  int seq,  InstallmentKind kind, @CivilDateConverter()  CivilDate dueDate, @MoneyPaiseConverter()@JsonKey(name: 'amountDuePaise')  Money amountDue, @MoneyPaiseConverter()@JsonKey(name: 'rescheduledOutPaise')  Money rescheduledOut,  List<String> rescheduledToIds,  String? rescheduledFromId,  String createdBy,  DateTime createdAt,  int schemaVersion)  $default,) {final _that = this;
switch (_that) {
case _Installment():
return $default(_that.id,_that.contractId,_that.borrowerId,_that.borrowerName,_that.loanNo,_that.contractActive,_that.seq,_that.kind,_that.dueDate,_that.amountDue,_that.rescheduledOut,_that.rescheduledToIds,_that.rescheduledFromId,_that.createdBy,_that.createdAt,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(includeToJson: false)  String id,  String contractId,  String borrowerId,  String borrowerName,  int loanNo,  bool contractActive,  int seq,  InstallmentKind kind, @CivilDateConverter()  CivilDate dueDate, @MoneyPaiseConverter()@JsonKey(name: 'amountDuePaise')  Money amountDue, @MoneyPaiseConverter()@JsonKey(name: 'rescheduledOutPaise')  Money rescheduledOut,  List<String> rescheduledToIds,  String? rescheduledFromId,  String createdBy,  DateTime createdAt,  int schemaVersion)?  $default,) {final _that = this;
switch (_that) {
case _Installment() when $default != null:
return $default(_that.id,_that.contractId,_that.borrowerId,_that.borrowerName,_that.loanNo,_that.contractActive,_that.seq,_that.kind,_that.dueDate,_that.amountDue,_that.rescheduledOut,_that.rescheduledToIds,_that.rescheduledFromId,_that.createdBy,_that.createdAt,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Installment implements Installment {
  const _Installment({@JsonKey(includeToJson: false) required this.id, required this.contractId, required this.borrowerId, required this.borrowerName, required this.loanNo, this.contractActive = true, required this.seq, this.kind = InstallmentKind.base, @CivilDateConverter() required this.dueDate, @MoneyPaiseConverter()@JsonKey(name: 'amountDuePaise') required this.amountDue, @MoneyPaiseConverter()@JsonKey(name: 'rescheduledOutPaise') this.rescheduledOut = Money.zero, final  List<String> rescheduledToIds = const <String>[], this.rescheduledFromId, required this.createdBy, required this.createdAt, this.schemaVersion = 1}): _rescheduledToIds = rescheduledToIds;
  factory _Installment.fromJson(Map<String, dynamic> json) => _$InstallmentFromJson(json);

@override@JsonKey(includeToJson: false) final  String id;
@override final  String contractId;
@override final  String borrowerId;
@override final  String borrowerName;
@override final  int loanNo;
@override@JsonKey() final  bool contractActive;
/// 1..n; rescheduled rows take the next seq.
@override final  int seq;
@override@JsonKey() final  InstallmentKind kind;
@override@CivilDateConverter() final  CivilDate dueDate;
@override@MoneyPaiseConverter()@JsonKey(name: 'amountDuePaise') final  Money amountDue;
@override@MoneyPaiseConverter()@JsonKey(name: 'rescheduledOutPaise') final  Money rescheduledOut;
 final  List<String> _rescheduledToIds;
@override@JsonKey() List<String> get rescheduledToIds {
  if (_rescheduledToIds is EqualUnmodifiableListView) return _rescheduledToIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rescheduledToIds);
}

@override final  String? rescheduledFromId;
@override final  String createdBy;
@override final  DateTime createdAt;
@override@JsonKey() final  int schemaVersion;

/// Create a copy of Installment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InstallmentCopyWith<_Installment> get copyWith => __$InstallmentCopyWithImpl<_Installment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InstallmentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Installment&&(identical(other.id, id) || other.id == id)&&(identical(other.contractId, contractId) || other.contractId == contractId)&&(identical(other.borrowerId, borrowerId) || other.borrowerId == borrowerId)&&(identical(other.borrowerName, borrowerName) || other.borrowerName == borrowerName)&&(identical(other.loanNo, loanNo) || other.loanNo == loanNo)&&(identical(other.contractActive, contractActive) || other.contractActive == contractActive)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.amountDue, amountDue) || other.amountDue == amountDue)&&(identical(other.rescheduledOut, rescheduledOut) || other.rescheduledOut == rescheduledOut)&&const DeepCollectionEquality().equals(other._rescheduledToIds, _rescheduledToIds)&&(identical(other.rescheduledFromId, rescheduledFromId) || other.rescheduledFromId == rescheduledFromId)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,contractId,borrowerId,borrowerName,loanNo,contractActive,seq,kind,dueDate,amountDue,rescheduledOut,const DeepCollectionEquality().hash(_rescheduledToIds),rescheduledFromId,createdBy,createdAt,schemaVersion);

@override
String toString() {
  return 'Installment(id: $id, contractId: $contractId, borrowerId: $borrowerId, borrowerName: $borrowerName, loanNo: $loanNo, contractActive: $contractActive, seq: $seq, kind: $kind, dueDate: $dueDate, amountDue: $amountDue, rescheduledOut: $rescheduledOut, rescheduledToIds: $rescheduledToIds, rescheduledFromId: $rescheduledFromId, createdBy: $createdBy, createdAt: $createdAt, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class _$InstallmentCopyWith<$Res> implements $InstallmentCopyWith<$Res> {
  factory _$InstallmentCopyWith(_Installment value, $Res Function(_Installment) _then) = __$InstallmentCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(includeToJson: false) String id, String contractId, String borrowerId, String borrowerName, int loanNo, bool contractActive, int seq, InstallmentKind kind,@CivilDateConverter() CivilDate dueDate,@MoneyPaiseConverter()@JsonKey(name: 'amountDuePaise') Money amountDue,@MoneyPaiseConverter()@JsonKey(name: 'rescheduledOutPaise') Money rescheduledOut, List<String> rescheduledToIds, String? rescheduledFromId, String createdBy, DateTime createdAt, int schemaVersion
});




}
/// @nodoc
class __$InstallmentCopyWithImpl<$Res>
    implements _$InstallmentCopyWith<$Res> {
  __$InstallmentCopyWithImpl(this._self, this._then);

  final _Installment _self;
  final $Res Function(_Installment) _then;

/// Create a copy of Installment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? contractId = null,Object? borrowerId = null,Object? borrowerName = null,Object? loanNo = null,Object? contractActive = null,Object? seq = null,Object? kind = null,Object? dueDate = null,Object? amountDue = null,Object? rescheduledOut = null,Object? rescheduledToIds = null,Object? rescheduledFromId = freezed,Object? createdBy = null,Object? createdAt = null,Object? schemaVersion = null,}) {
  return _then(_Installment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,contractId: null == contractId ? _self.contractId : contractId // ignore: cast_nullable_to_non_nullable
as String,borrowerId: null == borrowerId ? _self.borrowerId : borrowerId // ignore: cast_nullable_to_non_nullable
as String,borrowerName: null == borrowerName ? _self.borrowerName : borrowerName // ignore: cast_nullable_to_non_nullable
as String,loanNo: null == loanNo ? _self.loanNo : loanNo // ignore: cast_nullable_to_non_nullable
as int,contractActive: null == contractActive ? _self.contractActive : contractActive // ignore: cast_nullable_to_non_nullable
as bool,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as InstallmentKind,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as CivilDate,amountDue: null == amountDue ? _self.amountDue : amountDue // ignore: cast_nullable_to_non_nullable
as Money,rescheduledOut: null == rescheduledOut ? _self.rescheduledOut : rescheduledOut // ignore: cast_nullable_to_non_nullable
as Money,rescheduledToIds: null == rescheduledToIds ? _self._rescheduledToIds : rescheduledToIds // ignore: cast_nullable_to_non_nullable
as List<String>,rescheduledFromId: freezed == rescheduledFromId ? _self.rescheduledFromId : rescheduledFromId // ignore: cast_nullable_to_non_nullable
as String?,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
