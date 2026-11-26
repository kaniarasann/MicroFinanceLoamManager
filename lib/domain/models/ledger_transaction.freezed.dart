// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ledger_transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LedgerTransaction {

@JsonKey(includeToJson: false) String get id; String get contractId; String get borrowerId; String get borrowerName; int get loanNo; bool get contractActive; TxType get type;/// ≥ 0; 0 only for a reschedule audit entry.
@MoneyPaiseConverter()@JsonKey(name: 'amountPaise') Money get amount;@CivilDateConverter() CivilDate get paidOn; PaymentMode? get mode; String? get reference; String? get note; String? get reversesTxId;/// Rollover counterpart.
 String? get relatedContractId; Map<String, dynamic>? get rescheduleInfo;/// `onboarding` on the docs written by loan onboarding and on reversals
/// of them. Immutable.
@JsonKey(unknownEnumValue: TxOrigin.live) TxOrigin get origin;/// True on the payments an onboarding opening total was spread into.
 bool get openingBalance; String get recordedBy; String get recordedByName;/// Server timestamp. `null` while the write is pending (offline); use
/// [effectiveRecordedAt] for display and ordering.
 DateTime? get recordedAt; DateTime get clientRecordedAt; String get deviceId; int get schemaVersion;
/// Create a copy of LedgerTransaction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LedgerTransactionCopyWith<LedgerTransaction> get copyWith => _$LedgerTransactionCopyWithImpl<LedgerTransaction>(this as LedgerTransaction, _$identity);

  /// Serializes this LedgerTransaction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LedgerTransaction&&(identical(other.id, id) || other.id == id)&&(identical(other.contractId, contractId) || other.contractId == contractId)&&(identical(other.borrowerId, borrowerId) || other.borrowerId == borrowerId)&&(identical(other.borrowerName, borrowerName) || other.borrowerName == borrowerName)&&(identical(other.loanNo, loanNo) || other.loanNo == loanNo)&&(identical(other.contractActive, contractActive) || other.contractActive == contractActive)&&(identical(other.type, type) || other.type == type)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.paidOn, paidOn) || other.paidOn == paidOn)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.note, note) || other.note == note)&&(identical(other.reversesTxId, reversesTxId) || other.reversesTxId == reversesTxId)&&(identical(other.relatedContractId, relatedContractId) || other.relatedContractId == relatedContractId)&&const DeepCollectionEquality().equals(other.rescheduleInfo, rescheduleInfo)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.openingBalance, openingBalance) || other.openingBalance == openingBalance)&&(identical(other.recordedBy, recordedBy) || other.recordedBy == recordedBy)&&(identical(other.recordedByName, recordedByName) || other.recordedByName == recordedByName)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt)&&(identical(other.clientRecordedAt, clientRecordedAt) || other.clientRecordedAt == clientRecordedAt)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,contractId,borrowerId,borrowerName,loanNo,contractActive,type,amount,paidOn,mode,reference,note,reversesTxId,relatedContractId,const DeepCollectionEquality().hash(rescheduleInfo),origin,openingBalance,recordedBy,recordedByName,recordedAt,clientRecordedAt,deviceId,schemaVersion]);

