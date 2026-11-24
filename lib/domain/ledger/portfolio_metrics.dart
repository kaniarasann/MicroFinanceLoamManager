import '../../core/money/money.dart';
import '../../core/time/civil_date.dart';
import '../models/contract.dart';
import '../models/enums.dart';
import '../models/installment.dart';
import '../models/ledger_transaction.dart';
import 'contract_projection.dart';

/// Window of the collections chart.
enum ChartPeriod { weeks8, months6, months12 }

/// Overdue tracker severity: critical (> 3 days) or recent (1–3 days).
enum OverdueSeverity { critical, recent }

/// Days overdue above which an item is [OverdueSeverity.critical].
const int criticalOverdueDays = 3;

/// Months of history (including the current one) the dashboard loads for
/// inactive contracts' transactions: the 12-month chart window.
const int historyWindowMonths = 12;

/// First day of the history window that covers every chart period and the
/// calendar's back-navigation: the 1st of the month 11 months before
/// [today]'s month.
CivilDate chartWindowStart(CivilDate today) => CivilDate(
  today.year,
  today.month,
  1,
).addMonthsClamped(-(historyWindowMonths - 1), preferredDay: 1);

/// One open or settled schedule row of an active contract, with the
/// borrower details the dashboard, calendar and contact actions need.
final class DueRowItem {
  const DueRowItem({
    required this.contractId,
    required this.borrowerId,
    required this.borrowerName,
    required this.borrowerPhoneE164,
    required this.loanNo,
    required this.frequency,
    required this.seq,
    required this.dueDate,
    required this.amount,
    required this.paid,
    required this.status,
    required this.daysOverdue,
    required this.isExtension,
    required this.cyclesTotal,
    this.sourceLabel,
    this.contractStatus = ContractStatus.active,
  });

  final String contractId;
  final String borrowerId;
  final String borrowerName;
  final String borrowerPhoneE164;
  final int loanNo;
  final Frequency frequency;
  final int seq;
  final CivilDate dueDate;

  /// The row's effective due.
  final Money amount;

  /// FIFO-allocated paid amount on that row.
  final Money paid;
  final RowStatus status;
  final int daysOverdue;
  final bool isExtension;

  /// The contract's cycle count (extensions included), for "8/30".
  final int cyclesTotal;

  /// Extension rows: which shortfall they re-plan ("missed on 31 Oct
  /// (Inst. 2)"); null otherwise.
  final String? sourceLabel;

  /// The loan's status. Rows of closed / rolled-over loans (history) are
  /// always settled and never take a payment.
  final ContractStatus contractStatus;

  bool get isHistory => contractStatus != ContractStatus.active;

  bool get isPaid => paid >= amount;

  /// Unpaid part of the row (never negative).
  Money get remaining => isPaid ? Money.zero : amount - paid;
}

/// One row due today, on any contract.
typedef TodayDueItem = DueRowItem;

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

  /// Rows due today that are fully paid / still open.
  int get collectedCount => items.where((TodayDueItem i) => i.isPaid).length;
  int get pendingCount => items.length - collectedCount;

  /// received as bps of amountDue, capped at 100% (0 when nothing is due).
  int get progressBps {
    final bps = received.percentOf(amountDue);
    if (bps < 0) return 0;
    return bps > 10000 ? 10000 : bps;
  }
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

  /// collected as bps of due (0 when nothing was due).
  int get rateBps => collected.percentOf(due);
}

/// Totals of a collections series (the chart's summary line).
final class SeriesTotals {
  const SeriesTotals({required this.due, required this.collected});

  factory SeriesTotals.of(Iterable<CollectionBucket> buckets) {
    var due = 0;
    var collected = 0;
    for (final b in buckets) {
      due += b.due.paise;
      collected += b.collected.paise;
    }
    return SeriesTotals(due: Money(due), collected: Money(collected));
  }

  final Money due;
  final Money collected;

  /// collected as bps of due (0 when nothing was due).
  int get rateBps => collected.percentOf(due);

  /// The largest of any bucket's due or collected (the chart's y range).
  static Money peak(Iterable<CollectionBucket> buckets) {
    var max = 0;
    for (final b in buckets) {
      if (b.due.paise > max) max = b.due.paise;
      if (b.collected.paise > max) max = b.collected.paise;
    }
    return Money(max);
  }
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
    this.settled = Money.zero,
    this.settledCount = 0,
    this.pending = Money.zero,
    this.pendingCount = 0,
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

  /// Σ FIFO-paid amount of rows due this day; count of fully paid rows.
  final Money settled;
  final int settledCount;

  /// Σ unpaid amount of open base / rescheduled rows due this day that are
  /// not overdue (due today, upcoming, planned). Open extension rows add to
  /// [pendingCount] (the amber dot) but not to the amount: they re-plan
  /// money already counted as overdue.
  final Money pending;
  final int pendingCount;

