import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/money/money.dart';
import '../../core/time/civil_date.dart';
import 'enums.dart';
import 'json_converters.dart';

part 'ledger_transaction.freezed.dart';
part 'ledger_transaction.g.dart';

/// `companies/{cid}/transactions/{txId}`. Append-only and immutable:
/// corrections are a new [TxType.reversal] doc.
@freezed
abstract class LedgerTransaction with _$LedgerTransaction {
  const factory LedgerTransaction({
    @JsonKey(includeToJson: false) required String id,
    required String contractId,
    required String borrowerId,
    required String borrowerName,
    required int loanNo,
    @Default(true) bool contractActive,
    required TxType type,

    /// ≥ 0; 0 only for a reschedule audit entry.
    @MoneyPaiseConverter() @JsonKey(name: 'amountPaise') required Money amount,
    @CivilDateConverter() required CivilDate paidOn,
    PaymentMode? mode,
    String? reference,
    String? note,
    String? reversesTxId,

    /// Rollover counterpart.
    String? relatedContractId,
    Map<String, dynamic>? rescheduleInfo,
    required String recordedBy,
    required String recordedByName,

    /// Server timestamp. `null` while the write is pending (offline); use
    /// [effectiveRecordedAt] for display and ordering.
    DateTime? recordedAt,
    required DateTime clientRecordedAt,
    required String deviceId,
    @Default(1) int schemaVersion,
  }) = _LedgerTransaction;

  const LedgerTransaction._();

  /// [recordedAt], falling back to [clientRecordedAt] while pending.
  DateTime get effectiveRecordedAt => recordedAt ?? clientRecordedAt;

  factory LedgerTransaction.fromJson(Map<String, dynamic> json) =>
      _$LedgerTransactionFromJson(json);
}