@override
String toString() {
  return 'LedgerTransaction(id: $id, contractId: $contractId, borrowerId: $borrowerId, borrowerName: $borrowerName, loanNo: $loanNo, contractActive: $contractActive, type: $type, amount: $amount, paidOn: $paidOn, mode: $mode, reference: $reference, note: $note, reversesTxId: $reversesTxId, relatedContractId: $relatedContractId, rescheduleInfo: $rescheduleInfo, origin: $origin, openingBalance: $openingBalance, recordedBy: $recordedBy, recordedByName: $recordedByName, recordedAt: $recordedAt, clientRecordedAt: $clientRecordedAt, deviceId: $deviceId, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class $LedgerTransactionCopyWith<$Res>  {
  factory $LedgerTransactionCopyWith(LedgerTransaction value, $Res Function(LedgerTransaction) _then) = _$LedgerTransactionCopyWithImpl;
@useResult
$Res call({
@JsonKey(includeToJson: false) String id, String contractId, String borrowerId, String borrowerName, int loanNo, bool contractActive, TxType type,@MoneyPaiseConverter()@JsonKey(name: 'amountPaise') Money amount,@CivilDateConverter() CivilDate paidOn, PaymentMode? mode, String? reference, String? note, String? reversesTxId, String? relatedContractId, Map<String, dynamic>? rescheduleInfo,@JsonKey(unknownEnumValue: TxOrigin.live) TxOrigin origin, bool openingBalance, String recordedBy, String recordedByName, DateTime? recordedAt, DateTime clientRecordedAt, String deviceId, int schemaVersion
});




}
/// @nodoc
class _$LedgerTransactionCopyWithImpl<$Res>
    implements $LedgerTransactionCopyWith<$Res> {
  _$LedgerTransactionCopyWithImpl(this._self, this._then);

  final LedgerTransaction _self;
  final $Res Function(LedgerTransaction) _then;

/// Create a copy of LedgerTransaction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? contractId = null,Object? borrowerId = null,Object? borrowerName = null,Object? loanNo = null,Object? contractActive = null,Object? type = null,Object? amount = null,Object? paidOn = null,Object? mode = freezed,Object? reference = freezed,Object? note = freezed,Object? reversesTxId = freezed,Object? relatedContractId = freezed,Object? rescheduleInfo = freezed,Object? origin = null,Object? openingBalance = null,Object? recordedBy = null,Object? recordedByName = null,Object? recordedAt = freezed,Object? clientRecordedAt = null,Object? deviceId = null,Object? schemaVersion = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,contractId: null == contractId ? _self.contractId : contractId // ignore: cast_nullable_to_non_nullable
as String,borrowerId: null == borrowerId ? _self.borrowerId : borrowerId // ignore: cast_nullable_to_non_nullable
as String,borrowerName: null == borrowerName ? _self.borrowerName : borrowerName // ignore: cast_nullable_to_non_nullable
as String,loanNo: null == loanNo ? _self.loanNo : loanNo // ignore: cast_nullable_to_non_nullable
as int,contractActive: null == contractActive ? _self.contractActive : contractActive // ignore: cast_nullable_to_non_nullable
as bool,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TxType,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Money,paidOn: null == paidOn ? _self.paidOn : paidOn // ignore: cast_nullable_to_non_nullable
as CivilDate,mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as PaymentMode?,reference: freezed == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,reversesTxId: freezed == reversesTxId ? _self.reversesTxId : reversesTxId // ignore: cast_nullable_to_non_nullable
as String?,relatedContractId: freezed == relatedContractId ? _self.relatedContractId : relatedContractId // ignore: cast_nullable_to_non_nullable
as String?,rescheduleInfo: freezed == rescheduleInfo ? _self.rescheduleInfo : rescheduleInfo // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as TxOrigin,openingBalance: null == openingBalance ? _self.openingBalance : openingBalance // ignore: cast_nullable_to_non_nullable
as bool,recordedBy: null == recordedBy ? _self.recordedBy : recordedBy // ignore: cast_nullable_to_non_nullable
as String,recordedByName: null == recordedByName ? _self.recordedByName : recordedByName // ignore: cast_nullable_to_non_nullable
as String,recordedAt: freezed == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,clientRecordedAt: null == clientRecordedAt ? _self.clientRecordedAt : clientRecordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LedgerTransaction].
extension LedgerTransactionPatterns on LedgerTransaction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LedgerTransaction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LedgerTransaction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LedgerTransaction value)  $default,){
final _that = this;
switch (_that) {
case _LedgerTransaction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LedgerTransaction value)?  $default,){
final _that = this;
switch (_that) {
case _LedgerTransaction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String id,  String contractId,  String borrowerId,  String borrowerName,  int loanNo,  bool contractActive,  TxType type, @MoneyPaiseConverter()@JsonKey(name: 'amountPaise')  Money amount, @CivilDateConverter()  CivilDate paidOn,  PaymentMode? mode,  String? reference,  String? note,  String? reversesTxId,  String? relatedContractId,  Map<String, dynamic>? rescheduleInfo, @JsonKey(unknownEnumValue: TxOrigin.live)  TxOrigin origin,  bool openingBalance,  String recordedBy,  String recordedByName,  DateTime? recordedAt,  DateTime clientRecordedAt,  String deviceId,  int schemaVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LedgerTransaction() when $default != null:
return $default(_that.id,_that.contractId,_that.borrowerId,_that.borrowerName,_that.loanNo,_that.contractActive,_that.type,_that.amount,_that.paidOn,_that.mode,_that.reference,_that.note,_that.reversesTxId,_that.relatedContractId,_that.rescheduleInfo,_that.origin,_that.openingBalance,_that.recordedBy,_that.recordedByName,_that.recordedAt,_that.clientRecordedAt,_that.deviceId,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String id,  String contractId,  String borrowerId,  String borrowerName,  int loanNo,  bool contractActive,  TxType type, @MoneyPaiseConverter()@JsonKey(name: 'amountPaise')  Money amount, @CivilDateConverter()  CivilDate paidOn,  PaymentMode? mode,  String? reference,  String? note,  String? reversesTxId,  String? relatedContractId,  Map<String, dynamic>? rescheduleInfo, @JsonKey(unknownEnumValue: TxOrigin.live)  TxOrigin origin,  bool openingBalance,  String recordedBy,  String recordedByName,  DateTime? recordedAt,  DateTime clientRecordedAt,  String deviceId,  int schemaVersion)  $default,) {final _that = this;
switch (_that) {
case _LedgerTransaction():
return $default(_that.id,_that.contractId,_that.borrowerId,_that.borrowerName,_that.loanNo,_that.contractActive,_that.type,_that.amount,_that.paidOn,_that.mode,_that.reference,_that.note,_that.reversesTxId,_that.relatedContractId,_that.rescheduleInfo,_that.origin,_that.openingBalance,_that.recordedBy,_that.recordedByName,_that.recordedAt,_that.clientRecordedAt,_that.deviceId,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(includeToJson: false)  String id,  String contractId,  String borrowerId,  String borrowerName,  int loanNo,  bool contractActive,  TxType type, @MoneyPaiseConverter()@JsonKey(name: 'amountPaise')  Money amount, @CivilDateConverter()  CivilDate paidOn,  PaymentMode? mode,  String? reference,  String? note,  String? reversesTxId,  String? relatedContractId,  Map<String, dynamic>? rescheduleInfo, @JsonKey(unknownEnumValue: TxOrigin.live)  TxOrigin origin,  bool openingBalance,  String recordedBy,  String recordedByName,  DateTime? recordedAt,  DateTime clientRecordedAt,  String deviceId,  int schemaVersion)?  $default,) {final _that = this;
switch (_that) {
case _LedgerTransaction() when $default != null:
return $default(_that.id,_that.contractId,_that.borrowerId,_that.borrowerName,_that.loanNo,_that.contractActive,_that.type,_that.amount,_that.paidOn,_that.mode,_that.reference,_that.note,_that.reversesTxId,_that.relatedContractId,_that.rescheduleInfo,_that.origin,_that.openingBalance,_that.recordedBy,_that.recordedByName,_that.recordedAt,_that.clientRecordedAt,_that.deviceId,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LedgerTransaction extends LedgerTransaction {
  const _LedgerTransaction({@JsonKey(includeToJson: false) required this.id, required this.contractId, required this.borrowerId, required this.borrowerName, required this.loanNo, this.contractActive = true, required this.type, @MoneyPaiseConverter()@JsonKey(name: 'amountPaise') required this.amount, @CivilDateConverter() required this.paidOn, this.mode, this.reference, this.note, this.reversesTxId, this.relatedContractId, final  Map<String, dynamic>? rescheduleInfo, @JsonKey(unknownEnumValue: TxOrigin.live) this.origin = TxOrigin.live, this.openingBalance = false, required this.recordedBy, required this.recordedByName, this.recordedAt, required this.clientRecordedAt, required this.deviceId, this.schemaVersion = 1}): _rescheduleInfo = rescheduleInfo,super._();
  factory _LedgerTransaction.fromJson(Map<String, dynamic> json) => _$LedgerTransactionFromJson(json);

@override@JsonKey(includeToJson: false) final  String id;
@override final  String contractId;
@override final  String borrowerId;
@override final  String borrowerName;
@override final  int loanNo;
@override@JsonKey() final  bool contractActive;
@override final  TxType type;
/// ≥ 0; 0 only for a reschedule audit entry.
@override@MoneyPaiseConverter()@JsonKey(name: 'amountPaise') final  Money amount;
@override@CivilDateConverter() final  CivilDate paidOn;
@override final  PaymentMode? mode;
@override final  String? reference;
@override final  String? note;
@override final  String? reversesTxId;
/// Rollover counterpart.
@override final  String? relatedContractId;
 final  Map<String, dynamic>? _rescheduleInfo;
@override Map<String, dynamic>? get rescheduleInfo {
  final value = _rescheduleInfo;
  if (value == null) return null;
  if (_rescheduleInfo is EqualUnmodifiableMapView) return _rescheduleInfo;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

/// `onboarding` on the docs written by loan onboarding and on reversals
/// of them. Immutable.
@override@JsonKey(unknownEnumValue: TxOrigin.live) final  TxOrigin origin;
/// True on the payments an onboarding opening total was spread into.
@override@JsonKey() final  bool openingBalance;
@override final  String recordedBy;
@override final  String recordedByName;
/// Server timestamp. `null` while the write is pending (offline); use
/// [effectiveRecordedAt] for display and ordering.
@override final  DateTime? recordedAt;
@override final  DateTime clientRecordedAt;
@override final  String deviceId;
@override@JsonKey() final  int schemaVersion;

/// Create a copy of LedgerTransaction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LedgerTransactionCopyWith<_LedgerTransaction> get copyWith => __$LedgerTransactionCopyWithImpl<_LedgerTransaction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LedgerTransactionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LedgerTransaction&&(identical(other.id, id) || other.id == id)&&(identical(other.contractId, contractId) || other.contractId == contractId)&&(identical(other.borrowerId, borrowerId) || other.borrowerId == borrowerId)&&(identical(other.borrowerName, borrowerName) || other.borrowerName == borrowerName)&&(identical(other.loanNo, loanNo) || other.loanNo == loanNo)&&(identical(other.contractActive, contractActive) || other.contractActive == contractActive)&&(identical(other.type, type) || other.type == type)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.paidOn, paidOn) || other.paidOn == paidOn)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.note, note) || other.note == note)&&(identical(other.reversesTxId, reversesTxId) || other.reversesTxId == reversesTxId)&&(identical(other.relatedContractId, relatedContractId) || other.relatedContractId == relatedContractId)&&const DeepCollectionEquality().equals(other._rescheduleInfo, _rescheduleInfo)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.openingBalance, openingBalance) || other.openingBalance == openingBalance)&&(identical(other.recordedBy, recordedBy) || other.recordedBy == recordedBy)&&(identical(other.recordedByName, recordedByName) || other.recordedByName == recordedByName)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt)&&(identical(other.clientRecordedAt, clientRecordedAt) || other.clientRecordedAt == clientRecordedAt)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,contractId,borrowerId,borrowerName,loanNo,contractActive,type,amount,paidOn,mode,reference,note,reversesTxId,relatedContractId,const DeepCollectionEquality().hash(_rescheduleInfo),origin,openingBalance,recordedBy,recordedByName,recordedAt,clientRecordedAt,deviceId,schemaVersion]);

@override
String toString() {
  return 'LedgerTransaction(id: $id, contractId: $contractId, borrowerId: $borrowerId, borrowerName: $borrowerName, loanNo: $loanNo, contractActive: $contractActive, type: $type, amount: $amount, paidOn: $paidOn, mode: $mode, reference: $reference, note: $note, reversesTxId: $reversesTxId, relatedContractId: $relatedContractId, rescheduleInfo: $rescheduleInfo, origin: $origin, openingBalance: $openingBalance, recordedBy: $recordedBy, recordedByName: $recordedByName, recordedAt: $recordedAt, clientRecordedAt: $clientRecordedAt, deviceId: $deviceId, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class _$LedgerTransactionCopyWith<$Res> implements $LedgerTransactionCopyWith<$Res> {
  factory _$LedgerTransactionCopyWith(_LedgerTransaction value, $Res Function(_LedgerTransaction) _then) = __$LedgerTransactionCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(includeToJson: false) String id, String contractId, String borrowerId, String borrowerName, int loanNo, bool contractActive, TxType type,@MoneyPaiseConverter()@JsonKey(name: 'amountPaise') Money amount,@CivilDateConverter() CivilDate paidOn, PaymentMode? mode, String? reference, String? note, String? reversesTxId, String? relatedContractId, Map<String, dynamic>? rescheduleInfo,@JsonKey(unknownEnumValue: TxOrigin.live) TxOrigin origin, bool openingBalance, String recordedBy, String recordedByName, DateTime? recordedAt, DateTime clientRecordedAt, String deviceId, int schemaVersion
});




}
/// @nodoc
class __$LedgerTransactionCopyWithImpl<$Res>
    implements _$LedgerTransactionCopyWith<$Res> {
  __$LedgerTransactionCopyWithImpl(this._self, this._then);

  final _LedgerTransaction _self;
  final $Res Function(_LedgerTransaction) _then;

/// Create a copy of LedgerTransaction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? contractId = null,Object? borrowerId = null,Object? borrowerName = null,Object? loanNo = null,Object? contractActive = null,Object? type = null,Object? amount = null,Object? paidOn = null,Object? mode = freezed,Object? reference = freezed,Object? note = freezed,Object? reversesTxId = freezed,Object? relatedContractId = freezed,Object? rescheduleInfo = freezed,Object? origin = null,Object? openingBalance = null,Object? recordedBy = null,Object? recordedByName = null,Object? recordedAt = freezed,Object? clientRecordedAt = null,Object? deviceId = null,Object? schemaVersion = null,}) {
  return _then(_LedgerTransaction(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,contractId: null == contractId ? _self.contractId : contractId // ignore: cast_nullable_to_non_nullable
as String,borrowerId: null == borrowerId ? _self.borrowerId : borrowerId // ignore: cast_nullable_to_non_nullable
as String,borrowerName: null == borrowerName ? _self.borrowerName : borrowerName // ignore: cast_nullable_to_non_nullable
as String,loanNo: null == loanNo ? _self.loanNo : loanNo // ignore: cast_nullable_to_non_nullable
as int,contractActive: null == contractActive ? _self.contractActive : contractActive // ignore: cast_nullable_to_non_nullable
as bool,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TxType,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Money,paidOn: null == paidOn ? _self.paidOn : paidOn // ignore: cast_nullable_to_non_nullable
as CivilDate,mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as PaymentMode?,reference: freezed == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,reversesTxId: freezed == reversesTxId ? _self.reversesTxId : reversesTxId // ignore: cast_nullable_to_non_nullable
as String?,relatedContractId: freezed == relatedContractId ? _self.relatedContractId : relatedContractId // ignore: cast_nullable_to_non_nullable
as String?,rescheduleInfo: freezed == rescheduleInfo ? _self._rescheduleInfo : rescheduleInfo // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as TxOrigin,openingBalance: null == openingBalance ? _self.openingBalance : openingBalance // ignore: cast_nullable_to_non_nullable
as bool,recordedBy: null == recordedBy ? _self.recordedBy : recordedBy // ignore: cast_nullable_to_non_nullable
as String,recordedByName: null == recordedByName ? _self.recordedByName : recordedByName // ignore: cast_nullable_to_non_nullable
as String,recordedAt: freezed == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,clientRecordedAt: null == clientRecordedAt ? _self.clientRecordedAt : clientRecordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
