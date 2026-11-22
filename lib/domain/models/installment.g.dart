// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Installment _$InstallmentFromJson(Map<String, dynamic> json) => _Installment(
  id: json['id'] as String,
  contractId: json['contractId'] as String,
  borrowerId: json['borrowerId'] as String,
  borrowerName: json['borrowerName'] as String,
  loanNo: (json['loanNo'] as num).toInt(),
  contractActive: json['contractActive'] as bool? ?? true,
  seq: (json['seq'] as num).toInt(),
  kind:
      $enumDecodeNullable(_$InstallmentKindEnumMap, json['kind']) ??
      InstallmentKind.base,
  dueDate: const CivilDateConverter().fromJson(json['dueDate'] as String),
  amountDue: const MoneyPaiseConverter().fromJson(
    (json['amountDuePaise'] as num).toInt(),
  ),
  rescheduledOut: json['rescheduledOutPaise'] == null
      ? Money.zero
      : const MoneyPaiseConverter().fromJson(
          (json['rescheduledOutPaise'] as num).toInt(),
        ),
  rescheduledToIds:
      (json['rescheduledToIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  rescheduledFromId: json['rescheduledFromId'] as String?,
  createdBy: json['createdBy'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$InstallmentToJson(_Installment instance) =>
    <String, dynamic>{
      'contractId': instance.contractId,
      'borrowerId': instance.borrowerId,
      'borrowerName': instance.borrowerName,
      'loanNo': instance.loanNo,
      'contractActive': instance.contractActive,
      'seq': instance.seq,
      'kind': _$InstallmentKindEnumMap[instance.kind]!,
      'dueDate': const CivilDateConverter().toJson(instance.dueDate),
      'amountDuePaise': const MoneyPaiseConverter().toJson(instance.amountDue),
      'rescheduledOutPaise': const MoneyPaiseConverter().toJson(
        instance.rescheduledOut,
      ),
      'rescheduledToIds': instance.rescheduledToIds,
      'rescheduledFromId': instance.rescheduledFromId,
      'createdBy': instance.createdBy,
      'createdAt': instance.createdAt.toIso8601String(),
      'schemaVersion': instance.schemaVersion,
    };

const _$InstallmentKindEnumMap = {
  InstallmentKind.base: 'base',
  InstallmentKind.rescheduled: 'rescheduled',
};
