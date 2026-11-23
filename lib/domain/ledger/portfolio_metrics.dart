import '../../core/money/money.dart';
import '../../core/time/civil_date.dart';
import '../models/contract.dart';
import '../models/enums.dart';
import '../models/ledger_transaction.dart';
import 'contract_projection.dart';

/// Window of the collections chart.
enum ChartPeriod { weeks8, months6, months12 }

/// Overdue tracker severity: critical (> 3 days) or recent (1–3 days).
enum OverdueSeverity { critical, recent }

/// Days overdue above which an item is [OverdueSeverity.critical].
const int criticalOverdueDays = 3;

/// One row due today, on any contract.
final class TodayDueItem {
  const TodayDueItem({
    required this.contractId,
    required this.borrowerName,
    required this.loanNo,
    required this.seq,
    required this.amount,
    required this.paid,
    required this.isExtension,
  });

  final String contractId;
  final String borrowerName;
  final int loanNo;
  final int seq;

  /// The row's effective due.
  final Money amount;

  /// FIFO-allocated paid amount on that row.
  final Money paid;
  final bool isExtension;

  bool get isPaid => paid >= amount;
}

/// "Today's due" card.
final class TodayDue {
  const TodayDue({
    required this.amountDue,
    required this.received,
    required this.items,
  });

  /// Σ effective due of rows due today.
  final Money amountDue;

  /// Net cash received today: payments − reversals with paidOn == today.
  final Money received;
  final List<TodayDueItem> items;
}

/// One bar of the collections chart.
final class CollectionBucket {
  const CollectionBucket({
    required this.start,
    required this.end,
    required this.label,
    required this.due,
    required this.collected,
    required this.isCurrent,
  });

  /// First day (a Monday for weeks, the 1st for months).
  final CivilDate start;

  /// Last day, inclusive.
  final CivilDate end;

  /// "6 Nov" (week start) or "Nov" (month).
  final String label;
  final Money due;
  final Money collected;

  /// The bucket containing today (partial).
  final bool isCurrent;
}

/// An amount with its share of the sanctioned receivable.
final class ReceivableShare {
  const ReceivableShare({required this.amount, required this.bps});

  final Money amount;

  /// Basis points of `sanctionedReceivable` (0 when that is zero).
  final int bps;
}

/// Receivable breakdown card (separate labelled rows, never stacked).
final class ReceivableBreakdown {
  const ReceivableBreakdown({
    required this.collectedThisMonth,
    required this.upcoming30,
    required this.overdue,
  });

  final ReceivableShare collectedThisMonth;
  final ReceivableShare upcoming30;
  final ReceivableShare overdue;
}

/// One day of the month calendar.
final class CalendarDay {
  const CalendarDay({
    required this.date,
    required this.collected,
    required this.collectedCount,
    required this.scheduled,
    required this.scheduledCount,
    required this.overdue,
    required this.overdueCount,
  });

  final CivilDate date;

  /// Net payments − reversals with paidOn on this day; count of payments.
  final Money collected;
  final int collectedCount;

  /// Σ effective due of rows due this day (extensions included).
  final Money scheduled;
  final int scheduledCount;

  /// Σ unpaid amount of rows due this day that are overdue.
  final Money overdue;
  final int overdueCount;
}

/// One overdue row in the overdue tracker.
final class OverdueItem {
  const OverdueItem({
    required this.contractId,
    required this.borrowerName,
    required this.loanNo,
    required this.seq,
    required this.dueDate,
    required this.amount,
    required this.daysOverdue,
  });

  final String contractId;
  final String borrowerName;
  final int loanNo;
  final int seq;
  final CivilDate dueDate;

  /// Unpaid part of the row.
  final Money amount;
  final int daysOverdue;

  OverdueSeverity get severity => daysOverdue > criticalOverdueDays
      ? OverdueSeverity.critical
      : OverdueSeverity.recent;
}

