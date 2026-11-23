import '../models/enums.dart';
import '../models/ledger_transaction.dart';

/// Oldest-first order for ledger transactions: `paidOn`, then recorded time,
/// then a type rank, then id.
///
/// The cash payment and the waiver of one early closure share every
/// timestamp (same batch). The rank puts the waiver after the payment, so the
/// cash settles the earlier rows and the waiver clears the tail, every time.
int compareTxChronological(LedgerTransaction a, LedgerTransaction b) {
  final byDate = a.paidOn.compareTo(b.paidOn);
  if (byDate != 0) return byDate;
  final byTime = a.effectiveRecordedAt.compareTo(b.effectiveRecordedAt);
  if (byTime != 0) return byTime;
  final byRank = _rank(a.type) - _rank(b.type);
  if (byRank != 0) return byRank;
  return a.id.compareTo(b.id);
}

int _rank(TxType t) => t == TxType.waiver ? 1 : 0;