  /// Status dots: sage (something paid), amber (open, not late),
  /// terracotta (overdue).
  bool get hasCollectedDot => settled.isPositive;
  bool get hasPendingDot => pendingCount > 0;
  bool get hasOverdueDot => overdueCount > 0;
}

/// Month legend totals of the calendar (row based, like the dots).
final class CalendarTotals {
  const CalendarTotals({
    required this.settled,
    required this.pending,
    required this.overdue,
  });

  factory CalendarTotals.of(Iterable<CalendarDay> days) {
    var settled = 0;
    var pending = 0;
    var overdue = 0;
    for (final d in days) {
      settled += d.settled.paise;
      pending += d.pending.paise;
      overdue += d.overdue.paise;
    }
    return CalendarTotals(
      settled: Money(settled),
      pending: Money(pending),
      overdue: Money(overdue),
    );
  }

  final Money settled;
  final Money pending;
  final Money overdue;
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
    this.borrowerId = '',
    this.borrowerPhoneE164 = '',
    this.frequency = Frequency.weekly,
  });

  final String contractId;
  final String borrowerId;
  final String borrowerName;
  final String borrowerPhoneE164;
  final int loanNo;
  final Frequency frequency;
  final int seq;
  final CivilDate dueDate;

  /// Unpaid part of the row.
  final Money amount;
  final int daysOverdue;

  OverdueSeverity get severity => severityFor(daysOverdue);
}

/// [OverdueSeverity.critical] above [criticalOverdueDays], else recent.
OverdueSeverity severityFor(int daysOverdue) =>
    daysOverdue > criticalOverdueDays
    ? OverdueSeverity.critical
    : OverdueSeverity.recent;

/// A contract whose paid pool exceeds its sanctioned amount (a duplicate
/// offline collection, or a payment that landed after a rollover).
final class ExcessItem {
  const ExcessItem({
    required this.contractId,
    required this.borrowerName,
    required this.loanNo,
    required this.status,
    required this.excess,
  });

  final String contractId;
  final String borrowerName;
  final int loanNo;
  final ContractStatus status;
  final Money excess;
}

/// Dashboard, chart, calendar and overdue-tracker figures for the active
/// company. Pure: [collectionsSeries], [calendarBuckets] and
/// [dueItemsBetween] are computed from the inputs on each call (memoise in
/// the provider layer).
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
    required this.excessToReview,
    required List<DueRowItem> historyRows,
  }) : _projections = projections,
       _transactions = transactions,
       _typeById = typeById,
       _historyRows = historyRows;

  final CivilDate today;
  final List<ContractProjection> _projections;
  final List<LedgerTransaction> _transactions;
  final Map<String, TxType> _typeById;

  /// Settled rows of history contracts inside the loaded window.
  final List<DueRowItem> _historyRows;

  /// Σ netDisbursed of every contract in `contractsById` (active and
  /// closed / rolled over) plus `historyContracts`.
  final Money totalNetDisbursed;

  /// Σ outstanding of active contracts.
  final Money sanctionedReceivable;

  /// Cash collected: Σ payment − Σ reversal of payments in the window, plus
  /// the cached cash of `historyContracts` (whose transactions are then
  /// not counted again). rolloverSettlement and waiver are excluded (no
  /// cash moves), and so are reversals of them.
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

  /// Contracts holding excess (largest first): active projections with
  /// excess and history contracts whose cached paid pool exceeds the
  /// sanctioned amount.
  final List<ExcessItem> excessToReview;

  /// Number of active contracts.
  int get activeContractCount => _projections.length;

  /// totalOverdue as bps of sanctionedReceivable (the tracker's risk card).
  int get overdueRiskBps => totalOverdue.percentOf(sanctionedReceivable);

  /// Distinct active contracts with an overdue row.
  int get overdueLoanCount =>
      overdueList.map((OverdueItem i) => i.contractId).toSet().length;

  /// Schedule rows of active contracts due in [from]..[to] (inclusive),
  /// excluding rows rescheduled away. Sorted by date, then open rows before
  /// paid ones, then loanNo, contractId and seq.
  List<DueRowItem> dueItemsBetween(CivilDate from, CivilDate to) {
    final out = <DueRowItem>[];
    for (final p in _projections) {
      for (final row in p.rows) {
        if (row.isRescheduledAway) continue;
        if (row.dueDate.isBefore(from) || row.dueDate.isAfter(to)) continue;
        out.add(_item(p, row));
      }
    }
    for (final h in _historyRows) {
      if (h.dueDate.isBefore(from) || h.dueDate.isAfter(to)) continue;
      out.add(h);
    }
    out.sort((DueRowItem a, DueRowItem b) {
      final byDate = a.dueDate.compareTo(b.dueDate);
      if (byDate != 0) return byDate;
      if (a.isPaid != b.isPaid) return a.isPaid ? 1 : -1;
      return _compareRowIds(a, b);
    });
    return List<DueRowItem>.unmodifiable(out);
  }

  /// Rows due on [date] (see [dueItemsBetween]).
  List<DueRowItem> dayItems(CivilDate date) => dueItemsBetween(date, date);

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
    for (final h in _historyRows) {
      final i = indexOf(h.dueDate);
      if (i >= 0) due[i] += h.amount.paise;
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
    final settled = List<int>.filled(days, 0);
    final settledCount = List<int>.filled(days, 0);
    final pending = List<int>.filled(days, 0);
    final pendingCount = List<int>.filled(days, 0);

    for (final p in _projections) {
      for (final row in p.rows) {
        final d = row.dueDate;
        if (d.year != year || d.month != month || row.isRescheduledAway) {
          continue;
        }
        final i = d.day - 1;
        scheduled[i] += row.due.paise;
        scheduledCount[i]++;
        settled[i] += row.paid.paise;
        if (!row.isOpen) {
          settledCount[i]++;
        } else if (row.status == RowStatus.overdue) {
          overdue[i] += row.remaining.paise;
          overdueCount[i]++;
        } else {
          if (!row.isExtension) pending[i] += row.remaining.paise;
          pendingCount[i]++;
        }
      }
    }
    for (final h in _historyRows) {
      final d = h.dueDate;
      if (d.year != year || d.month != month) continue;
      final i = d.day - 1;
      scheduled[i] += h.amount.paise;
      scheduledCount[i]++;
      settled[i] += h.amount.paise;
      settledCount[i]++;
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
        settled: Money(settled[i]),
        settledCount: settledCount[i],
        pending: Money(pending[i]),
        pendingCount: pendingCount[i],
      ),
      growable: false,
    );
  }
}

