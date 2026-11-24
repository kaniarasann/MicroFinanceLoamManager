import '../../core/money/money.dart';
import '../../core/time/civil_date.dart';
import '../models/enums.dart';
import 'portfolio_metrics.dart';

/// Overdue tracker filter chips: All / Critical (> 3 days) / Recent (1–3).
enum OverdueFilter { all, critical, recent }

/// One overdue loan in the tracker: every overdue row of a contract folded
/// into one card.
final class OverdueLoan {
  const OverdueLoan({
    required this.contractId,
    required this.borrowerId,
    required this.borrowerName,
    required this.borrowerPhoneE164,
    required this.loanNo,
    required this.frequency,
    required this.amount,
    required this.daysOverdue,
    required this.oldestDueDate,
    required this.installmentCount,
  });

  final String contractId;
  final String borrowerId;
  final String borrowerName;
  final String borrowerPhoneE164;
  final int loanNo;
  final Frequency frequency;

  /// Σ unpaid amount of the contract's overdue rows.
  final Money amount;

  /// The highest delay among its rows (the oldest row's days).
  final int daysOverdue;
  final CivilDate oldestDueDate;

  /// How many overdue rows the loan has.
  final int installmentCount;

  OverdueSeverity get severity => severityFor(daysOverdue);
}

/// Groups [items] by contract. Sorted by daysOverdue desc, then loanNo and
/// contractId.
List<OverdueLoan> groupOverdueByLoan(Iterable<OverdueItem> items) {
  final byContract = <String, List<OverdueItem>>{};
  for (final i in items) {
    (byContract[i.contractId] ??= <OverdueItem>[]).add(i);
  }
  final loans = <OverdueLoan>[
    for (final rows in byContract.values) _fold(rows),
  ];
  loans.sort((OverdueLoan a, OverdueLoan b) {
    final byDays = b.daysOverdue.compareTo(a.daysOverdue);
    if (byDays != 0) return byDays;
    final byLoan = a.loanNo.compareTo(b.loanNo);
    return byLoan != 0 ? byLoan : a.contractId.compareTo(b.contractId);
  });
  return List<OverdueLoan>.unmodifiable(loans);
}

OverdueLoan _fold(List<OverdueItem> rows) {
  final first = rows.first;
  var amount = 0;
  var days = 0;
  var oldest = first.dueDate;
  for (final r in rows) {
    amount += r.amount.paise;
    if (r.daysOverdue > days) days = r.daysOverdue;
    if (r.dueDate.isBefore(oldest)) oldest = r.dueDate;
  }
  return OverdueLoan(
    contractId: first.contractId,
    borrowerId: first.borrowerId,
    borrowerName: first.borrowerName,
    borrowerPhoneE164: first.borrowerPhoneE164,
    loanNo: first.loanNo,
    frequency: first.frequency,
    amount: Money(amount),
    daysOverdue: days,
    oldestDueDate: oldest,
    installmentCount: rows.length,
  );
}

/// Whether [loan] passes [filter].
bool matchesOverdueFilter(OverdueLoan loan, OverdueFilter filter) =>
    switch (filter) {
      OverdueFilter.all => true,
      OverdueFilter.critical => loan.severity == OverdueSeverity.critical,
      OverdueFilter.recent => loan.severity == OverdueSeverity.recent,
    };

/// The tracker's figures for one filter.
final class OverdueSummary {
  const OverdueSummary({
    required this.loans,
    required this.total,
    required this.maxDaysOverdue,
    required this.criticalCount,
    required this.recentCount,
    required this.allCount,
  });

  /// Builds the summary of [all] (grouped loans) for [filter]. The chip
  /// counts always cover every loan.
  factory OverdueSummary.of(List<OverdueLoan> all, OverdueFilter filter) {
    var critical = 0;
    for (final l in all) {
      if (l.severity == OverdueSeverity.critical) critical++;
    }
    final shown = <OverdueLoan>[
      for (final l in all)
        if (matchesOverdueFilter(l, filter)) l,
    ];
    var total = 0;
    var maxDays = 0;
    for (final l in shown) {
      total += l.amount.paise;
      if (l.daysOverdue > maxDays) maxDays = l.daysOverdue;
    }
    return OverdueSummary(
      loans: List<OverdueLoan>.unmodifiable(shown),
      total: Money(total),
      maxDaysOverdue: maxDays,
      criticalCount: critical,
      recentCount: all.length - critical,
      allCount: all.length,
    );
  }

  /// Loans that pass the filter, in tracker order.
  final List<OverdueLoan> loans;

  /// Σ overdue of [loans].
  final Money total;
  final int maxDaysOverdue;
  final int criticalCount;
  final int recentCount;
  final int allCount;
}
