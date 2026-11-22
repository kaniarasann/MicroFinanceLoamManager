import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/money/money.dart';
import '../../core/time/civil_date.dart';
import 'enums.dart';
import 'json_converters.dart';

part 'installment.freezed.dart';
part 'installment.g.dart';

/// `companies/{cid}/installments/{installmentId}`.
///
/// No paid amount or status is stored: both are derived by the projection.
/// Auto-extension rows are computed and never stored.
@freezed
abstract class Installment with _$Installment {
  const factory Installment({
    @JsonKey(includeToJson: false) required String id,
    required String contractId,
    required String borrowerId,
    required String borrowerName,
    required int loanNo,
    @Default(true) bool contractActive,

    /// 1..n; rescheduled rows take the next seq.
    required int seq,
    @Default(InstallmentKind.base) InstallmentKind kind,
    @CivilDateConverter() required CivilDate dueDate,
    @MoneyPaiseConverter()
    @JsonKey(name: 'amountDuePaise')
    required Money amountDue,
    @MoneyPaiseConverter()
    @JsonKey(name: 'rescheduledOutPaise')
    @Default(Money.zero)
    Money rescheduledOut,
    @Default(<String>[]) List<String> rescheduledToIds,
    String? rescheduledFromId,
    required String createdBy,
    required DateTime createdAt,
    @Default(1) int schemaVersion,
  }) = _Installment;

  factory Installment.fromJson(Map<String, dynamic> json) =>
      _$InstallmentFromJson(json);
}