/// Dashboard, chart, calendar and overdue-tracker figures for the active
/// company. Pure: [collectionsSeries] and [calendarBuckets] are computed
/// from the inputs on each call (memoise in the provider layer).
final class PortfolioMetrics {
  PortfolioMetrics._({
    required this.today,
    required List<ContractProjection> projections,
    required List<LedgerTransaction> transactions,
    required Map<String, TxType> typeById,
    required this.totalNetDisbursed,
    required this.sanctionedReceivable,
    required this.totalCollected,
    required this.totalWaived,
    required this.totalOverdue,
    required this.overdueInstallmentCount,
    required this.maxDaysOverdue,
    required this.todayDue,
    required this.receivableBreakdown,
    required this.overdueList,
  }) : _projections = projections,
       _transactions = transactions,
       _typeById = typeById;

  final CivilDate today;
  final List<ContractProjection> _projections;
  final List<LedgerTransaction> _transactions;
  final Map<String, TxType> _typeById;

  /// Σ netDisbursed of every contract in `contractsById` (active and
  /// closed / rolled over).
  final Money totalNetDisbursed;

  /// Σ outstanding of active contracts.
  final Money sanctionedReceivable;

  /// Cash collected: Σ payment − Σ reversal of payments in the window.
  /// rolloverSettlement and waiver are excluded (no cash moves), and so are
  /// reversals of them.
  final Money totalCollected;

  /// Early-closure waivers in the window: Σ waiver − Σ reversal of a known
  /// waiver. Not cash; not displayed yet.
  final Money totalWaived;

  /// Σ shortfall S of active contracts.
  final Money totalOverdue;
  final int overdueInstallmentCount;
  final int maxDaysOverdue;
  final TodayDue todayDue;
  final ReceivableBreakdown receivableBreakdown;

  /// Sorted by daysOverdue desc, then loanNo, then seq.
  final List<OverdueItem> overdueList;

  /// Collections chart buckets, oldest first; the last one is current.
  List<CollectionBucket> collectionsSeries(ChartPeriod period) {
    final starts = <CivilDate>[];
    final ends = <CivilDate>[];
    final labels = <String>[];
    final bool weekly = period == ChartPeriod.weeks8;
    final int count = switch (period) {
      ChartPeriod.weeks8 => 8,
      ChartPeriod.months6 => 6,
      ChartPeriod.months12 => 12,
    };
    final CivilDate first;
    if (weekly) {
      first = mondayOf(today).addDays(-7 * (count - 1));
      for (var i = 0; i < count; i++) {
        final s = first.addDays(7 * i);
        starts.add(s);
        ends.add(s.addDays(6));
        labels.add(formatCivilDateDayMonth(s));
      }
    } else {
      first = CivilDate(
        today.year,
        today.month,
        1,
      ).addMonthsClamped(-(count - 1), preferredDay: 1);
      for (var i = 0; i < count; i++) {
        final s = first.addMonthsClamped(i, preferredDay: 1);
        starts.add(s);
        ends.add(
          CivilDate(s.year, s.month, CivilDate.daysInMonth(s.year, s.month)),
        );
        labels.add(civilMonthShortName(s.month));
      }
    }

    int indexOf(CivilDate d) {
      final int i = weekly
          ? _floorDiv(first.daysBetween(d), 7)
          : _monthIndex(d) - _monthIndex(first);
      return i >= 0 && i < count ? i : -1;
    }

    final due = List<int>.filled(count, 0);
    final collected = List<int>.filled(count, 0);
    for (final p in _projections) {
      for (final row in p.rows) {
        if (row.isRescheduledAway) continue;
        final i = indexOf(row.dueDate);
        if (i >= 0) due[i] += row.due.paise;
      }
    }
    for (final tx in _transactions) {
      final cash = _cashDelta(tx, _typeById);
      if (cash == 0) continue;
      final i = indexOf(tx.paidOn);
      if (i >= 0) collected[i] += cash;
    }

    return List<CollectionBucket>.generate(
      count,
      (int i) => CollectionBucket(
        start: starts[i],
        end: ends[i],
        label: labels[i],
        due: Money(due[i]),
        collected: Money(collected[i]),
        isCurrent: i == count - 1,
      ),
      growable: false,
    );
  }

