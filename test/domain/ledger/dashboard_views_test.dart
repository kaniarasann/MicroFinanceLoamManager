import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import 'ledger_fixtures.dart';

/// Sprint 7 dashboard / calendar / overdue views. Today = Wed 8 Nov 2023.
///
/// X (#2 Xavi): ₹1,00,000 weekly Tue ₹10,000 from 31 Oct, net ₹93,000.
///   Paid 31 Oct → 7 Nov missed (1 day). Outstanding ₹90,000.
/// Y (#4 Yash): ₹20,000 weekly Wed ₹5,000 from 1 Nov, ₹1,000 upfront.
///   Paid 1 Nov ₹5,000, 8 Nov ₹2,000 → 8 Nov partial, due today.
/// Z (#1 Zara): ₹9,000 weekly Tue ₹3,000 from 7 Nov, no upfront. Paid
///   ₹3,000 in advance on 6 Nov → 7 Nov paid.
/// W (#1 Wasim): ₹2,000, two ₹1,000 rows both on Tue 14 Nov.
final CivilDate today = d(2023, 11, 8);

final Contract x = makeContract(id: 'X', loanNo: 2, borrowerName: 'Xavi');
final Contract y = makeContract(
  id: 'Y',
  loanNo: 4,
  borrowerName: 'Yash',
  sanctioned: rs(20000),
  installment: rs(5000),
  weekday: 3,
  firstDue: d(2023, 11, 1),
  upfrontInput: 100000,
);
final Contract z = makeContract(
  id: 'Z',
  loanNo: 1,
  borrowerName: 'Zara',
  sanctioned: rs(9000),
  installment: rs(3000),
  firstDue: d(2023, 11, 7),
  upfrontInput: 0,
);
final Contract w = makeContract(
  id: 'W',
  loanNo: 1,
  borrowerName: 'Wasim',
  sanctioned: rs(2000),
  installment: rs(1000),
  firstDue: d(2023, 11, 14),
  upfrontInput: 0,
);

final List<LedgerTransaction> activeTx = <LedgerTransaction>[
  tx('X', rs(10000), d(2023, 10, 31), mode: PaymentMode.cash),
  tx('Y', rs(5000), d(2023, 11, 1), mode: PaymentMode.cash),
  tx('Y', rs(2000), d(2023, 11, 8), mode: PaymentMode.upi),
  tx('Z', rs(3000), d(2023, 11, 6), mode: PaymentMode.cash),
];

List<LedgerTransaction> _of(String id, List<LedgerTransaction> all) =>
    all.where((LedgerTransaction t) => t.contractId == id).toList();

List<ContractProjection> _projections() => <ContractProjection>[
  project(x, _of('X', activeTx), today),
  project(y, _of('Y', activeTx), today),
  project(z, _of('Z', activeTx), today),
  project(
    w,
    const <LedgerTransaction>[],
    today,
    installments: <Installment>[
      installment(w, 1, d(2023, 11, 14), rs(1000)),
      installment(w, 2, d(2023, 11, 14), rs(1000)),
    ],
  ),
];

Map<String, Contract> _active() => <String, Contract>{
  for (final c in <Contract>[x, y, z, w]) c.id: c,
};

PortfolioMetrics _metrics({
  List<LedgerTransaction> extraTx = const <LedgerTransaction>[],
  List<Contract> history = const <Contract>[],
}) => computePortfolio(
  projections: _projections(),
  allTransactions: <LedgerTransaction>[...activeTx, ...extraTx],
  today: today,
  contractsById: _active(),
  historyContracts: history,
);

Contract _closed(
  String id, {
  required int loanNo,
  required int sanctionedRs,
  required int paidRs,
  int waivedRs = 0,
  int? settledRs,
  ContractStatus status = ContractStatus.closed,
  int? netRs,
}) =>
    makeContract(
      id: id,
      loanNo: loanNo,
      borrowerName: 'History $id',
      sanctioned: rs(sanctionedRs),
      installment: rs(sanctionedRs),
      upfrontInput: 0,
      status: status,
      netDisbursed: netRs == null ? null : rs(netRs),
    ).copyWith(
      totalPaid: rs(paidRs),
      totalWaived: rs(waivedRs),
      rolloverSettled: settledRs == null ? null : rs(settledRs),
    );