DueRowItem _item(ContractProjection p, ProjectedRow row) {
  final c = p.contract;
  return DueRowItem(
    contractId: c.id,
    borrowerId: c.borrowerId,
    borrowerName: c.borrowerName,
    borrowerPhoneE164: c.borrowerPhoneE164,
    loanNo: c.loanNo,
    frequency: c.frequency,
    seq: row.seq,
    dueDate: row.dueDate,
    amount: row.due,
    paid: row.paid,
    status: row.status,
    daysOverdue: row.daysOverdue,
    isExtension: row.isExtension,
    cyclesTotal: p.cyclesTotal,
    sourceLabel: row.sourceLabel,
  );
}

/// Settled rows of history contracts: effective due
/// (`amountDue − rescheduledOut`) > 0, fully paid. A closed loan was paid
/// (or waived) to zero; a rolled-over loan's unpaid rows were settled by
/// the rollover.
List<DueRowItem> _historyItems(
  Map<String, Contract> history,
  Iterable<Installment> installments,
) {
  final byContract = <String, Map<String, Installment>>{};
  for (final i in installments) {
    if (!history.containsKey(i.contractId)) continue;
    (byContract[i.contractId] ??= <String, Installment>{})[i.id] = i;
  }
  final out = <DueRowItem>[];
  byContract.forEach((String cid, Map<String, Installment> rows) {
    final c = history[cid]!;
    final live = <Installment>[
      for (final i in rows.values)
        if (i.amountDue.paise - i.rescheduledOut.paise > 0) i,
    ];
    for (final i in live) {
      final due = Money(i.amountDue.paise - i.rescheduledOut.paise);
      out.add(
        DueRowItem(
          contractId: c.id,
          borrowerId: c.borrowerId,
          borrowerName: c.borrowerName,
          borrowerPhoneE164: c.borrowerPhoneE164,
          loanNo: c.loanNo,
          frequency: c.frequency,
          seq: i.seq,
          dueDate: i.dueDate,
          amount: due,
          paid: due,
          status: RowStatus.paid,
          daysOverdue: 0,
          isExtension: false,
          cyclesTotal: live.length,
          contractStatus: c.status,
        ),
      );
    }
  });
  return out;
}

int _compareRowIds(DueRowItem a, DueRowItem b) {
  final byLoan = a.loanNo.compareTo(b.loanNo);
  if (byLoan != 0) return byLoan;
  final byContract = a.contractId.compareTo(b.contractId);
  return byContract != 0 ? byContract : a.seq.compareTo(b.seq);
}

