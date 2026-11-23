import '../../core/money/money.dart';
import '../../core/time/civil_date.dart';
import '../models/contract.dart';
import '../models/enums.dart';
import '../models/ledger_transaction.dart';
import 'contract_projection.dart';
import 'tx_order.dart';

/// How a borrower (or one contract) stands today. Derived, never stored.
enum Standing {
  /// At least one installment is past due and not fully paid.
  overdue,

  /// Nothing overdue, but an installment is due today.
  dueToday,

  /// Active, nothing overdue or due today.
  onTrack,

  /// No active contract.
  none,
}

/// The standing of one active contract.
Standing contractStanding(ContractProjection p) {
  if (p.hasOverdue) return Standing.overdue;
  final dueToday = p.rows.any(
    (ProjectedRow r) => r.status == RowStatus.dueToday && r.isOpen,
  );
  return dueToday ? Standing.dueToday : Standing.onTrack;
}

/// Whether [p] has an open installment due today or in the next 6 days
/// (overdue rows are not counted: they have their own filter).
bool dueWithinWeek(ContractProjection p, CivilDate today) => p.rows.any(
  (ProjectedRow r) =>
      r.isOpen &&
      !r.dueDate.isBefore(today) &&
      today.daysBetween(r.dueDate) < DateTime.daysPerWeek,
);

/// Per-borrower figures for the borrower list, from the active contracts'
/// projections.
final class BorrowerListStats {
  const BorrowerListStats({
    required this.activeCount,
    required this.outstanding,
    required this.standing,
    required this.maxDaysOverdue,
    required this.dueThisWeek,
  });

  static const BorrowerListStats empty = BorrowerListStats(
    activeCount: 0,
    outstanding: Money.zero,
    standing: Standing.none,
    maxDaysOverdue: 0,
    dueThisWeek: false,
  );

  final int activeCount;

  /// Σ outstanding of the active contracts.
  final Money outstanding;
  final Standing standing;

  /// Highest days overdue across the active contracts (0 when none).
  final int maxDaysOverdue;
  final bool dueThisWeek;
}

/// Folds one borrower's active projections into [BorrowerListStats].
BorrowerListStats borrowerListStats(
  Iterable<ContractProjection> active,
  CivilDate today,
) {
  var count = 0;
  var outstanding = Money.zero;
  var maxDays = 0;
  var anyDueToday = false;
  var anyOverdue = false;
  var week = false;
  for (final p in active) {
    count++;
    outstanding += p.outstanding;
    switch (contractStanding(p)) {
      case Standing.overdue:
        anyOverdue = true;
        if (p.maxDaysOverdue > maxDays) maxDays = p.maxDaysOverdue;
      case Standing.dueToday:
        anyDueToday = true;
      case Standing.onTrack:
      case Standing.none:
        break;
    }
    if (dueWithinWeek(p, today)) week = true;
  }
  final Standing standing;
  if (count == 0) {
    standing = Standing.none;
  } else if (anyOverdue) {
    standing = Standing.overdue;
  } else if (anyDueToday) {
    standing = Standing.dueToday;
  } else {
    standing = Standing.onTrack;
  }
  return BorrowerListStats(
    activeCount: count,
    outstanding: outstanding,
    standing: standing,
    maxDaysOverdue: maxDays,
    dueThisWeek: week,
  );
}

/// One money movement in a borrower's ledger, with the contract's
/// outstanding balance right after it.
final class LedgerEntry {
  const LedgerEntry({required this.tx, required this.balanceAfter});

  final LedgerTransaction tx;

  /// sanctioned − net paid pool up to and including [tx], floored at 0.
  /// Null when the contract is not loaded.
  final Money? balanceAfter;
}

/// Borrower profile aggregates (Section 1, "borrower profile").
final class BorrowerSummary {
  const BorrowerSummary({
    required this.activeExposure,
    required this.lifetimeLent,
    required this.collected,
    required this.active,
    required this.closed,
    required this.ledger,
    required this.recentReceipts,
    required this.stats,
    required this.contractsById,
  });

  /// Σ outstanding of the active contracts.
  final Money activeExposure;

  /// Σ sanctioned of every contract (cancelled ones excluded).
  final Money lifetimeLent;