String _key(DueRowItem i) => '${i.contractId}${i.seq}';

void main() {
  group('chartWindowStart', () {
    test('1st of the month 11 months back', () {
      expect(chartWindowStart(d(2023, 11, 8)), d(2022, 12, 1));
      expect(chartWindowStart(d(2024, 1, 31)), d(2023, 2, 1));
      expect(chartWindowStart(d(2023, 12, 1)), d(2023, 1, 1));
    });
  });

  group('dueItemsBetween / dayItems', () {
    final m = _metrics();

    test('order: date, open before paid, loanNo, contractId, seq', () {
      final items = m.dueItemsBetween(d(2023, 10, 31), d(2023, 11, 14));
      expect(items.map(_key), <String>[
        'X1', 'Y1', //
        'X2', 'Z1', // 7 Nov: open #2 before paid #1
        'Y2',
        'W1', 'W2', 'Z2', 'X3', // 14 Nov: loan 1 (W < Z, seq), then loan 2
      ]);
    });

    test('row details carry borrower, status and cycles', () {
      final items = m.dueItemsBetween(d(2023, 11, 7), d(2023, 11, 7));
      final x2 = items.first;
      expect(x2.borrowerId, 'b-X');
      expect(x2.borrowerPhoneE164, '+919812345678');
      expect(x2.frequency, Frequency.weekly);
      expect(x2.status, RowStatus.overdue);
      expect(x2.daysOverdue, 1);
      expect(x2.remaining, rs(10000));
      expect(x2.cyclesTotal, 11); // 10 base + 1 extension
      expect(items.last.isPaid, isTrue);
      expect(items.last.remaining, Money.zero);
    });

    test('dayItems is one day; empty days and out-of-range rows excluded', () {
      final today8 = m.dayItems(today);
      expect(today8.map(_key), <String>['Y2']);
      expect(today8.single.status, RowStatus.dueToday);
      expect(today8.single.paid, rs(2000));
      expect(today8.single.remaining, rs(3000));
      expect(m.dayItems(d(2023, 11, 9)), isEmpty);
      expect(m.dueItemsBetween(d(2023, 10, 1), d(2023, 10, 30)), isEmpty);
    });

    test('extension rows are included, rescheduled-away rows are not', () {
      final r = makeContract(id: 'R', loanNo: 9, sanctioned: rs(20000));
      final rows = <Installment>[
        installment(
          r,
          1,
          d(2023, 10, 31),
          rs(10000),
          rescheduledOut: rs(10000),
        ),
        installment(r, 2, d(2023, 11, 7), rs(10000)),
      ];
      final pm = computePortfolio(
        projections: <ContractProjection>[
          project(r, const <LedgerTransaction>[], today, installments: rows),
        ],
        allTransactions: const <LedgerTransaction>[],
        today: today,
        contractsById: <String, Contract>{r.id: r},
      );
      final all = pm.dueItemsBetween(d(2023, 10, 1), d(2024, 12, 31));
      expect(all.any((DueRowItem i) => i.seq == 1), isFalse);
      expect(all.where((DueRowItem i) => i.isExtension), hasLength(1));
      final oct = pm.calendarBuckets(2023, 10);
      expect(oct[30].scheduledCount, 0);
    });
  });

  group('calendar settled / pending / overdue', () {
    final m = _metrics();
    final nov = m.calendarBuckets(2023, 11);
    CalendarDay day(int n) => nov[n - 1];

    test('a day with a paid and an overdue row', () {
      final d7 = day(7);
      expect(d7.scheduled, rs(13000));
      expect(d7.settled, rs(3000));
      expect(d7.settledCount, 1);
      expect(d7.overdue, rs(10000));
      expect(d7.overdueCount, 1);
      expect(d7.pending, Money.zero);
      expect(d7.hasCollectedDot, isTrue);
      expect(d7.hasPendingDot, isFalse);
      expect(d7.hasOverdueDot, isTrue);
    });

    test('a partial row due today: paid part settled, rest pending', () {
      final d8 = day(8);
      expect(d8.settled, rs(2000));
      expect(d8.settledCount, 0);
      expect(d8.pending, rs(3000));
      expect(d8.pendingCount, 1);
      expect(d8.hasCollectedDot, isTrue);
      expect(d8.hasPendingDot, isTrue);
      expect(d8.hasOverdueDot, isFalse);
    });

    test('future and empty days', () {
      expect(day(14).pending, rs(15000));
      expect(day(14).pendingCount, 4);
      final empty = day(10);
      expect(empty.hasCollectedDot, isFalse);
      expect(empty.hasPendingDot, isFalse);
      expect(empty.hasOverdueDot, isFalse);
    });

    test('month totals', () {
      final t = CalendarTotals.of(nov);
      expect(t.settled, rs(10000));
      expect(t.pending, rs(51000));
      expect(t.overdue, rs(10000));
      final none = CalendarTotals.of(const <CalendarDay>[]);
      expect(none.settled, Money.zero);
    });
  });

  group('today due and KPIs', () {
    final m = _metrics();

    test('counts and progress', () {
      final t = m.todayDue;
      expect(t.amountDue, rs(5000));
      expect(t.received, rs(2000));
      expect(t.progressBps, 4000);
      expect(t.collectedCount, 0);
      expect(t.pendingCount, 1);
    });

    test('progress caps at 100% and floors at 0', () {
      TodayDue td(int due, int got) => TodayDue(
        amountDue: rs(due),
        received: rs(got),
        items: const <TodayDueItem>[],
      );
      expect(td(1000, 1500).progressBps, 10000);
      expect(td(1000, -100).progressBps, 0);
      expect(td(0, 500).progressBps, 0);
    });

    test('counts and risk', () {
      expect(m.activeContractCount, 4);
      expect(m.overdueLoanCount, 1);
      expect(m.sanctionedReceivable, rs(90000 + 13000 + 6000 + 2000));
      expect(m.totalOverdue, rs(10000));
      expect(m.overdueRiskBps, 900); // 10,000 / 1,11,000 = 9.009%
      expect(m.excessToReview, isEmpty);
    });

    test('overdue items carry contact details', () {
      final o = m.overdueList.single;
      expect(o.borrowerId, 'b-X');
      expect(o.borrowerPhoneE164, '+919812345678');
      expect(o.frequency, Frequency.weekly);
    });

    test('severityFor boundary', () {
      expect(severityFor(3), OverdueSeverity.recent);
      expect(severityFor(4), OverdueSeverity.critical);
    });
  });

  group('history contracts', () {
    final h1 = _closed('H1', loanNo: 7, sanctionedRs: 30000, paidRs: 32000);
    final h2 = _closed(
      'H2',
      loanNo: 8,
      sanctionedRs: 20000,
      paidRs: 20000,
      settledRs: 8000,
      status: ContractStatus.rolledOver,
      netRs: 5000,
    );
    final h3 = _closed(
      'H3',
      loanNo: 9,
      sanctionedRs: 10000,
      paidRs: 9000,
      waivedRs: 1500,
    );
    // A stale copy of an active contract: ignored.
    final dupX = x.copyWith(status: ContractStatus.closed, totalPaid: rs(1));
    final late = tx('H1', rs(2000), today, mode: PaymentMode.cash);
    final m = _metrics(
      extraTx: <LedgerTransaction>[late],
      history: <Contract>[h1, h2, h3, dupX],
    );

    test('net disbursed adds history contracts once', () {
      expect(
        m.totalNetDisbursed,
        rs(93000 + 19000 + 9000 + 2000 + 30000 + 5000 + 10000),
      );
      final again = computePortfolio(
        projections: _projections(),
        allTransactions: activeTx,
        today: today,
        contractsById: <String, Contract>{..._active(), h1.id: h1},
        historyContracts: <Contract>[h1],
      );
      expect(again.totalNetDisbursed, rs(93000 + 19000 + 9000 + 2000 + 30000));
    });

    test('collected uses the cached cash of history contracts', () {
      // Active cash 20,000 + H1 32,000 + H2 (20,000 − 8,000) + H3 9,000;
      // H1's windowed transaction is not counted twice.
      expect(m.totalCollected, rs(20000 + 32000 + 12000 + 9000));
    });

    test('dated figures still include history transactions', () {
      expect(m.todayDue.received, rs(4000));
      expect(m.receivableBreakdown.collectedThisMonth.amount, rs(12000));
      final weeks = m.collectionsSeries(ChartPeriod.weeks8);
      expect(weeks.last.collected, rs(7000));
      expect(weeks[6].collected, rs(15000));
    });

    test('excess to review: history paid pool above sanctioned', () {
      expect(m.excessToReview.map((ExcessItem e) => e.contractId), <String>[
        'H1',
        'H3',
      ]);
      expect(m.excessToReview.first.excess, rs(2000));
      expect(m.excessToReview.first.status, ContractStatus.closed);
      expect(m.excessToReview.last.excess, rs(500));
    });

    test('excess sort: amount desc, then loanNo, then id; active included', () {
      final e = makeContract(
        id: 'E',
        loanNo: 8,
        sanctioned: rs(1000),
        installment: rs(1000),
        upfrontInput: 0,
      );
      final h5 = _closed('H5', loanNo: 9, sanctionedRs: 10000, paidRs: 10500);
      final eTx = <LedgerTransaction>[
        tx('E', rs(1500), d(2023, 11, 1), mode: PaymentMode.cash),
      ];
      final pm = computePortfolio(
        projections: <ContractProjection>[project(e, eTx, today)],
        allTransactions: eTx,
        today: today,
        contractsById: <String, Contract>{e.id: e},
        historyContracts: <Contract>[h5, h3, h1],
      );
      expect(pm.excessToReview.map((ExcessItem i) => i.contractId), <String>[
        'H1',
        'E',
        'H3',
        'H5',
      ]);
      expect(pm.excessToReview[1].status, ContractStatus.active);
      expect(pm.excessToReview[1].borrowerName, 'Anita Sharma');
      expect(pm.excessToReview[1].loanNo, 8);
    });
  });

  group('series totals', () {
    CollectionBucket b(int due, int got, {bool current = false}) =>
        CollectionBucket(
          start: today,
          end: today,
          label: 'x',
          due: rs(due),
          collected: rs(got),
          isCurrent: current,
        );

    test('sums, rate and peak', () {
      final buckets = <CollectionBucket>[b(100, 50), b(0, 120)];
      final t = SeriesTotals.of(buckets);
      expect(t.due, rs(100));
      expect(t.collected, rs(170));
      expect(t.rateBps, 17000);
      expect(SeriesTotals.peak(buckets), rs(120));
      expect(SeriesTotals.peak(<CollectionBucket>[b(300, 10)]), rs(300));
      expect(buckets.first.rateBps, 5000);
      expect(buckets.last.rateBps, 0);
    });

    test('empty', () {
      final t = SeriesTotals.of(const <CollectionBucket>[]);
      expect(t.due, Money.zero);
      expect(t.rateBps, 0);
      expect(SeriesTotals.peak(const <CollectionBucket>[]), Money.zero);
    });
  });

  group('overdue tracker', () {
    OverdueItem o(
      String c,
      int loan,
      int seq,
      CivilDate due,
      int amt,
      int days,
    ) => OverdueItem(
      contractId: c,
      borrowerId: 'b-$c',
      borrowerName: 'Name $c',
      borrowerPhoneE164: '+91981234567$loan',
      loanNo: loan,
      frequency: Frequency.daily,
      seq: seq,
      dueDate: due,
      amount: rs(amt),
      daysOverdue: days,
    );

    final items = <OverdueItem>[
      o('D', 5, 2, d(2023, 11, 7), 400, 1),
      o('A', 2, 4, d(2023, 11, 6), 500, 2),
      o('A', 2, 3, d(2023, 11, 1), 1000, 7),
      o('C', 1, 1, d(2023, 11, 6), 300, 2),
      o('E', 3, 1, d(2023, 11, 6), 100, 2),
      o('B', 1, 1, d(2023, 11, 6), 700, 2),
      o('A', 2, 5, d(2023, 11, 6), 0, 2),
    ];
    final loans = groupOverdueByLoan(items);

    test('groups rows per contract', () {
      expect(loans.map((OverdueLoan l) => l.contractId), <String>[
        'A',
        'B',
        'C',
        'E',
        'D',
      ]);
      final a = loans.first;
      expect(a.amount, rs(1500));
      expect(a.daysOverdue, 7);
      expect(a.oldestDueDate, d(2023, 11, 1));
      expect(a.installmentCount, 3);
      expect(a.severity, OverdueSeverity.critical);
      expect(a.borrowerId, 'b-A');
      expect(a.borrowerName, 'Name A');
      expect(a.borrowerPhoneE164, '+919812345672');
      expect(a.loanNo, 2);
      expect(a.frequency, Frequency.daily);
      expect(loans.last.severity, OverdueSeverity.recent);
    });

    test('filters', () {
      expect(matchesOverdueFilter(loans.first, OverdueFilter.all), isTrue);
      expect(matchesOverdueFilter(loans.first, OverdueFilter.critical), isTrue);
      expect(matchesOverdueFilter(loans.first, OverdueFilter.recent), isFalse);
      expect(matchesOverdueFilter(loans.last, OverdueFilter.critical), isFalse);
      expect(matchesOverdueFilter(loans.last, OverdueFilter.recent), isTrue);
    });

    test('summaries per filter', () {
      final all = OverdueSummary.of(loans, OverdueFilter.all);
      expect(all.loans, hasLength(5));
      expect(all.total, rs(3000));
      expect(all.maxDaysOverdue, 7);
      expect(all.allCount, 5);
      expect(all.criticalCount, 1);
      expect(all.recentCount, 4);

      final critical = OverdueSummary.of(loans, OverdueFilter.critical);
      expect(critical.loans.single.contractId, 'A');
      expect(critical.total, rs(1500));

      final recent = OverdueSummary.of(loans, OverdueFilter.recent);
      expect(recent.loans.map((OverdueLoan l) => l.contractId), <String>[
        'B',
        'C',
        'E',
        'D',
      ]);
      expect(recent.total, rs(1500));
      expect(recent.maxDaysOverdue, 2);
      expect(recent.allCount, 5);
    });

    test('empty', () {
      expect(groupOverdueByLoan(const <OverdueItem>[]), isEmpty);
      final s = OverdueSummary.of(const <OverdueLoan>[], OverdueFilter.all);
      expect(s.total, Money.zero);
      expect(s.maxDaysOverdue, 0);
      expect(s.allCount, 0);
    });
  });

  group('attempt 2: no double count, history rows', () {
    test('overdue + upcoming30 ≤ receivable with an extension in 30 days', () {
      // ₹40,000 weekly ₹10,000 from Tue 31 Oct, ₹5,000 paid; today 8 Nov:
      // ₹15,000 overdue, extensions 28 Nov / 5 Dec (inside 30 days).
      final e = makeContract(id: 'E', sanctioned: rs(40000));
      final txs = <LedgerTransaction>[
        tx('E', rs(5000), d(2023, 11, 1), mode: PaymentMode.cash),
      ];
      final pm = computePortfolio(
        projections: <ContractProjection>[project(e, txs, today)],
        allTransactions: txs,
        today: today,
        contractsById: <String, Contract>{e.id: e},
      );
      final b = pm.receivableBreakdown;
      expect(pm.sanctionedReceivable, rs(35000));
      expect(b.overdue.amount, rs(15000));
      expect(b.upcoming30.amount, rs(20000));
      expect(
        b.upcoming30.amount + b.overdue.amount,
        lessThanOrEqualTo(pm.sanctionedReceivable),
      );
      expect(b.upcoming30.bps + b.overdue.bps, lessThanOrEqualTo(10000));

      // Calendar: the extension keeps its amber dot and list row with the
      // source label, but is left out of the Pending total.
      final nov = pm.calendarBuckets(2023, 11);
      final ext = nov[27]; // 28 Nov
      expect(ext.hasPendingDot, isTrue);
      expect(ext.pending, Money.zero);
      final rows = pm.dayItems(d(2023, 11, 28));
      expect(rows.single.isExtension, isTrue);
      // Extensions carry the shortfall latest-first.
      expect(rows.single.sourceLabel, startsWith('missed on 7 Nov'));
      expect(CalendarTotals.of(nov).pending, rs(20000));
    });

    final closed = makeContract(
      id: 'H',
      loanNo: 7,
      borrowerName: 'Hari',
      sanctioned: rs(10000),
      installment: rs(5000),
      firstDue: d(2023, 10, 24),
      upfrontInput: 0,
      status: ContractStatus.closed,
    ).copyWith(totalPaid: rs(10000));
    final rolled = makeContract(
      id: 'R',
      loanNo: 8,
      borrowerName: 'Ravi',
      sanctioned: rs(20000),
      installment: rs(10000),
      firstDue: d(2023, 10, 31),
      upfrontInput: 0,
      status: ContractStatus.rolledOver,
    ).copyWith(totalPaid: rs(20000), rolloverSettled: rs(12000));
    final hTx = <LedgerTransaction>[
      tx('H', rs(5000), d(2023, 10, 24), mode: PaymentMode.cash),
      tx('H', rs(5000), d(2023, 10, 31), mode: PaymentMode.cash),
      tx('R', rs(8000), d(2023, 10, 31), mode: PaymentMode.cash),
      tx('R', rs(12000), d(2023, 11, 1), type: TxType.rolloverSettlement),
    ];
    final rRows = scheduleFor(rolled);
    PortfolioMetrics withHistory() => computePortfolio(
      projections: _projections(),
      allTransactions: <LedgerTransaction>[...activeTx, ...hTx],
      today: today,
      contractsById: _active(),
      historyContracts: <Contract>[closed, rolled],
      historyInstallments: <Installment>[
        ...scheduleFor(closed),
        ...rRows,
        rRows.first, // duplicate id: counted once
        // A rescheduled-away row (effective due 0) is skipped.
        installment(
          rolled,
          9,
          d(2023, 10, 31),
          rs(3000),
          rescheduledOut: rs(3000),
        ),
        // Rows of an active contract (active wins) and of an unknown
        // contract are ignored.
        installment(x, 1, d(2023, 10, 31), rs(10000), id: 'X-dup'),
        installment(makeContract(id: 'U'), 1, d(2023, 10, 31), rs(10000)),
      ],
    );

    test('a loan closed in the window keeps the bucket rate ≤ 100%', () {
      final weeks = withHistory().collectionsSeries(ChartPeriod.weeks8);
      final w30oct = weeks[6]; // Mon 30 Oct – Sun 5 Nov
      // Due: X 31 Oct ₹10,000, Y 1 Nov ₹5,000, H 31 Oct ₹5,000,
      // R 31 Oct ₹10,000. Collected: X ₹10,000 + Y ₹5,000 + H ₹5,000 +
      // R ₹8,000 (the settlement is not cash).
      expect(w30oct.due, rs(30000));
      expect(w30oct.collected, rs(28000));
      expect(w30oct.rateBps, lessThanOrEqualTo(10000));
      final w23oct = weeks[5];
      expect(w23oct.due, rs(5000));
      expect(w23oct.collected, rs(5000));
      expect(SeriesTotals.of(weeks).rateBps, lessThanOrEqualTo(10000));
    });

    test('history rows on the calendar: settled, no Record', () {
      final m = withHistory();
      final oct = m.calendarBuckets(2023, 10);
      final d31 = oct[30];
      // X #1 paid ₹10,000 + H #2 ₹5,000 + R #1 ₹10,000.
      expect(d31.settled, rs(25000));
      expect(d31.settledCount, 3);
      expect(d31.scheduledCount, 3);
      expect(d31.hasCollectedDot, isTrue);
      expect(oct[23].settled, rs(5000)); // 24 Oct: H #1
      expect(CalendarTotals.of(oct).settled, rs(30000));

      final rows = m.dayItems(d(2023, 10, 31));
      expect(rows.map((DueRowItem i) => '${i.contractId}${i.seq}'), <String>[
        'X1', // all settled: loanNo 2, 7, 8
        'H2',
        'R1',
      ]);
      final h = rows[1];
      expect(h.isHistory, isTrue);
      expect(h.isPaid, isTrue);
      expect(h.status, RowStatus.paid);
      expect(h.contractStatus, ContractStatus.closed);
      expect(h.cyclesTotal, 2);
      expect(h.borrowerName, 'Hari');
      expect(rows.last.contractStatus, ContractStatus.rolledOver);
      expect(rows.first.isHistory, isFalse);

      // November: R #2 (7 Nov) was settled by the rollover.
      final r2 = m
          .dayItems(d(2023, 11, 7))
          .where((DueRowItem i) => i.contractId == 'R');
      expect(r2.single.isPaid, isTrue);
      expect(m.calendarBuckets(2023, 11)[6].settled, rs(3000 + 10000));
    });
  });
}