  /// One [CalendarDay] per day of [year]-[month].
  List<CalendarDay> calendarBuckets(int year, int month) {
    final days = CivilDate.daysInMonth(year, month);
    final collected = List<int>.filled(days, 0);
    final collectedCount = List<int>.filled(days, 0);
    final scheduled = List<int>.filled(days, 0);
    final scheduledCount = List<int>.filled(days, 0);
    final overdue = List<int>.filled(days, 0);
    final overdueCount = List<int>.filled(days, 0);

    for (final p in _projections) {
      for (final row in p.rows) {
        final d = row.dueDate;
        if (d.year != year || d.month != month || row.isRescheduledAway) {
          continue;
        }
        final i = d.day - 1;
        scheduled[i] += row.due.paise;
        scheduledCount[i]++;
        if (row.status == RowStatus.overdue) {
          overdue[i] += row.remaining.paise;
          overdueCount[i]++;
        }
      }
    }
    for (final tx in _transactions) {
      final d = tx.paidOn;
      if (d.year != year || d.month != month) continue;
      final cash = _cashDelta(tx, _typeById);
      if (cash == 0) continue;
      collected[d.day - 1] += cash;
      if (tx.type == TxType.payment) collectedCount[d.day - 1]++;
    }

    return List<CalendarDay>.generate(
      days,
      (int i) => CalendarDay(
        date: CivilDate(year, month, i + 1),
        collected: Money(collected[i]),
        collectedCount: collectedCount[i],
        scheduled: Money(scheduled[i]),
        scheduledCount: scheduledCount[i],
        overdue: Money(overdue[i]),
        overdueCount: overdueCount[i],
      ),
      growable: false,
    );
  }
}

