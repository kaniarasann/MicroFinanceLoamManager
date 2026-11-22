import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import 'ledger_fixtures.dart';

/// Hand-computed fixture, today = Wed 6 Dec 2023.
///
/// A (#1 Anita): ₹1,00,000, 10 weekly ₹10,000 Tue from 31 Oct, net ₹93,000.
///   Paid 10k+10k+10k+6k → inst 4 partial (15 d), 5 missed (8 d), 6 missed
///   (1 d). S = ₹24,000, outstanding ₹64,000. Extensions 9/16/23 Jan.
/// B (#2 Bala): ₹30,000, 30 daily ₹1,000 from 1 Dec, net ₹28,000.
///   Paid 1 Dec 1k, 2 Dec 1k, 6 Dec 2k → 1–4 Dec paid, 5 Dec missed (1 d),
///   6 Dec due today unpaid. S = ₹1,000, outstanding ₹26,000. Ext 31 Dec.
/// C (#3 Chitra): ₹50,000, monthly 6th, 2 × ₹25,000 from 6 Nov, 5% upfront
///   → net ₹47,500. Paid 6 Nov 25k; 10 Nov 5k reversed 11 Nov.
///   6 Dec due today. Outstanding ₹25,000.
/// D (#4 Dev): rolled over (not active), net ₹18,600. Paid 20 Nov 20k,
///   rolloverSettlement 1 Dec 10k (no cash).
final CivilDate today = d(2023, 12, 6);

final Contract a = makeContract(id: 'A', loanNo: 1, borrowerName: 'Anita');
final Contract b = makeContract(
  id: 'B',
  loanNo: 2,
  borrowerName: 'Bala',
  sanctioned: rs(30000),
  installment: rs(1000),
  frequency: Frequency.daily,
  weekday: null,
  firstDue: d(2023, 12, 1),
  upfrontInput: 200000,
);
final Contract c = makeContract(
  id: 'C',
  loanNo: 3,
  borrowerName: 'Chitra',
  sanctioned: rs(50000),
  installment: rs(25000),
  frequency: Frequency.monthly,
  weekday: null,
  monthDay: 6,
  firstDue: d(2023, 11, 6),
  upfrontMode: UpfrontMode.percent,
  upfrontInput: 500,
);
final Contract dev = makeContract(
  id: 'D',
  loanNo: 4,
  borrowerName: 'Dev',
  sanctioned: rs(20000),
  installment: rs(10000),
  upfrontInput: 140000,
  status: ContractStatus.rolledOver,
);

final List<LedgerTransaction> txs = <LedgerTransaction>[
  tx('A', rs(93000), d(2023, 10, 24), type: TxType.disbursement),
  tx('A', rs(10000), d(2023, 10, 31)),
  tx('A', rs(10000), d(2023, 11, 7)),
  tx('A', rs(10000), d(2023, 11, 14)),
  tx('A', rs(6000), d(2023, 11, 21)),
  tx('B', rs(1000), d(2023, 12, 1)),
  tx('B', rs(1000), d(2023, 12, 2)),
  tx('B', rs(2000), d(2023, 12, 6)),
  tx('C', rs(25000), d(2023, 11, 6)),
  tx('C', rs(5000), d(2023, 11, 10), id: 'c-p2'),
  tx(
    'C',
    rs(5000),
    d(2023, 11, 11),
    type: TxType.reversal,
    reversesTxId: 'c-p2',
  ),
  tx('D', rs(20000), d(2023, 11, 20)),
  tx('D', rs(10000), d(2023, 12, 1), type: TxType.rolloverSettlement),
  tx('C', Money.zero, d(2023, 11, 12), type: TxType.reschedule),
];

List<LedgerTransaction> _of(String id) =>
    txs.where((LedgerTransaction t) => t.contractId == id).toList();

PortfolioMetrics _metrics() => computePortfolio(
  projections: <ContractProjection>[
    for (final k in <Contract>[a, b, c, dev]) project(k, _of(k.id), today),
  ],
  allTransactions: txs,
  today: today,
  contractsById: <String, Contract>{
    for (final k in <Contract>[a, b, c, dev]) k.id: k,
  },
);

