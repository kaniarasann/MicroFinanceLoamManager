// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ledger_transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LedgerTransaction _$LedgerTransactionFromJson(Map<String, dynamic> json) =>
    _LedgerTransaction(
      id: json['id'] as String,
      contractId: json['contractId'] as String,
      borrowerId: json['borrowerId'] as String,
      borrowerName: json['borrowerName'] as String,
      loanNo: (json['loanNo'] as num).toInt(),
      contractActive: json['contractActive'] as bool? ?? true,
      type: $enumDecode(_$TxTypeEnumMap, json['type']),
      amount: const MoneyPaiseConverter().fromJson(
        (json['amountPaise'] as num).toInt(),
      ),
      paidOn: const CivilDateConverter().fromJson(json['paidOn'] as String),
      mode: $enumDecodeNullable(_$PaymentModeEnumMap, json['mode']),
      reference: json['reference'] as String?,
      note: json['note'] as String?,
      reversesTxId: json['reversesTxId'] as String?,
      relatedContractId: json['relatedContractId'] as String?,
      rescheduleInfo: json['rescheduleInfo'] as Map<String, dynamic>?,
      recordedBy: json['recordedBy'] as String,
      recordedByName: json['recordedByName'] as String,
      recordedAt: json['recordedAt'] == null
          ? null
          : DateTime.parse(json['recordedAt'] as String),
      clientRecordedAt: DateTime.parse(json['clientRecordedAt'] as String),
      deviceId: json['deviceId'] as String,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$LedgerTransactionToJson(_LedgerTransaction instance) =>
    <String, dynamic>{
      'contractId': instance.contractId,
      'borrowerId': instance.borrowerId,
      'borrowerName': instance.borrowerName,
      'loanNo': instance.loanNo,
      'contractActive': instance.contractActive,
      'type': _$TxTypeEnumMap[instance.type]!,
      'amountPaise': const MoneyPaiseConverter().toJson(instance.amount),
      'paidOn': const CivilDateConverter().toJson(instance.paidOn),
      'mode': _$PaymentModeEnumMap[instance.mode],
      'reference': instance.reference,
      'note': instance.note,
      'reversesTxId': instance.reversesTxId,
      'relatedContractId': instance.relatedContractId,
      'rescheduleInfo': instance.rescheduleInfo,
      'recordedBy': instance.recordedBy,
      'recordedByName': instance.recordedByName,
      'recordedAt': instance.recordedAt?.toIso8601String(),
      'clientRecordedAt': instance.clientRecordedAt.toIso8601String(),
      'deviceId': instance.deviceId,
      'schemaVersion': instance.schemaVersion,
    };

const _$TxTypeEnumMap = {
  TxType.disbursement: 'disbursement',
  TxType.payment: 'payment',
  TxType.rolloverSettlement: 'rolloverSettlement',
  TxType.reversal: 'reversal',
  TxType.reschedule: 'reschedule',
  TxType.waiver: 'waiver',
};

const _$PaymentModeEnumMap = {
  PaymentMode.upi: 'upi',
  PaymentMode.cash: 'cash',
  PaymentMode.bank: 'bank',
};
