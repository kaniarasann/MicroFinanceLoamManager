// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contract.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Contract _$ContractFromJson(Map<String, dynamic> json) => _Contract(
  id: json['id'] as String,
  borrowerId: json['borrowerId'] as String,
  borrowerName: json['borrowerName'] as String,
  borrowerPhoneE164: json['borrowerPhoneE164'] as String,
  loanNo: (json['loanNo'] as num).toInt(),
  purpose: json['purpose'] as String?,
  status:
      $enumDecodeNullable(_$ContractStatusEnumMap, json['status']) ??
      ContractStatus.active,
  origin:
      $enumDecodeNullable(
        _$ContractOriginEnumMap,
        json['origin'],
        unknownValue: ContractOrigin.standard,
      ) ??
      ContractOrigin.standard,
  onboardedOn: const NullableCivilDateConverter().fromJson(
    json['onboardedOn'] as String?,
  ),
  previousRef: json['previousRef'] as String?,
  onboardedPaymentCount: (json['onboardedPaymentCount'] as num?)?.toInt(),
  onboardedTotal: const NullableMoneyPaiseConverter().fromJson(
    (json['onboardedTotalPaise'] as num?)?.toInt(),
  ),
  sanctioned: const MoneyPaiseConverter().fromJson(
    (json['sanctionedPaise'] as num).toInt(),
  ),
  upfrontMode: $enumDecode(_$UpfrontModeEnumMap, json['upfrontMode']),
  upfrontInput: (json['upfrontInput'] as num).toInt(),
  upfront: const MoneyPaiseConverter().fromJson(
    (json['upfrontPaise'] as num).toInt(),
  ),
  netDisbursed: const MoneyPaiseConverter().fromJson(
    (json['netDisbursedPaise'] as num).toInt(),
  ),
  frequency: $enumDecode(_$FrequencyEnumMap, json['frequency']),
  preferredWeekday: (json['preferredWeekday'] as num?)?.toInt(),
  preferredMonthDay: (json['preferredMonthDay'] as num?)?.toInt(),
  installmentAmount: const MoneyPaiseConverter().fromJson(
    (json['installmentPaise'] as num).toInt(),
  ),
  baseInstallmentCount: (json['baseInstallmentCount'] as num).toInt(),
  firstDueDate: const CivilDateConverter().fromJson(
    json['firstDueDate'] as String,
  ),
  disbursedOn: const CivilDateConverter().fromJson(
    json['disbursedOn'] as String,
  ),
  guarantor: json['guarantor'] as String?,
  notes: json['notes'] as String?,
  totalPaid: json['totalPaidPaise'] == null
      ? Money.zero
      : const MoneyPaiseConverter().fromJson(
          (json['totalPaidPaise'] as num).toInt(),
        ),
  totalWaived: json['totalWaivedPaise'] == null
      ? Money.zero
      : const MoneyPaiseConverter().fromJson(
          (json['totalWaivedPaise'] as num).toInt(),
        ),
  lastPaymentOn: const NullableCivilDateConverter().fromJson(
    json['lastPaymentOn'] as String?,
  ),
  closedAt: json['closedAt'] == null
      ? null
      : DateTime.parse(json['closedAt'] as String),
  rolledOverFromContractId: json['rolledOverFromContractId'] as String?,
  rolledOverToContractId: json['rolledOverToContractId'] as String?,
  rolloverSettled: const NullableMoneyPaiseConverter().fromJson(
    (json['rolloverSettledPaise'] as num?)?.toInt(),
  ),
  createdBy: json['createdBy'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$ContractToJson(_Contract instance) => <String, dynamic>{
  'borrowerId': instance.borrowerId,
  'borrowerName': instance.borrowerName,
  'borrowerPhoneE164': instance.borrowerPhoneE164,
  'loanNo': instance.loanNo,
  'purpose': instance.purpose,
  'status': _$ContractStatusEnumMap[instance.status]!,
  'origin': _$ContractOriginEnumMap[instance.origin]!,
  'onboardedOn': const NullableCivilDateConverter().toJson(
    instance.onboardedOn,
  ),
  'previousRef': instance.previousRef,
  'onboardedPaymentCount': instance.onboardedPaymentCount,
  'onboardedTotalPaise': const NullableMoneyPaiseConverter().toJson(
    instance.onboardedTotal,
  ),
  'sanctionedPaise': const MoneyPaiseConverter().toJson(instance.sanctioned),
  'upfrontMode': _$UpfrontModeEnumMap[instance.upfrontMode]!,
  'upfrontInput': instance.upfrontInput,
  'upfrontPaise': const MoneyPaiseConverter().toJson(instance.upfront),
  'netDisbursedPaise': const MoneyPaiseConverter().toJson(
    instance.netDisbursed,
  ),
  'frequency': _$FrequencyEnumMap[instance.frequency]!,
  'preferredWeekday': instance.preferredWeekday,
  'preferredMonthDay': instance.preferredMonthDay,
  'installmentPaise': const MoneyPaiseConverter().toJson(
    instance.installmentAmount,
  ),
  'baseInstallmentCount': instance.baseInstallmentCount,
  'firstDueDate': const CivilDateConverter().toJson(instance.firstDueDate),
  'disbursedOn': const CivilDateConverter().toJson(instance.disbursedOn),
  'guarantor': instance.guarantor,
  'notes': instance.notes,
  'totalPaidPaise': const MoneyPaiseConverter().toJson(instance.totalPaid),
  'totalWaivedPaise': const MoneyPaiseConverter().toJson(instance.totalWaived),
  'lastPaymentOn': const NullableCivilDateConverter().toJson(
    instance.lastPaymentOn,
  ),
  'closedAt': instance.closedAt?.toIso8601String(),
  'rolledOverFromContractId': instance.rolledOverFromContractId,
  'rolledOverToContractId': instance.rolledOverToContractId,
  'rolloverSettledPaise': const NullableMoneyPaiseConverter().toJson(
    instance.rolloverSettled,
  ),
  'createdBy': instance.createdBy,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'schemaVersion': instance.schemaVersion,
};

const _$ContractStatusEnumMap = {
  ContractStatus.active: 'active',
  ContractStatus.closed: 'closed',
  ContractStatus.rolledOver: 'rolledOver',
  ContractStatus.cancelled: 'cancelled',
};

const _$ContractOriginEnumMap = {
  ContractOrigin.standard: 'standard',
  ContractOrigin.onboarded: 'onboarded',
};

const _$UpfrontModeEnumMap = {
  UpfrontMode.flat: 'flat',
  UpfrontMode.percent: 'percent',
};

const _$FrequencyEnumMap = {
  Frequency.daily: 'daily',
  Frequency.weekly: 'weekly',
  Frequency.monthly: 'monthly',
};
