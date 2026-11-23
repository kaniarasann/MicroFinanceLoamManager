// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'contract.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Contract {

@JsonKey(includeToJson: false) String get id;// Identity.
 String get borrowerId; String get borrowerName; String get borrowerPhoneE164; int get loanNo; String? get purpose;// Lifecycle.
 ContractStatus get status;// Amounts.
/// Repayable principal.
@MoneyPaiseConverter()@JsonKey(name: 'sanctionedPaise') Money get sanctioned; UpfrontMode get upfrontMode;/// Paise when [upfrontMode] is flat; basis points (700 = 7.00%) when
/// percent.
 int get upfrontInput;/// Amount actually deducted up front.
@MoneyPaiseConverter()@JsonKey(name: 'upfrontPaise') Money get upfront;/// sanctioned − upfront (for a rollover: − settled old outstanding too).
@MoneyPaiseConverter()@JsonKey(name: 'netDisbursedPaise') Money get netDisbursed;// Schedule terms.
 Frequency get frequency;/// 1 = Mon … 7 = Sun (weekly).
 int? get preferredWeekday;/// 1–31, clamped to month length (monthly).
 int? get preferredMonthDay;@MoneyPaiseConverter()@JsonKey(name: 'installmentPaise') Money get installmentAmount; int get baseInstallmentCount;@CivilDateConverter() CivilDate get firstDueDate;@CivilDateConverter() CivilDate get disbursedOn;// Optional details.
 String? get guarantor; String? get notes;// Running total (cache; the projection is the source of truth).
@MoneyPaiseConverter()@JsonKey(name: 'totalPaidPaise') Money get totalPaid;/// Running total of early-closure waivers (cache; not cash).
@MoneyPaiseConverter()@JsonKey(name: 'totalWaivedPaise') Money get totalWaived;// Lifecycle dates.
@NullableCivilDateConverter() CivilDate? get lastPaymentOn; DateTime? get closedAt;// Rollover links.
 String? get rolledOverFromContractId; String? get rolledOverToContractId;@NullableMoneyPaiseConverter()@JsonKey(name: 'rolloverSettledPaise') Money? get rolloverSettled;// Audit.
 String get createdBy; DateTime get createdAt; DateTime get updatedAt; int get schemaVersion;
/// Create a copy of Contract
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContractCopyWith<Contract> get copyWith => _$ContractCopyWithImpl<Contract>(this as Contract, _$identity);

  /// Serializes this Contract to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Contract&&(identical(other.id, id) || other.id == id)&&(identical(other.borrowerId, borrowerId) || other.borrowerId == borrowerId)&&(identical(other.borrowerName, borrowerName) || other.borrowerName == borrowerName)&&(identical(other.borrowerPhoneE164, borrowerPhoneE164) || other.borrowerPhoneE164 == borrowerPhoneE164)&&(identical(other.loanNo, loanNo) || other.loanNo == loanNo)&&(identical(other.purpose, purpose) || other.purpose == purpose)&&(identical(other.status, status) || other.status == status)&&(identical(other.sanctioned, sanctioned) || other.sanctioned == sanctioned)&&(identical(other.upfrontMode, upfrontMode) || other.upfrontMode == upfrontMode)&&(identical(other.upfrontInput, upfrontInput) || other.upfrontInput == upfrontInput)&&(identical(other.upfront, upfront) || other.upfront == upfront)&&(identical(other.netDisbursed, netDisbursed) || other.netDisbursed == netDisbursed)&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.preferredWeekday, preferredWeekday) || other.preferredWeekday == preferredWeekday)&&(identical(other.preferredMonthDay, preferredMonthDay) || other.preferredMonthDay == preferredMonthDay)&&(identical(other.installmentAmount, installmentAmount) || other.installmentAmount == installmentAmount)&&(identical(other.baseInstallmentCount, baseInstallmentCount) || other.baseInstallmentCount == baseInstallmentCount)&&(identical(other.firstDueDate, firstDueDate) || other.firstDueDate == firstDueDate)&&(identical(other.disbursedOn, disbursedOn) || other.disbursedOn == disbursedOn)&&(identical(other.guarantor, guarantor) || other.guarantor == guarantor)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.totalPaid, totalPaid) || other.totalPaid == totalPaid)&&(identical(other.totalWaived, totalWaived) || other.totalWaived == totalWaived)&&(identical(other.lastPaymentOn, lastPaymentOn) || other.lastPaymentOn == lastPaymentOn)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.rolledOverFromContractId, rolledOverFromContractId) || other.rolledOverFromContractId == rolledOverFromContractId)&&(identical(other.rolledOverToContractId, rolledOverToContractId) || other.rolledOverToContractId == rolledOverToContractId)&&(identical(other.rolloverSettled, rolloverSettled) || other.rolloverSettled == rolloverSettled)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,borrowerId,borrowerName,borrowerPhoneE164,loanNo,purpose,status,sanctioned,upfrontMode,upfrontInput,upfront,netDisbursed,frequency,preferredWeekday,preferredMonthDay,installmentAmount,baseInstallmentCount,firstDueDate,disbursedOn,guarantor,notes,totalPaid,totalWaived,lastPaymentOn,closedAt,rolledOverFromContractId,rolledOverToContractId,rolloverSettled,createdBy,createdAt,updatedAt,schemaVersion]);

