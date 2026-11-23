import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import '../../features/borrowers/borrower_test_support.dart';
import 'ledger_fixtures.dart';

void main() {
  final seed = aggregatesFixture();
  final c1 = seed.contracts[0];
  final c2 = seed.contracts[1];
  final c3 = seed.contracts[2];

  List<LedgerTransaction> txsOf(Contract c) => <LedgerTransaction>[
    for (final t in seed.transactions)
      if (t.contractId == c.id) t,
  ];

  ContractProjection p(Contract c) => project(c, txsOf(c), kToday);

  group('contractStanding / dueWithinWeek', () {
    test('due today, overdue, on track', () {
      expect(contractStanding(p(c1)), Standing.dueToday);
      expect(contractStanding(p(c2)), Standing.overdue);
      final later = contractFor(
        'b9',
        'c9',
        loanNo: 9,
        sanctionedRs: 1000,
        installmentRs: 500,
        firstDue: d(2023, 11, 20),
        weekday: 1,
      );
      expect(contractStanding(p(later)), Standing.onTrack);
      expect(dueWithinWeek(p(later), kToday), isFalse);
    });

    test('a row 6 days ahead is this week, 7 days ahead is not', () {
      ContractProjection at(CivilDate due) => p(
        contractFor(
          'b9',
          'c9',
          loanNo: 9,
          sanctionedRs: 1000,
          installmentRs: 1000,
          firstDue: due,
          weekday: due.weekday,
        ),
      );
      expect(dueWithinWeek(at(d(2023, 11, 13)), kToday), isTrue);
      expect(dueWithinWeek(at(d(2023, 11, 14)), kToday), isFalse);
    });
  });

  group('borrowerListStats', () {
    test('empty → none', () {
      final s = borrowerListStats(const <ContractProjection>[], kToday);
      expect(s.standing, Standing.none);
      expect(s.activeCount, 0);
      expect(s.outstanding, Money.zero);
      expect(s.dueThisWeek, isFalse);
    });

    test('overdue wins over due today; outstanding summed', () {
      final s = borrowerListStats(<ContractProjection>[p(c1), p(c2)], kToday);
      expect(s.standing, Standing.overdue);
      expect(s.maxDaysOverdue, 7);
      expect(s.activeCount, 2);
      expect(s.outstanding, rs(135000));
      expect(s.dueThisWeek, isTrue);
    });

    test('due today only → dueToday; on track only → onTrack', () {
      expect(
        borrowerListStats(<ContractProjection>[p(c1)], kToday).standing,
        Standing.dueToday,
      );
      final later = contractFor(
        'b9',
        'c9',
        loanNo: 9,
        sanctionedRs: 1000,
        installmentRs: 500,
        firstDue: d(2023, 11, 20),
        weekday: 1,
      );
      expect(
        borrowerListStats(<ContractProjection>[p(later)], kToday).standing,
        Standing.onTrack,
      );
    });
  });

  group('summarizeBorrower (2 active + 1 rolled over)', () {
    final summary = summarizeBorrower(
      active: <ContractProjection>[p(c1), p(c2)],
      contracts: <Contract>[c3, c1], // c1 repeats: de-duplicated
      transactions: <LedgerTransaction>[
        ...seed.transactions,
        seed.transactions.first, // repeat: de-duplicated
        txFor(c1, 't-resched', 0, d(2023, 11, 3), type: TxType.reschedule),
      ],
      today: kToday,
    );

    test('aggregates match the hand-computed figures', () {
      expect(summary.activeExposure, rs(135000));
      expect(summary.lifetimeLent, rs(180000));
      expect(summary.collected, rs(45000));
      expect(summary.stats.standing, Standing.overdue);
    });

    test('active newest loan first; closed lists the rolled-over one', () {
      expect(
        summary.active.map((ContractProjection x) => x.contract.loanNo),
        <int>[5, 4],
      );
      expect(summary.closed.map((Contract c) => c.id), <String>['c3']);
      expect(summary.contractsById.keys, containsAll(<String>['c1', 'c2']));
    });

    test('ledger newest first, reschedule rows dropped, balance after', () {
      final ids = summary.ledger.map((LedgerEntry e) => e.tx.id).toList();
      expect(ids, isNot(contains('t-resched')));
      expect(ids.first, 't-c2-rev');
      expect(ids.length, 6);
      Money? bal(String id) => summary.ledger
          .firstWhere((LedgerEntry e) => e.tx.id == id)
          .balanceAfter;
      expect(bal('t-c1-disb'), rs(100000));
      expect(bal('t-c2-p2'), rs(43000));
      expect(bal('t-c2-rev'), rs(45000));
      expect(bal('t-c3-p1'), Money.zero);
    });

    test('recent receipts: payments only, newest first, with balance', () {
      expect(summary.recentReceipts.map((LedgerEntry e) => e.tx.id), <String>[
        't-c2-p2',
        't-c1-p1',
        't-c2-p1',
        't-c3-p1',
      ]);
      expect(
        summary.recentReceipts.map((LedgerEntry e) => e.balanceAfter),
        <Money>[rs(43000), rs(90000), rs(45000), Money.zero],
      );
    });
  });

  test('recent receipts are capped at 10', () {
    final many = <LedgerTransaction>[
      for (var i = 1; i <= 12; i++) txFor(c1, 't-$i', 100, d(2023, 10, i + 1)),
    ];
    final s = summarizeBorrower(
      active: <ContractProjection>[project(c1, many, kToday)],
      contracts: const <Contract>[],
      transactions: many,
      today: kToday,
    );
    expect(s.recentReceipts.length, BorrowerSummary.recentReceiptsLimit);
    expect(s.recentReceipts.first.tx.id, 't-12');
    expect(s.ledger.length, 12);
  });

  test('unknown contract → no balance; cancelled not lent; '
      'reversal of a settlement is not a collection', () {
    final cancelled = c3.copyWith(id: 'cx', status: ContractStatus.cancelled);
    final settle = txFor(
      c3,
      't-set',
      500,
      d(2023, 10, 1),
      type: TxType.rolloverSettlement,
    );
    final revSettle = txFor(
      c3,
      't-rev-set',
      500,
      d(2023, 10, 2),
      type: TxType.reversal,
      reversesTxId: 't-set',
    );
    final orphanRev = txFor(
      c3,
      't-rev-orphan',
      100,
      d(2023, 10, 3),
      type: TxType.reversal,
    );
    final s = summarizeBorrower(
      active: const <ContractProjection>[],
      contracts: <Contract>[cancelled],
      transactions: <LedgerTransaction>[settle, revSettle, orphanRev],
      today: kToday,
    );
    expect(s.lifetimeLent, Money.zero);
    expect(s.closed, isEmpty);
    // Only the orphan reversal (assumed to reverse a payment) counts.
    expect(s.collected, rs(-100));
    expect(s.ledger.every((LedgerEntry e) => e.balanceAfter == null), isTrue);
    expect(s.stats.standing, Standing.none);
  });

  test('closed contract appears in closed; balances floor at zero', () {
    final closed = c3.copyWith(id: 'cc', status: ContractStatus.closed);
    final over = txFor(closed, 't-over', 40000, d(2023, 9, 30));
    final s = summarizeBorrower(
      active: const <ContractProjection>[],
      contracts: <Contract>[closed],
      transactions: <LedgerTransaction>[over],
      today: kToday,
    );
    expect(s.closed.single.id, 'cc');
    expect(s.ledger.single.balanceAfter, Money.zero);
  });
}
