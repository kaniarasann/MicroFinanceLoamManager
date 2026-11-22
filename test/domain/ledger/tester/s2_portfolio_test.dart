// Tester (Sprint 2): portfolio KPIs hand-computed on a small fixture.
// Today = Wed 8 Nov 2023.
//  c1 active 1L/10k weekly Tue from 31 Oct, flat 7k (net 93k); paid 6k 31 Oct
//     -> Inst1 4k overdue 8 days, Inst2 10k overdue 1 day, outstanding 94k
//  c2 active 50k/5k daily from 8 Nov, flat 2.5k (net 47.5k); paid 5k today
//     -> outstanding 45k, today due 5k received 5k
//  c3 closed 20k, flat 1k (net 19k); paid 20k on 1 Nov
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import '../ledger_fixtures.dart';

void main() {
  final today = d(2023, 11, 8);
  final c1 = makeContract();
  final c2 = makeContract(
    id: 'c2',
    loanNo: 2,
    sanctioned: rs(50000),
    installment: rs(5000),
    frequency: Frequency.daily,
    weekday: null,
    firstDue: d(2023, 11, 8),
    upfrontInput: 250000,
  );
  final c3 = makeContract(
    id: 'c3',
    loanNo: 3,
    sanctioned: rs(20000),
    installment: rs(20000),
    firstDue: d(2023, 10, 31),
    status: ContractStatus.closed,
    upfrontInput: 100000,
  );
  final txs = [
    tx('c1', rs(6000), d(2023, 10, 31)),
    tx('c2', rs(5000), today),
    tx('c3', rs(20000), d(2023, 11, 1)),
  ];
  PortfolioMetrics build() => computePortfolio(
    projections: [
      for (final c in [c1, c2, c3]) project(c, txs, today),
    ],
    allTransactions: txs,
    today: today,
    contractsById: {
      for (final c in [c1, c2, c3]) c.id: c,
    },
  );

  test('four KPIs match hand calculation', () {
    final m = build();
    expect(m.totalNetDisbursed, rs(93000 + 47500 + 19000));
    expect(m.sanctionedReceivable, rs(94000 + 45000));
    expect(m.totalCollected, rs(31000));
    expect(m.totalOverdue, rs(14000));
    expect(m.overdueInstallmentCount, 2);
    expect(m.maxDaysOverdue, 8);
  });

  test('receivable never includes extension rows (sanctioned - paid)', () {
    final p1 = project(c1, txs, today);
    expect(p1.rows.where((r) => r.isExtension), isNotEmpty);
    expect(p1.outstanding, c1.sanctioned - rs(6000));
  });

  test("today's due: 5k due, 5k received", () {
    final t = build().todayDue;
    expect(t.amountDue, rs(5000));
    expect(t.received, rs(5000));
    expect(t.items.map((i) => i.contractId), ['c2']);
  });

  test('overdue list sorted by days desc with severity', () {
    final l = build().overdueList;
    expect(l.map((o) => o.daysOverdue).toList(), [8, 1]);
    expect(l[0].amount, rs(4000));
    expect(l[0].severity, OverdueSeverity.critical);
    expect(l[1].severity, OverdueSeverity.recent);
  });

  test('severity boundary: 3 days recent, 4 days critical', () {
    PortfolioMetrics at(CivilDate t) => computePortfolio(
      projections: [project(c1, const [], t)],
      allTransactions: const [],
      today: t,
      contractsById: {c1.id: c1},
    );
    expect(
      at(d(2023, 11, 3)).overdueList.single.severity,
      OverdueSeverity.recent,
    );
    expect(
      at(d(2023, 11, 4)).overdueList.single.severity,
      OverdueSeverity.critical,
    );
  });

  test('weekly chart: 8 buckets each starting Monday, current last', () {
    final s = build().collectionsSeries(ChartPeriod.weeks8);
    expect(s, hasLength(8));
    for (final b in s) {
      expect(b.start.weekday, DateTime.monday);
      expect(b.end, b.start.addDays(6));
    }
    expect(s.last.start, d(2023, 11, 6));
    expect(s.last.isCurrent, isTrue);
    expect(s.last.collected, rs(5000));
    expect(s[6].collected, rs(26000));
    expect(mondayOf(d(2023, 11, 12)), d(2023, 11, 6)); // Sunday
    expect(mondayOf(d(2023, 11, 6)), d(2023, 11, 6));
  });

  test('monthly chart: 6 buckets ending current month', () {
    final s = build().collectionsSeries(ChartPeriod.months6);
    expect(s, hasLength(6));
    expect(s.last.start, d(2023, 11, 1));
    expect(s.first.start, d(2023, 6, 1));
    expect(s.last.collected, rs(25000));
  });

  test('empty book gives zero KPIs', () {
    final m = computePortfolio(
      projections: const [],
      allTransactions: const [],
      today: today,
      contractsById: const {},
    );
    expect(m.sanctionedReceivable, Money.zero);
    expect(m.receivableBreakdown.overdue.bps, 0);
    expect(m.overdueList, isEmpty);
  });
}