@override
String toString() {
  return 'Contract(id: $id, borrowerId: $borrowerId, borrowerName: $borrowerName, borrowerPhoneE164: $borrowerPhoneE164, loanNo: $loanNo, purpose: $purpose, status: $status, sanctioned: $sanctioned, upfrontMode: $upfrontMode, upfrontInput: $upfrontInput, upfront: $upfront, netDisbursed: $netDisbursed, frequency: $frequency, preferredWeekday: $preferredWeekday, preferredMonthDay: $preferredMonthDay, installmentAmount: $installmentAmount, baseInstallmentCount: $baseInstallmentCount, firstDueDate: $firstDueDate, disbursedOn: $disbursedOn, guarantor: $guarantor, notes: $notes, totalPaid: $totalPaid, totalWaived: $totalWaived, lastPaymentOn: $lastPaymentOn, closedAt: $closedAt, rolledOverFromContractId: $rolledOverFromContractId, rolledOverToContractId: $rolledOverToContractId, rolloverSettled: $rolloverSettled, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class $ContractCopyWith<$Res>  {
  factory $ContractCopyWith(Contract value, $Res Function(Contract) _then) = _$ContractCopyWithImpl;
@useResult
$Res call({
@JsonKey(includeToJson: false) String id, String borrowerId, String borrowerName, String borrowerPhoneE164, int loanNo, String? purpose, ContractStatus status,@MoneyPaiseConverter()@JsonKey(name: 'sanctionedPaise') Money sanctioned, UpfrontMode upfrontMode, int upfrontInput,@MoneyPaiseConverter()@JsonKey(name: 'upfrontPaise') Money upfront,@MoneyPaiseConverter()@JsonKey(name: 'netDisbursedPaise') Money netDisbursed, Frequency frequency, int? preferredWeekday, int? preferredMonthDay,@MoneyPaiseConverter()@JsonKey(name: 'installmentPaise') Money installmentAmount, int baseInstallmentCount,@CivilDateConverter() CivilDate firstDueDate,@CivilDateConverter() CivilDate disbursedOn, String? guarantor, String? notes,@MoneyPaiseConverter()@JsonKey(name: 'totalPaidPaise') Money totalPaid,@MoneyPaiseConverter()@JsonKey(name: 'totalWaivedPaise') Money totalWaived,@NullableCivilDateConverter() CivilDate? lastPaymentOn, DateTime? closedAt, String? rolledOverFromContractId, String? rolledOverToContractId,@NullableMoneyPaiseConverter()@JsonKey(name: 'rolloverSettledPaise') Money? rolloverSettled, String createdBy, DateTime createdAt, DateTime updatedAt, int schemaVersion
});




}
/// @nodoc
class _$ContractCopyWithImpl<$Res>
    implements $ContractCopyWith<$Res> {
  _$ContractCopyWithImpl(this._self, this._then);

  final Contract _self;
  final $Res Function(Contract) _then;

/// Create a copy of Contract
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? borrowerId = null,Object? borrowerName = null,Object? borrowerPhoneE164 = null,Object? loanNo = null,Object? purpose = freezed,Object? status = null,Object? sanctioned = null,Object? upfrontMode = null,Object? upfrontInput = null,Object? upfront = null,Object? netDisbursed = null,Object? frequency = null,Object? preferredWeekday = freezed,Object? preferredMonthDay = freezed,Object? installmentAmount = null,Object? baseInstallmentCount = null,Object? firstDueDate = null,Object? disbursedOn = null,Object? guarantor = freezed,Object? notes = freezed,Object? totalPaid = null,Object? totalWaived = null,Object? lastPaymentOn = freezed,Object? closedAt = freezed,Object? rolledOverFromContractId = freezed,Object? rolledOverToContractId = freezed,Object? rolloverSettled = freezed,Object? createdBy = null,Object? createdAt = null,Object? updatedAt = null,Object? schemaVersion = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,borrowerId: null == borrowerId ? _self.borrowerId : borrowerId // ignore: cast_nullable_to_non_nullable
as String,borrowerName: null == borrowerName ? _self.borrowerName : borrowerName // ignore: cast_nullable_to_non_nullable
as String,borrowerPhoneE164: null == borrowerPhoneE164 ? _self.borrowerPhoneE164 : borrowerPhoneE164 // ignore: cast_nullable_to_non_nullable
as String,loanNo: null == loanNo ? _self.loanNo : loanNo // ignore: cast_nullable_to_non_nullable
as int,purpose: freezed == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ContractStatus,sanctioned: null == sanctioned ? _self.sanctioned : sanctioned // ignore: cast_nullable_to_non_nullable
as Money,upfrontMode: null == upfrontMode ? _self.upfrontMode : upfrontMode // ignore: cast_nullable_to_non_nullable
as UpfrontMode,upfrontInput: null == upfrontInput ? _self.upfrontInput : upfrontInput // ignore: cast_nullable_to_non_nullable
as int,upfront: null == upfront ? _self.upfront : upfront // ignore: cast_nullable_to_non_nullable
as Money,netDisbursed: null == netDisbursed ? _self.netDisbursed : netDisbursed // ignore: cast_nullable_to_non_nullable
as Money,frequency: null == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as Frequency,preferredWeekday: freezed == preferredWeekday ? _self.preferredWeekday : preferredWeekday // ignore: cast_nullable_to_non_nullable
as int?,preferredMonthDay: freezed == preferredMonthDay ? _self.preferredMonthDay : preferredMonthDay // ignore: cast_nullable_to_non_nullable
as int?,installmentAmount: null == installmentAmount ? _self.installmentAmount : installmentAmount // ignore: cast_nullable_to_non_nullable
as Money,baseInstallmentCount: null == baseInstallmentCount ? _self.baseInstallmentCount : baseInstallmentCount // ignore: cast_nullable_to_non_nullable
as int,firstDueDate: null == firstDueDate ? _self.firstDueDate : firstDueDate // ignore: cast_nullable_to_non_nullable
as CivilDate,disbursedOn: null == disbursedOn ? _self.disbursedOn : disbursedOn // ignore: cast_nullable_to_non_nullable
as CivilDate,guarantor: freezed == guarantor ? _self.guarantor : guarantor // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,totalPaid: null == totalPaid ? _self.totalPaid : totalPaid // ignore: cast_nullable_to_non_nullable
as Money,totalWaived: null == totalWaived ? _self.totalWaived : totalWaived // ignore: cast_nullable_to_non_nullable
as Money,lastPaymentOn: freezed == lastPaymentOn ? _self.lastPaymentOn : lastPaymentOn // ignore: cast_nullable_to_non_nullable
as CivilDate?,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rolledOverFromContractId: freezed == rolledOverFromContractId ? _self.rolledOverFromContractId : rolledOverFromContractId // ignore: cast_nullable_to_non_nullable
as String?,rolledOverToContractId: freezed == rolledOverToContractId ? _self.rolledOverToContractId : rolledOverToContractId // ignore: cast_nullable_to_non_nullable
as String?,rolloverSettled: freezed == rolloverSettled ? _self.rolloverSettled : rolloverSettled // ignore: cast_nullable_to_non_nullable
as Money?,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Contract].
extension ContractPatterns on Contract {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Contract value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Contract() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Contract value)  $default,){
final _that = this;
switch (_that) {
case _Contract():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Contract value)?  $default,){
final _that = this;
switch (_that) {
case _Contract() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String id,  String borrowerId,  String borrowerName,  String borrowerPhoneE164,  int loanNo,  String? purpose,  ContractStatus status, @MoneyPaiseConverter()@JsonKey(name: 'sanctionedPaise')  Money sanctioned,  UpfrontMode upfrontMode,  int upfrontInput, @MoneyPaiseConverter()@JsonKey(name: 'upfrontPaise')  Money upfront, @MoneyPaiseConverter()@JsonKey(name: 'netDisbursedPaise')  Money netDisbursed,  Frequency frequency,  int? preferredWeekday,  int? preferredMonthDay, @MoneyPaiseConverter()@JsonKey(name: 'installmentPaise')  Money installmentAmount,  int baseInstallmentCount, @CivilDateConverter()  CivilDate firstDueDate, @CivilDateConverter()  CivilDate disbursedOn,  String? guarantor,  String? notes, @MoneyPaiseConverter()@JsonKey(name: 'totalPaidPaise')  Money totalPaid, @MoneyPaiseConverter()@JsonKey(name: 'totalWaivedPaise')  Money totalWaived, @NullableCivilDateConverter()  CivilDate? lastPaymentOn,  DateTime? closedAt,  String? rolledOverFromContractId,  String? rolledOverToContractId, @NullableMoneyPaiseConverter()@JsonKey(name: 'rolloverSettledPaise')  Money? rolloverSettled,  String createdBy,  DateTime createdAt,  DateTime updatedAt,  int schemaVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Contract() when $default != null:
return $default(_that.id,_that.borrowerId,_that.borrowerName,_that.borrowerPhoneE164,_that.loanNo,_that.purpose,_that.status,_that.sanctioned,_that.upfrontMode,_that.upfrontInput,_that.upfront,_that.netDisbursed,_that.frequency,_that.preferredWeekday,_that.preferredMonthDay,_that.installmentAmount,_that.baseInstallmentCount,_that.firstDueDate,_that.disbursedOn,_that.guarantor,_that.notes,_that.totalPaid,_that.totalWaived,_that.lastPaymentOn,_that.closedAt,_that.rolledOverFromContractId,_that.rolledOverToContractId,_that.rolloverSettled,_that.createdBy,_that.createdAt,_that.updatedAt,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String id,  String borrowerId,  String borrowerName,  String borrowerPhoneE164,  int loanNo,  String? purpose,  ContractStatus status, @MoneyPaiseConverter()@JsonKey(name: 'sanctionedPaise')  Money sanctioned,  UpfrontMode upfrontMode,  int upfrontInput, @MoneyPaiseConverter()@JsonKey(name: 'upfrontPaise')  Money upfront, @MoneyPaiseConverter()@JsonKey(name: 'netDisbursedPaise')  Money netDisbursed,  Frequency frequency,  int? preferredWeekday,  int? preferredMonthDay, @MoneyPaiseConverter()@JsonKey(name: 'installmentPaise')  Money installmentAmount,  int baseInstallmentCount, @CivilDateConverter()  CivilDate firstDueDate, @CivilDateConverter()  CivilDate disbursedOn,  String? guarantor,  String? notes, @MoneyPaiseConverter()@JsonKey(name: 'totalPaidPaise')  Money totalPaid, @MoneyPaiseConverter()@JsonKey(name: 'totalWaivedPaise')  Money totalWaived, @NullableCivilDateConverter()  CivilDate? lastPaymentOn,  DateTime? closedAt,  String? rolledOverFromContractId,  String? rolledOverToContractId, @NullableMoneyPaiseConverter()@JsonKey(name: 'rolloverSettledPaise')  Money? rolloverSettled,  String createdBy,  DateTime createdAt,  DateTime updatedAt,  int schemaVersion)  $default,) {final _that = this;
switch (_that) {
case _Contract():
return $default(_that.id,_that.borrowerId,_that.borrowerName,_that.borrowerPhoneE164,_that.loanNo,_that.purpose,_that.status,_that.sanctioned,_that.upfrontMode,_that.upfrontInput,_that.upfront,_that.netDisbursed,_that.frequency,_that.preferredWeekday,_that.preferredMonthDay,_that.installmentAmount,_that.baseInstallmentCount,_that.firstDueDate,_that.disbursedOn,_that.guarantor,_that.notes,_that.totalPaid,_that.totalWaived,_that.lastPaymentOn,_that.closedAt,_that.rolledOverFromContractId,_that.rolledOverToContractId,_that.rolloverSettled,_that.createdBy,_that.createdAt,_that.updatedAt,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(includeToJson: false)  String id,  String borrowerId,  String borrowerName,  String borrowerPhoneE164,  int loanNo,  String? purpose,  ContractStatus status, @MoneyPaiseConverter()@JsonKey(name: 'sanctionedPaise')  Money sanctioned,  UpfrontMode upfrontMode,  int upfrontInput, @MoneyPaiseConverter()@JsonKey(name: 'upfrontPaise')  Money upfront, @MoneyPaiseConverter()@JsonKey(name: 'netDisbursedPaise')  Money netDisbursed,  Frequency frequency,  int? preferredWeekday,  int? preferredMonthDay, @MoneyPaiseConverter()@JsonKey(name: 'installmentPaise')  Money installmentAmount,  int baseInstallmentCount, @CivilDateConverter()  CivilDate firstDueDate, @CivilDateConverter()  CivilDate disbursedOn,  String? guarantor,  String? notes, @MoneyPaiseConverter()@JsonKey(name: 'totalPaidPaise')  Money totalPaid, @MoneyPaiseConverter()@JsonKey(name: 'totalWaivedPaise')  Money totalWaived, @NullableCivilDateConverter()  CivilDate? lastPaymentOn,  DateTime? closedAt,  String? rolledOverFromContractId,  String? rolledOverToContractId, @NullableMoneyPaiseConverter()@JsonKey(name: 'rolloverSettledPaise')  Money? rolloverSettled,  String createdBy,  DateTime createdAt,  DateTime updatedAt,  int schemaVersion)?  $default,) {final _that = this;
switch (_that) {
case _Contract() when $default != null:
return $default(_that.id,_that.borrowerId,_that.borrowerName,_that.borrowerPhoneE164,_that.loanNo,_that.purpose,_that.status,_that.sanctioned,_that.upfrontMode,_that.upfrontInput,_that.upfront,_that.netDisbursed,_that.frequency,_that.preferredWeekday,_that.preferredMonthDay,_that.installmentAmount,_that.baseInstallmentCount,_that.firstDueDate,_that.disbursedOn,_that.guarantor,_that.notes,_that.totalPaid,_that.totalWaived,_that.lastPaymentOn,_that.closedAt,_that.rolledOverFromContractId,_that.rolledOverToContractId,_that.rolloverSettled,_that.createdBy,_that.createdAt,_that.updatedAt,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Contract extends Contract {
  const _Contract({@JsonKey(includeToJson: false) required this.id, required this.borrowerId, required this.borrowerName, required this.borrowerPhoneE164, required this.loanNo, this.purpose, this.status = ContractStatus.active, @MoneyPaiseConverter()@JsonKey(name: 'sanctionedPaise') required this.sanctioned, required this.upfrontMode, required this.upfrontInput, @MoneyPaiseConverter()@JsonKey(name: 'upfrontPaise') required this.upfront, @MoneyPaiseConverter()@JsonKey(name: 'netDisbursedPaise') required this.netDisbursed, required this.frequency, this.preferredWeekday, this.preferredMonthDay, @MoneyPaiseConverter()@JsonKey(name: 'installmentPaise') required this.installmentAmount, required this.baseInstallmentCount, @CivilDateConverter() required this.firstDueDate, @CivilDateConverter() required this.disbursedOn, this.guarantor, this.notes, @MoneyPaiseConverter()@JsonKey(name: 'totalPaidPaise') this.totalPaid = Money.zero, @MoneyPaiseConverter()@JsonKey(name: 'totalWaivedPaise') this.totalWaived = Money.zero, @NullableCivilDateConverter() this.lastPaymentOn, this.closedAt, this.rolledOverFromContractId, this.rolledOverToContractId, @NullableMoneyPaiseConverter()@JsonKey(name: 'rolloverSettledPaise') this.rolloverSettled, required this.createdBy, required this.createdAt, required this.updatedAt, this.schemaVersion = 1}): super._();
  factory _Contract.fromJson(Map<String, dynamic> json) => _$ContractFromJson(json);

@override@JsonKey(includeToJson: false) final  String id;
// Identity.
@override final  String borrowerId;
@override final  String borrowerName;
@override final  String borrowerPhoneE164;
@override final  int loanNo;
@override final  String? purpose;
// Lifecycle.
@override@JsonKey() final  ContractStatus status;
// Amounts.
/// Repayable principal.
@override@MoneyPaiseConverter()@JsonKey(name: 'sanctionedPaise') final  Money sanctioned;
@override final  UpfrontMode upfrontMode;
/// Paise when [upfrontMode] is flat; basis points (700 = 7.00%) when
/// percent.
@override final  int upfrontInput;
/// Amount actually deducted up front.
@override@MoneyPaiseConverter()@JsonKey(name: 'upfrontPaise') final  Money upfront;
/// sanctioned − upfront (for a rollover: − settled old outstanding too).
@override@MoneyPaiseConverter()@JsonKey(name: 'netDisbursedPaise') final  Money netDisbursed;
// Schedule terms.
@override final  Frequency frequency;
/// 1 = Mon … 7 = Sun (weekly).
@override final  int? preferredWeekday;
/// 1–31, clamped to month length (monthly).
@override final  int? preferredMonthDay;
@override@MoneyPaiseConverter()@JsonKey(name: 'installmentPaise') final  Money installmentAmount;
@override final  int baseInstallmentCount;
@override@CivilDateConverter() final  CivilDate firstDueDate;
@override@CivilDateConverter() final  CivilDate disbursedOn;
// Optional details.
@override final  String? guarantor;
@override final  String? notes;
// Running total (cache; the projection is the source of truth).
@override@MoneyPaiseConverter()@JsonKey(name: 'totalPaidPaise') final  Money totalPaid;
/// Running total of early-closure waivers (cache; not cash).
@override@MoneyPaiseConverter()@JsonKey(name: 'totalWaivedPaise') final  Money totalWaived;
// Lifecycle dates.
@override@NullableCivilDateConverter() final  CivilDate? lastPaymentOn;
@override final  DateTime? closedAt;
// Rollover links.
@override final  String? rolledOverFromContractId;
@override final  String? rolledOverToContractId;
@override@NullableMoneyPaiseConverter()@JsonKey(name: 'rolloverSettledPaise') final  Money? rolloverSettled;
// Audit.
@override final  String createdBy;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override@JsonKey() final  int schemaVersion;

/// Create a copy of Contract
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContractCopyWith<_Contract> get copyWith => __$ContractCopyWithImpl<_Contract>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ContractToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Contract&&(identical(other.id, id) || other.id == id)&&(identical(other.borrowerId, borrowerId) || other.borrowerId == borrowerId)&&(identical(other.borrowerName, borrowerName) || other.borrowerName == borrowerName)&&(identical(other.borrowerPhoneE164, borrowerPhoneE164) || other.borrowerPhoneE164 == borrowerPhoneE164)&&(identical(other.loanNo, loanNo) || other.loanNo == loanNo)&&(identical(other.purpose, purpose) || other.purpose == purpose)&&(identical(other.status, status) || other.status == status)&&(identical(other.sanctioned, sanctioned) || other.sanctioned == sanctioned)&&(identical(other.upfrontMode, upfrontMode) || other.upfrontMode == upfrontMode)&&(identical(other.upfrontInput, upfrontInput) || other.upfrontInput == upfrontInput)&&(identical(other.upfront, upfront) || other.upfront == upfront)&&(identical(other.netDisbursed, netDisbursed) || other.netDisbursed == netDisbursed)&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.preferredWeekday, preferredWeekday) || other.preferredWeekday == preferredWeekday)&&(identical(other.preferredMonthDay, preferredMonthDay) || other.preferredMonthDay == preferredMonthDay)&&(identical(other.installmentAmount, installmentAmount) || other.installmentAmount == installmentAmount)&&(identical(other.baseInstallmentCount, baseInstallmentCount) || other.baseInstallmentCount == baseInstallmentCount)&&(identical(other.firstDueDate, firstDueDate) || other.firstDueDate == firstDueDate)&&(identical(other.disbursedOn, disbursedOn) || other.disbursedOn == disbursedOn)&&(identical(other.guarantor, guarantor) || other.guarantor == guarantor)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.totalPaid, totalPaid) || other.totalPaid == totalPaid)&&(identical(other.totalWaived, totalWaived) || other.totalWaived == totalWaived)&&(identical(other.lastPaymentOn, lastPaymentOn) || other.lastPaymentOn == lastPaymentOn)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.rolledOverFromContractId, rolledOverFromContractId) || other.rolledOverFromContractId == rolledOverFromContractId)&&(identical(other.rolledOverToContractId, rolledOverToContractId) || other.rolledOverToContractId == rolledOverToContractId)&&(identical(other.rolloverSettled, rolloverSettled) || other.rolloverSettled == rolloverSettled)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,borrowerId,borrowerName,borrowerPhoneE164,loanNo,purpose,status,sanctioned,upfrontMode,upfrontInput,upfront,netDisbursed,frequency,preferredWeekday,preferredMonthDay,installmentAmount,baseInstallmentCount,firstDueDate,disbursedOn,guarantor,notes,totalPaid,totalWaived,lastPaymentOn,closedAt,rolledOverFromContractId,rolledOverToContractId,rolloverSettled,createdBy,createdAt,updatedAt,schemaVersion]);

