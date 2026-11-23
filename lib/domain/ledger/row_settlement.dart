import '../../core/time/civil_date.dart';
import '../models/enums.dart';
import '../models/ledger_transaction.dart';
import 'contract_projection.dart';
import 'tx_order.dart';

/// The payment that completed a paid row (timeline "cleared {date}" and the
/// mode chip).
final class RowSettlement {
  const RowSettlement({required this.clearedOn, this.mode});

  final CivilDate clearedOn;

  /// Mode of the completing payment; null for a rollover settlement or a
  /// waiver.
  final PaymentMode? mode;

  @override
  bool operator ==(Object other) =>
      other is RowSettlement &&
      other.clearedOn == clearedOn &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(clearedOn, mode);

  @override
  String toString() => 'RowSettlement($clearedOn, ${mode?.name})';
}

/// When each paid row of [projection] was cleared, keyed by installment id.
///
/// Replays the contract's payment / settlement / reversal transactions in
/// `(paidOn, recorded, id)` order against the cumulative due of the
/// effective rows (the same FIFO order as the projection). A row is cleared
/// by the transaction after which the running pool first covers it; a
/// reversal that drops the pool below a row's cumulative due un-clears it,
/// and the next covering payment clears it again.
Map<String, RowSettlement> rowSettlements(
  ContractProjection projection,
  Iterable<LedgerTransaction> transactions,
) {
  final contractId = projection.contract.id;
  final txs =
      transactions
          .where(
            (LedgerTransaction t) =>
                t.contractId == contractId &&
                (t.type == TxType.payment ||
                    t.type == TxType.rolloverSettlement ||
                    t.type == TxType.waiver ||
                    t.type == TxType.reversal),
          )
          .toList()
        ..sort(compareTxChronological);

  // Cumulative due of each paid stored row, in allocation order.
  final targets = <(String, int)>[];
  var cumulative = 0;
  for (final row in projection.rows) {
    if (row.isExtension || row.isRescheduledAway) continue;
    cumulative += row.due.paise;
    if (row.status == RowStatus.paid) {
      targets.add((row.installmentId!, cumulative));
    }
  }

  final out = <String, RowSettlement>{};
  var pool = 0;
  for (final t in txs) {
    pool += t.type == TxType.reversal ? -t.amount.paise : t.amount.paise;
    for (final (id, target) in targets) {
      if (pool >= target) {
        out.putIfAbsent(
          id,
          () => RowSettlement(clearedOn: t.paidOn, mode: t.mode),
        );
      } else {
        out.remove(id);
      }
    }
  }
  return out;
}