/// Folds per-contract projections into the portfolio figures.
///
/// - [projections]: active contracts (non-active ones are skipped for the
///   receivable, overdue, today and chart-due figures).
/// - [allTransactions]: the transactions window, all contracts; drives
///   totalCollected, received-today and the collected series.
/// - [contractsById]: every loaded contract (active and closed); drives
///   totalNetDisbursed and borrower names.
/// - [historyInstallments]: installments of [historyContracts] inside the
///   loaded window. Rows of contracts that are not in [historyContracts]
///   (or that are active) are ignored, and ids are deduped. They add their
///   effective due to the chart's due series and appear on the calendar
///   (dots, day lists, legend) as settled rows.
/// - [historyContracts]: closed / rolled-over contracts loaded for the
///   dashboard. They add to totalNetDisbursed (unless already in
///   [contractsById]) and contribute their cached cash
///   (`totalPaid − rolloverSettled`) to totalCollected; their transactions
///   in [allTransactions] still drive the dated figures (chart, calendar,
///   today, this month) but are not counted in totalCollected again. Any
///   id that is also an active projection is ignored. They also feed
///   [PortfolioMetrics.excessToReview].
PortfolioMetrics computePortfolio({
  required List<ContractProjection> projections,
  required List<LedgerTransaction> allTransactions,
  required CivilDate today,
  required Map<String, Contract> contractsById,
  Iterable<Contract> historyContracts = const <Contract>[],
  Iterable<Installment> historyInstallments = const <Installment>[],
}) {
  final active = projections
      .where((ContractProjection p) => p.contract.isActive)
      .toList(growable: false);
  final activeIds = <String>{for (final p in active) p.contract.id};
  final history = <String, Contract>{
    for (final c in historyContracts)
      if (!activeIds.contains(c.id)) c.id: c,
  };

  final typeById = <String, TxType>{
    for (final tx in allTransactions) tx.id: tx.type,
  };

  var netDisbursed = 0;
  for (final c in contractsById.values) {
    netDisbursed += c.netDisbursed.paise;
  }

  var collected = 0;
  for (final c in history.values) {
    if (!contractsById.containsKey(c.id)) netDisbursed += c.netDisbursed.paise;
    collected += c.totalPaid.paise - (c.rolloverSettled?.paise ?? 0);
  }

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
    if (!history.containsKey(tx.contractId)) collected += cash;
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
  final excess = <ExcessItem>[];

  for (final p in active) {
    final contract = contractsById[p.contract.id] ?? p.contract;
    receivable += p.outstanding.paise;
    overdue += p.overdueAmount.paise;
    overdueCount += p.overdueCount;
    if (p.maxDaysOverdue > maxDays) maxDays = p.maxDaysOverdue;
    if (p.hasExcess) {
      excess.add(
        ExcessItem(
          contractId: contract.id,
          borrowerName: contract.borrowerName,
          loanNo: contract.loanNo,
          status: contract.status,
          excess: p.excess,
        ),
      );
    }

    for (final row in p.rows) {
      if (row.isRescheduledAway) continue;
      if (row.dueDate == today) {
        todayAmount += row.due.paise;
        todayItems.add(_item(p, row));
      }
      if (row.status == RowStatus.overdue) {
        overdueItems.add(
          OverdueItem(
            contractId: contract.id,
            borrowerId: contract.borrowerId,
            borrowerName: contract.borrowerName,
            borrowerPhoneE164: contract.borrowerPhoneE164,
            loanNo: contract.loanNo,
            frequency: contract.frequency,
            seq: row.seq,
            dueDate: row.dueDate,
            amount: row.remaining,
            daysOverdue: row.daysOverdue,
          ),
        );
      } else if (row.isOpen && !row.isExtension) {
        // Extension rows re-plan overdue money: counting them here would
        // count the same rupees twice (overdue + upcoming).
        final ahead = today.daysBetween(row.dueDate);
        if (ahead >= 0 && ahead <= 30) upcoming30 += row.remaining.paise;
      }
    }
  }

  for (final c in history.values) {
    final pool = c.totalPaid.paise + c.totalWaived.paise;
    final extra = pool - c.sanctioned.paise;
    if (extra > 0) {
      excess.add(
        ExcessItem(
          contractId: c.id,
          borrowerName: c.borrowerName,
          loanNo: c.loanNo,
          status: c.status,
          excess: Money(extra),
        ),
      );
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
  todayItems.sort(_compareRowIds);
  excess.sort((ExcessItem a, ExcessItem b) {
    final byAmount = b.excess.compareTo(a.excess);
    if (byAmount != 0) return byAmount;
    final byLoan = a.loanNo.compareTo(b.loanNo);
    return byLoan != 0 ? byLoan : a.contractId.compareTo(b.contractId);
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
    excessToReview: List<ExcessItem>.unmodifiable(excess),
    historyRows: _historyItems(history, historyInstallments),
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
