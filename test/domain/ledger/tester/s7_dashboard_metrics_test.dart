import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import '../ledger_fixtures.dart';

/// Sprint 7 tester: dashboard KPIs, chart buckets, receivable breakdown,
/// calendar and overdue maths, against hand-computed figures.

/// A history (closed / rolled-over) contract with cached aggregates.
Contract hist(
  String id, {
  required int sanctionedRs,
  required int paidRs,
  required int netRs,
  int waivedRs = 0,
  int? settledRs,
  ContractStatus status = ContractStatus.closed,
  int loanNo = 7,
}) =>
    makeContract(
      id: id,
      loanNo: loanNo,
      borrowerName: 'History $id',
      sanctioned: rs(sanctionedRs),
      installment: rs(sanctionedRs),
      upfrontInput: 0,
      status: status,
      netDisbursed: rs(netRs),
    ).copyWith(
      totalPaid: rs(paidRs),
      totalWaived: rs(waivedRs),
      rolloverSettled: settledRs == null ? null : rs(settledRs),
    );

LedgerTransaction inactive(LedgerTransaction t) =>
    t.copyWith(contractActive: false);

void main() {
  group('KPIs against recorded data (today Wed 8 Nov 2023)', () {
    final today = d(2023, 11, 8);
    // A: active ₹1,00,000 weekly Tue ₹10,000 from 31 Oct, net ₹93,000.
    final a = makeContract(id: 'A', loanNo: 1);
    final aTx = <LedgerTransaction>[
      tx('A', rs(10000), d(2023, 10, 31), id: 'a1'),
      tx('A', rs(3000), d(2023, 11, 7), id: 'a2'),
      tx(
        'A',
        rs(3000),
        d(2023, 11, 8),
        id: 'a2r',
        type: TxType.reversal,
        reversesTxId: 'a2',
      ),
    ];
    // C: closed ₹20,000, paid in full on 1 Nov (net ₹18,000).
    final c = hist('C', sanctionedRs: 20000, paidRs: 20000, netRs: 18000);
    // R: rolled over ₹30,000: ₹18,000 cash + ₹12,000 settled by rollover.
    final r = hist(
      'R',
      sanctionedRs: 30000,
      paidRs: 30000,
      settledRs: 12000,
      netRs: 27000,
      status: ContractStatus.rolledOver,
    );
    // W: closed early with a waiver: ₹9,000 cash + ₹1,000 waived.
    final wv = hist(
      'W',
      sanctionedRs: 10000,
      paidRs: 9000,
      waivedRs: 1000,
      netRs: 9500,
    );
    final historyTx = <LedgerTransaction>[
      inactive(tx('C', rs(20000), d(2023, 11, 1), id: 'c1')),
      inactive(tx('R', rs(18000), d(2023, 11, 2), id: 'r1')),
      inactive(
        tx(
          'R',
          rs(12000),
          d(2023, 11, 3),
          id: 'r2',
          type: TxType.rolloverSettlement,
        ),
      ),
      inactive(tx('W', rs(9000), d(2023, 11, 6), id: 'w1')),
      inactive(
        tx('W', rs(1000), d(2023, 11, 6), id: 'w2', type: TxType.waiver),
      ),
    ];
    // A stale copy of A in the history listener (mid close / reopen).
    final staleA = a.copyWith(
      status: ContractStatus.closed,
      totalPaid: rs(99999),
      netDisbursed: rs(55555),
    );

    PortfolioMetrics metrics({
      List<LedgerTransaction> extra = const <LedgerTransaction>[],
    }) => computePortfolio(
      projections: <ContractProjection>[project(a, aTx, today)],
      allTransactions: <LedgerTransaction>[...aTx, ...historyTx, ...extra],
      today: today,
      contractsById: <String, Contract>{a.id: a},
      historyContracts: <Contract>[c, r, wv, staleA],
    );

    test('Total collected: active + closed + rolledOver cash + waiver-closed '
        'cash; no waiver, no settlement, no double count', () {
      // 10,000 (A net of reversal) + 20,000 + 18,000 + 9,000.
      expect(metrics().totalCollected, rs(57000));
    });

    test('Net disbursed: active + every history contract, stale A ignored', () {
      expect(metrics().totalNetDisbursed, rs(93000 + 18000 + 27000 + 9500));
    });

    test('Outstanding, overdue amount and count', () {
      final m = metrics();
      expect(m.sanctionedReceivable, rs(90000));
      expect(m.totalOverdue, rs(10000)); // 7 Nov row, 1 day late
      expect(m.overdueInstallmentCount, 1);
      expect(m.overdueLoanCount, 1);
      expect(m.maxDaysOverdue, 1);
      expect(m.activeContractCount, 1);
      expect(m.totalWaived, rs(1000));
    });

    test('Collected this month counts dated cash of history loans once', () {
      // Nov: A 3,000 − 3,000, C 20,000, R 18,000, W 9,000.
      expect(
        metrics().receivableBreakdown.collectedThisMonth.amount,
        rs(47000),
      );
    });

    test(
      'a reversal reduces collected (known and out-of-window originals)',
      () {
        final base = metrics().totalCollected;
        final known = metrics(
          extra: <LedgerTransaction>[
            tx(
              'A',
              rs(10000),
              d(2023, 11, 8),
              id: 'a1r',
              type: TxType.reversal,
              reversesTxId: 'a1',
            ),
          ],
        );
        expect(known.totalCollected, base - rs(10000));
        expect(known.todayDue.received, rs(-13000));
        expect(known.todayDue.progressBps, 0); // clamped, never negative

        final unknownPayment = metrics(
          extra: <LedgerTransaction>[
            tx(
              'A',
              rs(500),
              d(2023, 11, 8),
              id: 'old-r',
              type: TxType.reversal,
              reversesTxId: 'outside-window',
            ),
          ],
        );
        expect(unknownPayment.totalCollected, base - rs(500));

        // A waiver reversal (no mode) whose waiver is out of the window.
        final waiverRev = metrics(
          extra: <LedgerTransaction>[
            tx(
              'A',
              rs(500),
              d(2023, 11, 8),
              id: 'old-wr',
              type: TxType.reversal,
              reversesTxId: 'outside-window-w',
              noMode: true,
            ),
          ],
        );
        expect(waiverRev.totalCollected, base);
      },
    );
  });

  group('Collections chart buckets (IST civil dates)', () {
    test('8W: Monday-start weeks, Sunday ends, current flagged', () {
      final today = d(2023, 11, 12); // Sunday
      // Monthly-free: weekly Monday ₹10,000 from Mon 30 Oct.
      final c = makeContract(
        id: 'M',
        sanctioned: rs(50000),
        weekday: 1,
        firstDue: d(2023, 10, 30),
      );
      final txs = <LedgerTransaction>[
        tx('M', rs(1000), d(2023, 9, 17)), // Sun before the window
        tx('M', rs(1000), d(2023, 9, 18)), // Mon, first bucket
        tx('M', rs(2000), d(2023, 11, 5)), // Sun → week of 30 Oct
        tx('M', rs(3000), d(2023, 11, 6)), // Mon → current week
        tx('M', rs(4000), d(2023, 11, 12)), // Sun today → current week
      ];
      final m = computePortfolio(
        projections: <ContractProjection>[project(c, txs, today)],
        allTransactions: txs,
        today: today,
        contractsById: <String, Contract>{c.id: c},
      );
      final s = m.collectionsSeries(ChartPeriod.weeks8);
      expect(s, hasLength(8));
      expect(s.first.start, d(2023, 9, 18));
      expect(s.last.start, d(2023, 11, 6));
      expect(s.last.end, d(2023, 11, 12));
      for (final b in s) {
        expect(b.start.weekday, DateTime.monday, reason: b.label);
        expect(b.start.daysBetween(b.end), 6);
      }
      expect(s.map((CollectionBucket b) => b.isCurrent), <bool>[
        false, false, false, false, false, false, false, true, //
      ]);
      expect(s.first.label, '18 Sep');
      expect(s.first.collected, rs(1000));
      expect(s[6].collected, rs(2000));
      expect(s[7].collected, rs(7000));
      expect(s[6].due, rs(10000)); // 30 Oct
      expect(s[7].due, rs(10000)); // 6 Nov
      expect(s[6].rateBps, 2000);
      final totals = SeriesTotals.of(s);
      expect(totals.collected, rs(10000));
      expect(totals.due, rs(20000));
      expect(totals.rateBps, 5000);
    });

    test('6M across a leap February and the 31st', () {
      final today = d(2024, 3, 15);
      final c = makeContract(
        id: 'MO',
        sanctioned: rs(60000),
        frequency: Frequency.monthly,
        weekday: null,
        monthDay: 31,
        firstDue: d(2023, 10, 31),
        disbursedOn: d(2023, 10, 1),
      );
      final txs = <LedgerTransaction>[
        tx('MO', rs(100), d(2023, 9, 30)), // outside
        tx('MO', rs(200), d(2023, 10, 1)),
        tx('MO', rs(300), d(2023, 10, 31)),
        tx('MO', rs(400), d(2024, 1, 31)),
        tx('MO', rs(500), d(2024, 2, 1)),
        tx('MO', rs(600), d(2024, 2, 29)),
        tx('MO', rs(700), d(2024, 3, 1)),
      ];
      final m = computePortfolio(
        projections: <ContractProjection>[project(c, txs, today)],
        allTransactions: txs,
        today: today,
        contractsById: <String, Contract>{c.id: c},
      );
      final s = m.collectionsSeries(ChartPeriod.months6);
      expect(s.map((CollectionBucket b) => b.label), <String>[
        'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar', //
      ]);
      final feb = s[4];
      expect(feb.start, d(2024, 2, 1));
      expect(feb.end, d(2024, 2, 29));
      expect(s[0].collected, rs(500));
      expect(s[3].collected, rs(400));
      expect(feb.collected, rs(1100));
      expect(s[5].collected, rs(700));
      expect(s[5].isCurrent, isTrue);
      expect(s.where((CollectionBucket b) => b.isCurrent), hasLength(1));
      // Monthly day-31 rows clamp to 30 Nov and 29 Feb: one due per month.
      // (Overdue shortfalls are re-planned as extension rows after March.)
      for (final b in s) {
        expect(b.due, rs(10000), reason: b.label);
      }
    });

    test('12M ending on a leap day', () {
      final today = d(2024, 2, 29);
      final m = computePortfolio(
        projections: const <ContractProjection>[],
        allTransactions: <LedgerTransaction>[
          tx('Q', rs(100), d(2023, 2, 28)), // outside
          tx('Q', rs(200), d(2023, 3, 1)),
          tx('Q', rs(300), d(2024, 2, 29)),
        ],
        today: today,
        contractsById: const <String, Contract>{},
      );
      final s = m.collectionsSeries(ChartPeriod.months12);
      expect(s, hasLength(12));
      expect(s.first.start, d(2023, 3, 1));
      expect(s.last.end, d(2024, 2, 29));
      expect(s.first.collected, rs(200));
      expect(s.last.collected, rs(300));
      expect(s.last.isCurrent, isTrue);
    });

    test('Due includes rows of loans closed in the window, so the rate '
        'stays within 100%', () {
      // A ₹10,000 single-installment loan due and paid on Tue 31 Oct,
      // closed since. Today Wed 8 Nov.
      final today = d(2023, 11, 8);
      final closed = hist(
        'H',
        sanctionedRs: 10000,
        paidRs: 10000,
        netRs: 10000,
      ).copyWith(firstDueDate: d(2023, 10, 31));
      final m = computePortfolio(
        projections: const <ContractProjection>[],
        allTransactions: <LedgerTransaction>[
          inactive(tx('H', rs(10000), d(2023, 10, 31))),
        ],
        today: today,
        contractsById: const <String, Contract>{},
        historyContracts: <Contract>[closed],
        historyInstallments: scheduleFor(closed),
      );
      final s = m.collectionsSeries(ChartPeriod.weeks8);
      expect(s[6].collected, rs(10000));
      // Due should be ₹10,000 (the installment fell in that week).
      expect(s[6].due, rs(10000));
      expect(SeriesTotals.of(s).rateBps, lessThanOrEqualTo(10000));
    });
  });

  group('Receivable breakdown', () {
    test('three rows; shares of the receivable, no overdue money counted twice '
        '(all current)', () {
      final today = d(2023, 11, 8);
      // ₹40,000 weekly ₹10,000 from Tue 14 Nov: nothing late.
      final c = makeContract(
        id: 'B',
        sanctioned: rs(40000),
        firstDue: d(2023, 11, 14),
      );
      final txs = <LedgerTransaction>[tx('B', rs(4000), d(2023, 11, 8))];
      final m = computePortfolio(
        projections: <ContractProjection>[project(c, txs, today)],
        allTransactions: txs,
        today: today,
        contractsById: <String, Contract>{c.id: c},
      );
      final b = m.receivableBreakdown;
      expect(m.sanctionedReceivable, rs(36000));
      expect(b.collectedThisMonth.amount, rs(4000));
      expect(b.overdue.amount, Money.zero);
      // 14, 21, 28 Nov and 5 Dec are all within 30 days: ₹36,000.
      expect(b.upcoming30.amount, rs(36000));
      expect(b.upcoming30.bps + b.overdue.bps, 10000);
      expect(b.collectedThisMonth.bps, 1111); // 4,000 / 36,000
    });

    test('Upcoming next 30 days leaves out the auto-extension rows of '
        'overdue money', () {
      final today = d(2023, 11, 8);
      // ₹40,000 weekly ₹10,000 from 31 Oct, ₹5,000 paid: 31 Oct partial
      // and 7 Nov missed → ₹15,000 overdue; outstanding ₹35,000.
      final c = makeContract(
        id: 'E',
        sanctioned: rs(40000),
        firstDue: d(2023, 10, 31),
      );
      final txs = <LedgerTransaction>[tx('E', rs(5000), d(2023, 11, 1))];
      final m = computePortfolio(
        projections: <ContractProjection>[project(c, txs, today)],
        allTransactions: txs,
        today: today,
        contractsById: <String, Contract>{c.id: c},
      );
      final b = m.receivableBreakdown;
      expect(m.sanctionedReceivable, rs(35000));
      expect(b.overdue.amount, rs(15000));
      // Not yet due: 14 Nov + 21 Nov = ₹20,000. The ₹15,000 extension
      // rows (28 Nov, 5 Dec) are the same overdue money re-planned.
      expect(b.upcoming30.amount, rs(20000));
      expect(
        b.upcoming30.amount + b.overdue.amount,
        lessThanOrEqualTo(m.sanctionedReceivable),
      );
    });
  });

  group('Calendar dots and legend', () {
    final today = d(2023, 11, 8);
    // P: ₹30,000 weekly Tue ₹10,000 from 31 Oct, paid ₹10,000 → 31 Oct
    // paid, 7 Nov overdue, 14 Nov pending (+ 21 Nov extension).
    final p = makeContract(
      id: 'P',
      sanctioned: rs(30000),
      firstDue: d(2023, 10, 31),
    );
    final txs = <LedgerTransaction>[tx('P', rs(10000), d(2023, 10, 31))];
    final m = computePortfolio(
      projections: <ContractProjection>[project(p, txs, today)],
      allTransactions: txs,
      today: today,
      contractsById: <String, Contract>{p.id: p},
    );

    test('dot per status: paid / open-not-late / overdue / empty', () {
      final oct31 = m.calendarBuckets(2023, 10)[30];
      expect(oct31.hasCollectedDot, isTrue);
      expect(oct31.hasPendingDot, isFalse);
      expect(oct31.hasOverdueDot, isFalse);
      final nov = m.calendarBuckets(2023, 11);
      expect(nov[6].hasOverdueDot, isTrue); // 7 Nov
      expect(nov[6].hasCollectedDot, isFalse);
      expect(nov[13].hasPendingDot, isTrue); // 14 Nov
      expect(nov[13].hasOverdueDot, isFalse);
      final empty = nov[8]; // 9 Nov
      expect(
        <bool>[empty.hasCollectedDot, empty.hasPendingDot, empty.hasOverdueDot],
        <bool>[false, false, false],
      );
      expect(m.dayItems(d(2023, 11, 9)), isEmpty);
    });

    test('legend totals equal the sum of the day lists', () {
      for (final (int y, int mo) in <(int, int)>[(2023, 10), (2023, 11)]) {
        final days = m.calendarBuckets(y, mo);
        final totals = CalendarTotals.of(days);
        final items = m.dueItemsBetween(
          CivilDate(y, mo, 1),
          CivilDate(y, mo, CivilDate.daysInMonth(y, mo)),
        );
        var paid = 0;
        var pending = 0;
        var overdue = 0;
        for (final i in items) {
          paid += i.paid.paise;
          if (i.isPaid) continue;
          if (i.status == RowStatus.overdue) {
            overdue += i.remaining.paise;
          } else if (!i.isExtension) {
            // Extension rows re-plan overdue money: listed (amber dot) but
            // not added to the Pending total.
            pending += i.remaining.paise;
          }
        }
        expect(totals.settled.paise, paid, reason: '$y-$mo settled');
        expect(totals.pending.paise, pending, reason: '$y-$mo pending');
        expect(totals.overdue.paise, overdue, reason: '$y-$mo overdue');
      }
    });
  });

  group('Overdue tracker grouping', () {
    final today = d(2023, 11, 8);
    // O: 3 rows missed (17, 24, 31 Oct, 7 Nov … from 17 Oct): days 22/15/8/1.
    final o = makeContract(
      id: 'O',
      loanNo: 3,
      sanctioned: rs(50000),
      firstDue: d(2023, 10, 17),
      disbursedOn: d(2023, 10, 10),
    );
    // R4: due Sat 4 Nov → exactly 4 days (critical). R3: Sun 5 Nov → 3 days
    // (recent, boundary).
    final r4 = makeContract(
      id: 'R4',
      loanNo: 4,
      sanctioned: rs(1000),
      installment: rs(1000),
      weekday: 6,
      firstDue: d(2023, 11, 4),
    );
    final r3 = makeContract(
      id: 'R3',
      loanNo: 5,
      sanctioned: rs(2000),
      installment: rs(2000),
      weekday: 7,
      firstDue: d(2023, 11, 5),
    );
    final m = computePortfolio(
      projections: <ContractProjection>[
        project(o, const <LedgerTransaction>[], today),
        project(r4, const <LedgerTransaction>[], today),
        project(r3, const <LedgerTransaction>[], today),
      ],
      allTransactions: const <LedgerTransaction>[],
      today: today,
      contractsById: <String, Contract>{
        for (final c in <Contract>[o, r4, r3]) c.id: c,
      },
    );
    final loans = groupOverdueByLoan(m.overdueList);

    test('one card per loan with the highest delay', () {
      expect(loans.map((OverdueLoan l) => l.contractId), <String>[
        'O',
        'R4',
        'R3',
      ]);
      final lo = loans.first;
      expect(lo.installmentCount, 4);
      expect(lo.daysOverdue, 22);
      expect(lo.oldestDueDate, d(2023, 10, 17));
      expect(lo.amount, rs(40000));
      expect(loans[1].daysOverdue, 4);
      expect(loans[2].daysOverdue, 3);
    });

    test('Critical (>3 days) and Recent filters and their totals', () {
      final all = OverdueSummary.of(loans, OverdueFilter.all);
      expect(all.allCount, 3);
      expect(all.criticalCount, 2);
      expect(all.recentCount, 1);
      expect(all.total, rs(43000));
      expect(all.total, m.totalOverdue);

      final crit = OverdueSummary.of(loans, OverdueFilter.critical);
      expect(crit.loans.map((OverdueLoan l) => l.contractId), <String>[
        'O',
        'R4',
      ]);
      expect(crit.total, rs(41000));
      expect(crit.maxDaysOverdue, 22);

      final recent = OverdueSummary.of(loans, OverdueFilter.recent);
      expect(recent.loans.single.contractId, 'R3');
      expect(recent.total, rs(2000));
      expect(recent.maxDaysOverdue, 3);
    });
  });

  group('Excess to review', () {
    final today = d(2023, 11, 8);
    PortfolioMetrics withHistory(List<Contract> h) => computePortfolio(
      projections: const <ContractProjection>[],
      allTransactions: const <LedgerTransaction>[],
      today: today,
      contractsById: const <String, Contract>{},
      historyContracts: h,
    );

    test('closed loan with a duplicate payment shows the excess', () {
      final m = withHistory(<Contract>[
        hist('D', sanctionedRs: 10000, paidRs: 12000, netRs: 9000),
      ]);
      expect(m.excessToReview.single.contractId, 'D');
      expect(m.excessToReview.single.excess, rs(2000));
      expect(m.excessToReview.single.status, ContractStatus.closed);
    });

    test('waiver-closed loan shows no false excess', () {
      final m = withHistory(<Contract>[
        hist(
          'WV',
          sanctionedRs: 10000,
          paidRs: 9000,
          waivedRs: 1000,
          netRs: 9000,
        ),
      ]);
      expect(m.excessToReview, isEmpty);
    });

    test('rolled-over loan with a late payment shows it', () {
      // ₹30,000: ₹18,000 cash + ₹12,000 settled, then ₹2,000 arrives late.
      final m = withHistory(<Contract>[
        hist(
          'RO',
          sanctionedRs: 30000,
          paidRs: 32000,
          settledRs: 12000,
          netRs: 27000,
          status: ContractStatus.rolledOver,
        ),
      ]);
      expect(m.excessToReview.single.excess, rs(2000));
      expect(m.excessToReview.single.status, ContractStatus.rolledOver);
      expect(m.totalCollected, rs(20000));
    });

    test('active loan over-collected shows the excess', () {
      final c = makeContract(
        id: 'AX',
        sanctioned: rs(10000),
        installment: rs(10000),
      );
      final txs = <LedgerTransaction>[
        tx('AX', rs(10000), d(2023, 10, 31)),
        tx('AX', rs(1500), d(2023, 10, 31)),
      ];
      final m = computePortfolio(
        projections: <ContractProjection>[project(c, txs, today)],
        allTransactions: txs,
        today: today,
        contractsById: <String, Contract>{c.id: c},
      );
      expect(m.excessToReview.single.excess, rs(1500));
    });
  });
}