@override
String toString() {
  return 'Contract(id: $id, borrowerId: $borrowerId, borrowerName: $borrowerName, borrowerPhoneE164: $borrowerPhoneE164, loanNo: $loanNo, purpose: $purpose, status: $status, sanctioned: $sanctioned, upfrontMode: $upfrontMode, upfrontInput: $upfrontInput, upfront: $upfront, netDisbursed: $netDisbursed, frequency: $frequency, preferredWeekday: $preferredWeekday, preferredMonthDay: $preferredMonthDay, installmentAmount: $installmentAmount, baseInstallmentCount: $baseInstallmentCount, firstDueDate: $firstDueDate, disbursedOn: $disbursedOn, guarantor: $guarantor, notes: $notes, totalPaid: $totalPaid, totalWaived: $totalWaived, lastPaymentOn: $lastPaymentOn, closedAt: $closedAt, rolledOverFromContractId: $rolledOverFromContractId, rolledOverToContractId: $rolledOverToContractId, rolloverSettled: $rolloverSettled, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class _$ContractCopyWith<$Res> implements $ContractCopyWith<$Res> {
  factory _$ContractCopyWith(_Contract value, $Res Function(_Contract) _then) = __$ContractCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(includeToJson: false) String id, String borrowerId, String borrowerName, String borrowerPhoneE164, int loanNo, String? purpose, ContractStatus status,@MoneyPaiseConverter()@JsonKey(name: 'sanctionedPaise') Money sanctioned, UpfrontMode upfrontMode, int upfrontInput,@MoneyPaiseConverter()@JsonKey(name: 'upfrontPaise') Money upfront,@MoneyPaiseConverter()@JsonKey(name: 'netDisbursedPaise') Money netDisbursed, Frequency frequency, int? preferredWeekday, int? preferredMonthDay,@MoneyPaiseConverter()@JsonKey(name: 'installmentPaise') Money installmentAmount, int baseInstallmentCount,@CivilDateConverter() CivilDate firstDueDate,@CivilDateConverter() CivilDate disbursedOn, String? guarantor, String? notes,@MoneyPaiseConverter()@JsonKey(name: 'totalPaidPaise') Money totalPaid,@MoneyPaiseConverter()@JsonKey(name: 'totalWaivedPaise') Money totalWaived,@NullableCivilDateConverter() CivilDate? lastPaymentOn, DateTime? closedAt, String? rolledOverFromContractId, String? rolledOverToContractId,@NullableMoneyPaiseConverter()@JsonKey(name: 'rolloverSettledPaise') Money? rolloverSettled, String createdBy, DateTime createdAt, DateTime updatedAt, int schemaVersion
});




}
/// @nodoc
class __$ContractCopyWithImpl<$Res>
    implements _$ContractCopyWith<$Res> {
  __$ContractCopyWithImpl(this._self, this._then);

  final _Contract _self;
  final $Res Function(_Contract) _then;

/// Create a copy of Contract
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? borrowerId = null,Object? borrowerName = null,Object? borrowerPhoneE164 = null,Object? loanNo = null,Object? purpose = freezed,Object? status = null,Object? sanctioned = null,Object? upfrontMode = null,Object? upfrontInput = null,Object? upfront = null,Object? netDisbursed = null,Object? frequency = null,Object? preferredWeekday = freezed,Object? preferredMonthDay = freezed,Object? installmentAmount = null,Object? baseInstallmentCount = null,Object? firstDueDate = null,Object? disbursedOn = null,Object? guarantor = freezed,Object? notes = freezed,Object? totalPaid = null,Object? totalWaived = null,Object? lastPaymentOn = freezed,Object? closedAt = freezed,Object? rolledOverFromContractId = freezed,Object? rolledOverToContractId = freezed,Object? rolloverSettled = freezed,Object? createdBy = null,Object? createdAt = null,Object? updatedAt = null,Object? schemaVersion = null,}) {
  return _then(_Contract(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,borrowerId: null == borrowerId ? _self.borrowerId : borrowerId // ignore: cast_nullable_to_non_nullable
as String,borrowerName: null == borrowerName ? _self.borrowerName : borrowerName // ignore: cast_nullable_to_non_nullable
as String,borrowerPhoneE164: null == borrowerPhoneE164 ? _self.borrowerPhoneE164 : borrowerPhoneE164 // ignore: cast_nullable_to_non_nullable
as String,loanNo: null == loanNo ? _self.loanNo : loanNo // ignore: cast_nullable_to_non_nullable
as int,purpose: freezed == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ContractStatus,sanctioned: null == sanctioned ? _self.sanctioned : sanctioned // ignore: cast_nullable_to_non_nullable
as Money,upfrontMode: null == upfrontMode ? _self.upfrontMode : upfrontMode // ignore: cast_nullable_to_non_nullable
as UpfrontMode,upfrontInput: null == upfrontInput ? _self.upfrontInput : upfrontInput // ignore: cast_nullable_to_non_nullable
as int,upfront: null == upfront ? _self.upfront : upfront // ignore: cast_nullable_to_non_nullable
as Money,netDisbursed: null == netDisbursed ? _self.netDisbursed : netDisbursed // ignore: cast_nullable_to_non_nullable
as Money,frequency: null == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as Frequency,preferredWeekday: freezed == preferredWeekday ? _self.preferredWeekday : preferredWeekday // ignore: cast_nullable_to_non_nullable
as int?,preferredMonthDay: freezed == preferredMonthDay ? _self.preferredMonthDay : preferredMonthDay // ignore: cast_nullable_to_non_nullable
as int?,installmentAmount: null == installmentAmount ? _self.installmentAmount : installmentAmount // ignore: cast_nullable_to_non_nullable
as Money,baseInstallmentCount: null == baseInstallmentCount ? _self.baseInstallmentCount : baseInstallmentCount // ignore: cast_nullable_to_non_nullable
as int,firstDueDate: null == firstDueDate ? _self.firstDueDate : firstDueDate // ignore: cast_nullable_to_non_nullable
as CivilDate,disbursedOn: null == disbursedOn ? _self.disbursedOn : disbursedOn // ignore: cast_nullable_to_non_nullable
as CivilDate,guarantor: freezed == guarantor ? _self.guarantor : guarantor // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,totalPaid: null == totalPaid ? _self.totalPaid : totalPaid // ignore: cast_nullable_to_non_nullable
as Money,totalWaived: null == totalWaived ? _self.totalWaived : totalWaived // ignore: cast_nullable_to_non_nullable
as Money,lastPaymentOn: freezed == lastPaymentOn ? _self.lastPaymentOn : lastPaymentOn // ignore: cast_nullable_to_non_nullable
as CivilDate?,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rolledOverFromContractId: freezed == rolledOverFromContractId ? _self.rolledOverFromContractId : rolledOverFromContractId // ignore: cast_nullable_to_non_nullable
as String?,rolledOverToContractId: freezed == rolledOverToContractId ? _self.rolledOverToContractId : rolledOverToContractId // ignore: cast_nullable_to_non_nullable
as String?,rolloverSettled: freezed == rolloverSettled ? _self.rolloverSettled : rolloverSettled // ignore: cast_nullable_to_non_nullable
as Money?,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