/// Folds per-contract projections into the portfolio figures.
///
/// - [projections]: active contracts (non-active ones are skipped for the
///   receivable, overdue, today and chart-due figures).
/// - [allTransactions]: the transactions window, all contracts; drives
///   totalCollected, received-today and the collected series.
/// - [contractsById]: every loaded contract (active and closed); drives
///   totalNetDisbursed and borrower names.
PortfolioMetrics computePortfolio({
  required List<ContractProjection> projections,
  required List<LedgerTransaction> allTransactions,
  required CivilDate today,
  required Map<String, Contract> contractsById,
}) {
  final active = projections
      .where((ContractProjection p) => p.contract.isActive)
      .toList(growable: false);

  final typeById = <String, TxType>{
    for (final tx in allTransactions) tx.id: tx.type,
  };

  var netDisbursed = 0;
  for (final c in contractsById.values) {
    netDisbursed += c.netDisbursed.paise;
  }

  var collected = 0;
  var receivedToday = 0;
  var collectedThisMonth = 0;
  var waived = 0;
  for (final tx in allTransactions) {
    if (tx.type == TxType.waiver) waived += tx.amount.paise;
    if (tx.type == TxType.reversal &&
        typeById[tx.reversesTxId] == TxType.waiver) {
      waived -= tx.amount.paise;
    }
    final cash = _cashDelta(tx, typeById);
    if (cash == 0) continue;
    collected += cash;
    if (tx.paidOn == today) receivedToday += cash;
    if (tx.paidOn.year == today.year && tx.paidOn.month == today.month) {
      collectedThisMonth += cash;
    }
  }

  var receivable = 0;
  var overdue = 0;
  var overdueCount = 0;
  var maxDays = 0;
  var todayAmount = 0;
  var upcoming30 = 0;
  final todayItems = <TodayDueItem>[];
  final overdueItems = <OverdueItem>[];

  for (final p in active) {
    final contract = contractsById[p.contract.id] ?? p.contract;
    receivable += p.outstanding.paise;
    overdue += p.overdueAmount.paise;
    overdueCount += p.overdueCount;
    if (p.maxDaysOverdue > maxDays) maxDays = p.maxDaysOverdue;

    for (final row in p.rows) {
      if (row.isRescheduledAway) continue;
      if (row.dueDate == today) {
        todayAmount += row.due.paise;
        todayItems.add(
          TodayDueItem(
            contractId: contract.id,
            borrowerName: contract.borrowerName,
            loanNo: contract.loanNo,
            seq: row.seq,
            amount: row.due,
            paid: row.paid,
            isExtension: row.isExtension,
          ),
        );
      }
      if (row.status == RowStatus.overdue) {
        overdueItems.add(
          OverdueItem(
            contractId: contract.id,
            borrowerName: contract.borrowerName,
            loanNo: contract.loanNo,
            seq: row.seq,
            dueDate: row.dueDate,
            amount: row.remaining,
            daysOverdue: row.daysOverdue,
          ),
        );
      } else if (row.isOpen) {
        final ahead = today.daysBetween(row.dueDate);
        if (ahead >= 0 && ahead <= 30) upcoming30 += row.remaining.paise;
      }
    }
  }

  overdueItems.sort((OverdueItem a, OverdueItem b) {
    final byDays = b.daysOverdue.compareTo(a.daysOverdue);
    if (byDays != 0) return byDays;
    final byLoan = a.loanNo.compareTo(b.loanNo);
    if (byLoan != 0) return byLoan;
    final byContract = a.contractId.compareTo(b.contractId);
    return byContract != 0 ? byContract : a.seq.compareTo(b.seq);
  });
  todayItems.sort((TodayDueItem a, TodayDueItem b) {
    final byLoan = a.loanNo.compareTo(b.loanNo);
    if (byLoan != 0) return byLoan;
    final byContract = a.contractId.compareTo(b.contractId);
    return byContract != 0 ? byContract : a.seq.compareTo(b.seq);
  });

  final receivableMoney = Money(receivable);
  ReceivableShare share(int paise) => ReceivableShare(
    amount: Money(paise),
    bps: Money(paise).percentOf(receivableMoney),
  );

  return PortfolioMetrics._(
    today: today,
    projections: active,
    transactions: allTransactions,
    typeById: typeById,
    totalNetDisbursed: Money(netDisbursed),
    sanctionedReceivable: receivableMoney,
    totalCollected: Money(collected),
    totalWaived: Money(waived > 0 ? waived : 0),
    totalOverdue: Money(overdue),
    overdueInstallmentCount: overdueCount,
    maxDaysOverdue: maxDays,
    todayDue: TodayDue(
      amountDue: Money(todayAmount),
      received: Money(receivedToday),
      items: List<TodayDueItem>.unmodifiable(todayItems),
    ),
    receivableBreakdown: ReceivableBreakdown(
      collectedThisMonth: share(collectedThisMonth),
      upcoming30: share(upcoming30),
      overdue: share(overdue),
    ),
    overdueList: List<OverdueItem>.unmodifiable(overdueItems),
  );
}

/// The Monday on or before [date].
CivilDate mondayOf(CivilDate date) => date.addDays(1 - date.weekday);

/// Cash effect of [tx]: +payment, −reversal of a payment; 0 otherwise.
/// A reversal whose original is not in the window is assumed to reverse a
/// payment when it carries a mode (a waiver reversal has none); a reversal of a known non-payment (a rolloverSettlement or a
/// waiver) moves no cash. Waivers themselves are never cash.
int _cashDelta(LedgerTransaction tx, Map<String, TxType> typeById) {
  switch (tx.type) {
    case TxType.payment:
      return tx.amount.paise;
    case TxType.reversal:
      final original = tx.reversesTxId == null
          ? null
          : typeById[tx.reversesTxId];
      if (original != null && original != TxType.payment) return 0;
      // Unknown original with no mode: a waiver reversal (payments always
      // carry a mode and reversals copy it; waivers never do). Not cash.
      if (original == null && tx.mode == null) return 0;
      return -tx.amount.paise;
    case TxType.disbursement:
    case TxType.rolloverSettlement:
    case TxType.reschedule:
    case TxType.waiver:
      return 0;
  }
}

int _monthIndex(CivilDate d) => d.year * 12 + d.month - 1;

int _floorDiv(int a, int b) => (a - (a % b)) ~/ b;