void main() {
  late PortfolioMetrics m;
  setUp(() => m = _metrics());

  test('fixture sanity', () {
    expect(b.netDisbursed, rs(28000));
    expect(c.netDisbursed, rs(47500));
    expect(dev.netDisbursed, rs(18600));
  });

  group('KPIs', () {
    test('total net disbursed includes non-active contracts', () {
      expect(m.totalNetDisbursed, rs(93000 + 28000 + 47500 + 18600));
    });

    test('sanctioned receivable: active outstanding only', () {
      expect(m.sanctionedReceivable, rs(64000 + 26000 + 25000));
    });

    test('total collected: payments − reversals, settlements excluded', () {
      expect(m.totalCollected, rs(36000 + 4000 + 25000 + 20000));
    });

    test('overdue totals', () {
      expect(m.totalOverdue, rs(25000));
      expect(m.overdueInstallmentCount, 4);
      expect(m.maxDaysOverdue, 15);
    });
  });

  group('today due', () {
    test('rows due today across contracts and cash received today', () {
      expect(m.todayDue.amountDue, rs(26000));
      expect(m.todayDue.received, rs(2000));
      final items = m.todayDue.items;
      expect(items.map((TodayDueItem i) => i.loanNo), <int>[2, 3]);
      expect(items[0].borrowerName, 'Bala');
      expect(items[0].seq, 6);
      expect(items[0].amount, rs(1000));
      expect(items[0].isPaid, isFalse);
      expect(items[0].isExtension, isFalse);
      expect(items[1].contractId, 'C');
      expect(items[1].amount, rs(25000));
      expect(items[1].paid, Money.zero);
    });

    test('a paid row due today is listed as paid', () {
      final extra = <LedgerTransaction>[...txs, tx('B', rs(2000), today)];
      final pm = computePortfolio(
        projections: <ContractProjection>[
          project(b, extra.where((t) => t.contractId == 'B').toList(), today),
        ],
        allTransactions: extra,
        today: today,
        contractsById: <String, Contract>{'B': b},
      );
      expect(pm.todayDue.items.single.isPaid, isTrue);
      expect(pm.todayDue.received, rs(4000));
    });
  });

  group('receivable breakdown', () {
    test('collected this month, upcoming 30 days, overdue (+ bps)', () {
      final r = m.receivableBreakdown;
      expect(r.collectedThisMonth.amount, rs(4000));
      expect(r.collectedThisMonth.bps, 347); // 4,000 / 1,15,000
      // A: 12/19/26 Dec + 2 Jan = 40k; B: 6–30 Dec + ext 31 Dec = 26k;
      // C: 6 Dec 25k.
      expect(r.upcoming30.amount, rs(91000));
      expect(r.upcoming30.bps, 7913);
      expect(r.overdue.amount, rs(25000));
      expect(r.overdue.bps, 2173);
    });

    test('zero receivable → 0 bps', () {
      final pm = computePortfolio(
        projections: const <ContractProjection>[],
        allTransactions: txs,
        today: today,
        contractsById: const <String, Contract>{},
      );
      expect(pm.sanctionedReceivable, Money.zero);
      expect(pm.receivableBreakdown.collectedThisMonth.bps, 0);
      expect(pm.totalNetDisbursed, Money.zero);
      expect(pm.overdueList, isEmpty);
    });
  });

  group('overdue list', () {
    test('sorted by days desc then loanNo; severity', () {
      final list = m.overdueList;
      expect(
        list.map((OverdueItem o) => '${o.loanNo}/${o.seq}/${o.daysOverdue}'),
        <String>['1/4/15', '1/5/8', '1/6/1', '2/5/1'],
      );
      expect(list.map((OverdueItem o) => o.severity), <OverdueSeverity>[
        OverdueSeverity.critical,
        OverdueSeverity.critical,
        OverdueSeverity.recent,
        OverdueSeverity.recent,
      ]);
      expect(list.first.amount, rs(4000));
      expect(list.first.borrowerName, 'Anita');
      expect(list.first.dueDate, d(2023, 11, 21));
      expect(list.last.contractId, 'B');
    });

    test('severity boundary: 3 days recent, 4 days critical', () {
      OverdueItem item(int days) => OverdueItem(
        contractId: 'x',
        borrowerName: 'x',
        loanNo: 1,
        seq: 1,
        dueDate: today,
        amount: rs(1),
        daysOverdue: days,
      );
      expect(item(3).severity, OverdueSeverity.recent);
      expect(item(4).severity, OverdueSeverity.critical);
    });

    test('ties on days and loanNo break on contractId then seq', () {
      final x1 = makeContract(id: 'X1', loanNo: 7);
      final x2 = makeContract(id: 'X2', loanNo: 7);
      final pm = computePortfolio(
        projections: <ContractProjection>[
          project(x2, const <LedgerTransaction>[], d(2023, 11, 8)),
          project(x1, const <LedgerTransaction>[], d(2023, 11, 8)),
        ],
        allTransactions: const <LedgerTransaction>[],
        today: d(2023, 11, 8),
        contractsById: <String, Contract>{'X1': x1, 'X2': x2},
      );
      expect(
        pm.overdueList.map((OverdueItem o) => '${o.contractId}/${o.seq}'),
        <String>['X1/1', 'X2/1', 'X1/2', 'X2/2'],
      );

      // Today's items: same loanNo → contractId, then seq.
      final extra = installment(
        x1,
        11,
        d(2023, 11, 7),
        rs(500),
        kind: InstallmentKind.rescheduled,
      );
      final onDay = d(2023, 11, 7);
      final pt = computePortfolio(
        projections: <ContractProjection>[
          project(x2, const <LedgerTransaction>[], onDay),
          project(
            x1,
            const <LedgerTransaction>[],
            onDay,
            installments: <Installment>[...scheduleFor(x1), extra],
          ),
        ],
        allTransactions: const <LedgerTransaction>[],
        today: onDay,
        contractsById: <String, Contract>{'X1': x1, 'X2': x2},
      );
      expect(
        pt.todayDue.items.map((TodayDueItem i) => '${i.contractId}/${i.seq}'),
        <String>['X1/2', 'X1/11', 'X2/2'],
      );
    });
  });

  group('collections series', () {
    test('weeks8: Monday start, current bucket flagged', () {
      final s = m.collectionsSeries(ChartPeriod.weeks8);
      expect(s, hasLength(8));
      expect(s.map((CollectionBucket x) => x.start), <CivilDate>[
        d(2023, 10, 16),
        d(2023, 10, 23),
        d(2023, 10, 30),
        d(2023, 11, 6),
        d(2023, 11, 13),
        d(2023, 11, 20),
        d(2023, 11, 27),
        d(2023, 12, 4),
      ]);
      expect(s.every((CollectionBucket x) => x.start.weekday == 1), isTrue);
      expect(s.last.end, d(2023, 12, 10));
      expect(s.last.label, '4 Dec');
      expect(s.map((CollectionBucket x) => x.isCurrent), <bool>[
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
      ]);
      expect(s.map((CollectionBucket x) => x.due.rupeesPart), <int>[
        0,
        0,
        10000,
        35000,
        10000,
        10000,
        13000,
        42000,
      ]);
      expect(s.map((CollectionBucket x) => x.collected.rupeesPart), <int>[
        0,
        0,
        10000,
        35000,
        10000,
        26000,
        2000,
        2000,
      ]);
    });

    test('months6 and months12', () {
      final s6 = m.collectionsSeries(ChartPeriod.months6);
      expect(s6.map((CollectionBucket x) => x.label), <String>[
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ]);
      expect(s6.last.isCurrent, isTrue);
      expect(s6.last.end, d(2023, 12, 31));
      expect(s6[3].due, rs(10000));
      expect(s6[3].collected, rs(10000));
      expect(s6[4].due, rs(65000));
      expect(s6[4].collected, rs(71000));
      expect(s6[5].due, rs(96000));
      expect(s6[5].collected, rs(4000));

      final s12 = m.collectionsSeries(ChartPeriod.months12);
      expect(s12, hasLength(12));
      expect(s12.first.start, d(2023, 1, 1));
      expect(s12.first.label, 'Jan');
      expect(s12[1].end, d(2023, 2, 28));
      expect(s12.last.due, rs(96000));
    });

    test('weeks8 when today is a Monday / Sunday', () {
      PortfolioMetrics at(CivilDate t) => computePortfolio(
        projections: const <ContractProjection>[],
        allTransactions: const <LedgerTransaction>[],
        today: t,
        contractsById: const <String, Contract>{},
      );
      expect(
        at(d(2023, 12, 4)).collectionsSeries(ChartPeriod.weeks8).last.start,
        d(2023, 12, 4),
      );
      expect(
        at(d(2023, 12, 10)).collectionsSeries(ChartPeriod.weeks8).last.start,
        d(2023, 12, 4),
      );
      expect(mondayOf(d(2024, 1, 1)), d(2024, 1, 1));
      expect(mondayOf(d(2023, 12, 31)), d(2023, 12, 25));
    });
  });

  group('calendar buckets', () {
    test('December 2023 per-day figures', () {
      final days = m.calendarBuckets(2023, 12);
      expect(days, hasLength(31));
      CalendarDay day(int n) => days[n - 1];
      expect(day(1).date, d(2023, 12, 1));
      expect(day(1).collected, rs(1000));
      expect(day(1).collectedCount, 1);
      expect(day(1).scheduled, rs(1000));
      expect(day(5).scheduled, rs(11000));
      expect(day(5).scheduledCount, 2);
      expect(day(5).overdue, rs(11000));
      expect(day(5).overdueCount, 2);
      expect(day(6).scheduled, rs(26000));
      expect(day(6).collected, rs(2000));
      expect(day(6).overdue, Money.zero);
      expect(day(12).scheduled, rs(11000));
      expect(day(31).scheduled, rs(1000)); // B extension
      expect(day(31).scheduledCount, 1);
    });

    test('November 2023: reversal nets out, rescheduled-away skipped', () {
      final days = m.calendarBuckets(2023, 11);
      expect(days, hasLength(30));
      expect(days[9].collected, rs(5000)); // 10 Nov
      expect(days[9].collectedCount, 1);
      expect(days[10].collected, rs(-5000)); // 11 Nov reversal
      expect(days[10].collectedCount, 0);
      expect(days[20].overdue, rs(4000)); // 21 Nov partial
      expect(days[19].collected, rs(20000)); // D on 20 Nov
    });

    test('rescheduled-away rows are excluded from due figures', () {
      final rows = <Installment>[
        for (final i in scheduleFor(a))
          if (i.seq == 7) i.copyWith(rescheduledOut: rs(10000)) else i,
        installment(
          a,
          11,
          d(2023, 12, 14),
          rs(10000),
          kind: InstallmentKind.rescheduled,
        ),
      ];
      final pa = project(a, _of('A'), today, installments: rows);
      final pm = computePortfolio(
        projections: <ContractProjection>[pa],
        allTransactions: const <LedgerTransaction>[],
        today: today,
        contractsById: <String, Contract>{'A': a},
      );
      final cal = pm.calendarBuckets(2023, 12);
      expect(cal[11].scheduled, Money.zero); // 12 Dec moved away
      expect(cal[13].scheduled, rs(10000)); // 14 Dec
      final wk = pm.collectionsSeries(ChartPeriod.weeks8);
      expect(wk.last.due, rs(10000)); // only 5 Dec in 4–10 Dec
    });
  });

  group('reversal cash rules', () {
    test(
      'reversal of unknown original subtracts; of a settlement does not',
      () {
        final list = <LedgerTransaction>[
          tx('A', rs(10000), today, id: 'set', type: TxType.rolloverSettlement),
          tx('A', rs(10000), today, type: TxType.reversal, reversesTxId: 'set'),
          tx('A', rs(3000), today, type: TxType.reversal, reversesTxId: 'gone'),
          tx('A', rs(2000), today, type: TxType.reversal),
        ];
        final pm = computePortfolio(
          projections: const <ContractProjection>[],
          allTransactions: list,
          today: today,
          contractsById: const <String, Contract>{},
        );
        expect(pm.totalCollected, rs(-5000));
        expect(pm.todayDue.received, rs(-5000));
      },
    );
  });
}
