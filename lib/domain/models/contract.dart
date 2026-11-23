import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/money/money.dart';
import '../../core/time/civil_date.dart';
import 'enums.dart';
import 'json_converters.dart';

part 'contract.freezed.dart';
part 'contract.g.dart';

/// `companies/{cid}/contracts/{contractId}`.
///
/// Money fields are [Money] in Dart and `int` paise in the document (key
/// names keep the `...Paise` suffix). Civil dates are [CivilDate] in Dart and
/// `'yyyy-MM-dd'` strings in the document.
@freezed
abstract class Contract with _$Contract {
  const factory Contract({
    @JsonKey(includeToJson: false) required String id,

    // Identity.
    required String borrowerId,
    required String borrowerName,
    required String borrowerPhoneE164,
    required int loanNo,
    String? purpose,

    // Lifecycle.
    @Default(ContractStatus.active) ContractStatus status,

    // Amounts.
    /// Repayable principal.
    @MoneyPaiseConverter()
    @JsonKey(name: 'sanctionedPaise')
    required Money sanctioned,
    required UpfrontMode upfrontMode,

    /// Paise when [upfrontMode] is flat; basis points (700 = 7.00%) when
    /// percent.
    required int upfrontInput,

    /// Amount actually deducted up front.
    @MoneyPaiseConverter()
    @JsonKey(name: 'upfrontPaise')
    required Money upfront,

    /// sanctioned − upfront (for a rollover: − settled old outstanding too).
    @MoneyPaiseConverter()
    @JsonKey(name: 'netDisbursedPaise')
    required Money netDisbursed,

    // Schedule terms.
    required Frequency frequency,

    /// 1 = Mon … 7 = Sun (weekly).
    int? preferredWeekday,

    /// 1–31, clamped to month length (monthly).
    int? preferredMonthDay,
    @MoneyPaiseConverter()
    @JsonKey(name: 'installmentPaise')
    required Money installmentAmount,
    required int baseInstallmentCount,
    @CivilDateConverter() required CivilDate firstDueDate,
    @CivilDateConverter() required CivilDate disbursedOn,

    // Optional details.
    String? guarantor,
    String? notes,

    // Running total (cache; the projection is the source of truth).
    @MoneyPaiseConverter()
    @JsonKey(name: 'totalPaidPaise')
    @Default(Money.zero)
    Money totalPaid,

    /// Running total of early-closure waivers (cache; not cash).
    @MoneyPaiseConverter()
    @JsonKey(name: 'totalWaivedPaise')
    @Default(Money.zero)
    Money totalWaived,

    // Lifecycle dates.
    @NullableCivilDateConverter() CivilDate? lastPaymentOn,
    DateTime? closedAt,

    // Rollover links.
    String? rolledOverFromContractId,
    String? rolledOverToContractId,
    @NullableMoneyPaiseConverter()
    @JsonKey(name: 'rolloverSettledPaise')
    Money? rolloverSettled,

    // Audit.
    required String createdBy,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(1) int schemaVersion,
  }) = _Contract;

  const Contract._();

  bool get isActive => status == ContractStatus.active;

  factory Contract.fromJson(Map<String, dynamic> json) =>
      _$ContractFromJson(json);
}