  /// Σ payments − reversals of payments (waivers and settlements are not
  /// cash).
  final Money collected;

  /// Active contracts' projections, newest loan first.
  final List<ContractProjection> active;

  /// Closed and rolled-over contracts, newest loan first.
  final List<Contract> closed;

  /// Money movements, newest first.
  final List<LedgerEntry> ledger;

  /// The latest [recentReceiptsLimit] payments, newest first.
  final List<LedgerEntry> recentReceipts;

  final BorrowerListStats stats;

  /// Every known contract of the borrower (for loan numbers and links).
  final Map<String, Contract> contractsById;

  static const int recentReceiptsLimit = 10;
}

/// Ledger types that move money (reschedule audit rows do not).
bool _isMoney(TxType t) => t != TxType.reschedule;

/// Builds the borrower's profile figures.
///
/// [active] are the borrower's active-contract projections. [contracts] are
/// any further known contracts (closed / rolled over; active ones may repeat
/// and are de-duplicated by id). [transactions] may repeat too.
BorrowerSummary summarizeBorrower({
  required List<ContractProjection> active,
  required List<Contract> contracts,
  required List<LedgerTransaction> transactions,
  required CivilDate today,
}) {
  final byId = <String, Contract>{
    for (final c in contracts) c.id: c,
    for (final p in active) p.contract.id: p.contract,
  };
  final txs =
      <String, LedgerTransaction>{
          for (final t in transactions) t.id: t,
        }.values.where((LedgerTransaction t) => _isMoney(t.type)).toList()
        ..sort(compareTxChronological);

  final typeById = <String, TxType>{for (final t in txs) t.id: t.type};
  var collected = 0;
  final pools = <String, int>{};
  final entries = <LedgerEntry>[];
  for (final t in txs) {
    final pool = pools[t.contractId] ?? 0;
    switch (t.type) {
      case TxType.payment:
        collected += t.amount.paise;
        pools[t.contractId] = pool + t.amount.paise;
      case TxType.rolloverSettlement:
      case TxType.waiver:
        // Settles the loan but is not cash: not in "Collected".
        pools[t.contractId] = pool + t.amount.paise;
      case TxType.reversal:
        final original = t.reversesTxId == null
            ? null
            : typeById[t.reversesTxId];
        // An unknown original with no mode is a waiver reversal: payments
        // always carry a mode and reversals copy it; waivers never do.
        if (original == TxType.payment ||
            (original == null && t.mode != null)) {
          collected -= t.amount.paise;
        }
        pools[t.contractId] = pool - t.amount.paise;
      case TxType.disbursement:
      case TxType.reschedule:
        break;
    }
    final contract = byId[t.contractId];
    final Money? balance;
    if (contract == null) {
      balance = null;
    } else {
      final left = contract.sanctioned.paise - (pools[t.contractId] ?? 0);
      balance = Money(left > 0 ? left : 0);
    }
    entries.add(LedgerEntry(tx: t, balanceAfter: balance));
  }
  final ledger = entries.reversed.toList(growable: false);

  final activeSorted = List<ContractProjection>.of(active)
    ..sort(
      (ContractProjection a, ContractProjection b) =>
          b.contract.loanNo.compareTo(a.contract.loanNo),
    );
  final closed =
      byId.values
          .where(
            (Contract c) =>
                c.status == ContractStatus.closed ||
                c.status == ContractStatus.rolledOver,
          )
          .toList()
        ..sort((Contract a, Contract b) => b.loanNo.compareTo(a.loanNo));

  var lent = Money.zero;
  for (final c in byId.values) {
    if (c.status != ContractStatus.cancelled) lent += c.sanctioned;
  }

  return BorrowerSummary(
    activeExposure: Money.sum(
      active.map((ContractProjection p) => p.outstanding),
    ),
    lifetimeLent: lent,
    collected: Money(collected),
    active: List<ContractProjection>.unmodifiable(activeSorted),
    closed: List<Contract>.unmodifiable(closed),
    ledger: ledger,
    recentReceipts: ledger
        .where((LedgerEntry e) => e.tx.type == TxType.payment)
        .take(BorrowerSummary.recentReceiptsLimit)
        .toList(growable: false),
    stats: borrowerListStats(active, today),
    contractsById: Map<String, Contract>.unmodifiable(byId),
  );
}
