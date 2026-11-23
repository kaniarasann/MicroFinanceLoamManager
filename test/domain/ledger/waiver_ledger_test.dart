import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import 'ledger_fixtures.dart';

/// ₹30,000 weekly 3 × ₹10,000 (31 Oct, 7 Nov, 14 Nov). ₹20,000 paid; the
/// owner closes on 7 Nov for ₹8,000 cash + ₹2,000 waived.
void main() {
  final c = makeContract(
    sanctioned: rs(30000),
    upfrontInput: 0,
    status: ContractStatus.closed,
  );
  final today = d(2023, 11, 7);
  final base = <LedgerTransaction>[
    tx('c1', rs(30000), d(2023, 10, 24), type: TxType.disbursement, id: 'd'),
    tx('c1', rs(20000), d(2023, 10, 31), id: 'p1'),
  ];
  final pay = tx('c1', rs(8000), today, id: 'p2');
  final waiver = tx('c1', rs(2000), today, type: TxType.waiver, id: 'w1');
  final waiverRev = tx(
    'c1',
    rs(2000),
    today,
    type: TxType.reversal,
    id: 'r1',
    reversesTxId: 'w1',
    noMode: true, // a reversal copies the waiver's (null) mode
  );
  final closedTxs = <LedgerTransaction>[...base, pay, waiver];

  PortfolioMetrics metrics(List<LedgerTransaction> txs, Contract k) =>
      computePortfolio(
        projections: <ContractProjection>[project(k, txs, today)],
        allTransactions: txs,
        today: today,
        contractsById: <String, Contract>{k.id: k},
      );

  test('the paid pool includes the waiver: every row paid, settled', () {
    expect(paidPool('c1', closedTxs), rs(30000));
    final p = project(c, closedTxs, today);
    expect(p.totalPaid, rs(30000));
    expect(p.totalWaived, rs(2000));
    expect(p.outstanding, Money.zero);
    expect(p.excess, Money.zero);
    expect(p.isSettled, isTrue);
    expect(p.rows.every((ProjectedRow r) => r.status == RowStatus.paid), true);
    // The last row was completed by the waiver (no mode).
    final settled = rowSettlements(p, closedTxs);
    expect(settled['c1-i3'], RowSettlement(clearedOn: today));
  });

  test('a waiver reversal reopens the balance and nets totalWaived', () {
    final txs = <LedgerTransaction>[...closedTxs, waiverRev];
    final p = project(c, txs, today);
    expect(p.totalWaived, Money.zero);
    expect(p.outstanding, rs(2000));
    expect(waivedTotal('c1', txs), Money.zero);
  });

  test('cash metrics exclude waivers and waiver reversals', () {
    final m = metrics(closedTxs, c);
    expect(m.totalCollected, rs(28000));
    expect(m.todayDue.received, rs(8000));
    // ₹20,000 was paid on 31 Oct; November cash is the ₹8,000 only.
    expect(m.receivableBreakdown.collectedThisMonth.amount, rs(8000));
    expect(m.totalWaived, rs(2000));

    final reversed = metrics(<LedgerTransaction>[...closedTxs, waiverRev], c);
    expect(reversed.totalCollected, rs(28000));
    expect(reversed.todayDue.received, rs(8000));
    expect(reversed.totalWaived, Money.zero);
  });

  test('the chart and calendar collected exclude waivers', () {
    final m = metrics(<LedgerTransaction>[...closedTxs, waiverRev], c);
    final week = m
        .collectionsSeries(ChartPeriod.weeks8)
        .firstWhere((CollectionBucket b) => b.isCurrent);
    expect(week.collected, rs(8000));
    final day = m.calendarBuckets(2023, 11)[6];
    expect(day.collected, rs(8000));
    expect(day.collectedCount, 1);
  });

  test('borrower Collected and receipts exclude the waiver', () {
    final s = summarizeBorrower(
      active: const <ContractProjection>[],
      contracts: <Contract>[c],
      transactions: closedTxs,
      today: today,
    );
    expect(s.collected, rs(28000));
    expect(s.recentReceipts.map((LedgerEntry e) => e.tx.id), <String>[
      'p2',
      'p1',
    ]);
    final w = s.ledger.firstWhere((LedgerEntry e) => e.tx.id == 'w1');
    expect(w.balanceAfter, Money.zero);

    final undone = summarizeBorrower(
      active: const <ContractProjection>[],
      contracts: <Contract>[c],
      transactions: <LedgerTransaction>[...closedTxs, waiverRev],
      today: today,
    );
    expect(undone.collected, rs(28000));
    expect(undone.ledger.first.balanceAfter, rs(2000));
  });

  group('a reversal whose original is outside the loaded window', () {
    // Only the reversals are loaded, not the docs they reverse.
    final orphanWaiverRev = tx(
      'c1',
      rs(2000),
      today,
      type: TxType.reversal,
      id: 'r-w',
      reversesTxId: 'w-old',
      noMode: true,
    );
    final orphanPaymentRev = tx(
      'c1',
      rs(3000),
      today,
      type: TxType.reversal,
      id: 'r-p',
      reversesTxId: 'p-old',
      mode: PaymentMode.cash,
    );

    test('with no mode (a waiver reversal) moves no cash', () {
      final m = metrics(<LedgerTransaction>[...base, orphanWaiverRev], c);
      expect(m.totalCollected, rs(20000));
      expect(m.todayDue.received, Money.zero);
      final s = summarizeBorrower(
        active: const <ContractProjection>[],
        contracts: <Contract>[c],
        transactions: <LedgerTransaction>[...base, orphanWaiverRev],
        today: today,
      );
      expect(s.collected, rs(20000));
    });

    test('with a mode (a payment reversal) still reduces cash', () {
      final m = metrics(<LedgerTransaction>[...base, orphanPaymentRev], c);
      expect(m.totalCollected, rs(17000));
      final s = summarizeBorrower(
        active: const <ContractProjection>[],
        contracts: <Contract>[c],
        transactions: <LedgerTransaction>[...base, orphanPaymentRev],
        today: today,
      );
      expect(s.collected, rs(17000));
    });
  });

  group('the payment and waiver of one close tie on every timestamp', () {
    // Same paidOn and clientRecordedAt (one batch); try both id orders.
    for (final ids in <(String, String)>[
      ('a-pay', 'z-wav'),
      ('z-pay', 'a-wav'),
    ]) {
      test('cash settles first, the waiver last (ids ${ids.$1}/${ids.$2})', () {
        final p2 = tx(
          'c1',
          rs(8000),
          today,
          id: ids.$1,
          mode: PaymentMode.cash,
        );
        final w = tx('c1', rs(2000), today, type: TxType.waiver, id: ids.$2);
        final txs = <LedgerTransaction>[...base, w, p2];

        expect(compareTxChronological(p2, w), lessThan(0));
        expect(compareTxChronological(w, p2), greaterThan(0));

        // Row 2 (₹10,000 due 7 Nov) is cleared by the ₹8,000 cash; the
        // waiver completes row 3, so it carries no mode.
        final settled = rowSettlements(project(c, txs, today), txs);
        expect(settled['c1-i3'], RowSettlement(clearedOn: today));

        final s = summarizeBorrower(
          active: const <ContractProjection>[],
          contracts: <Contract>[c],
          transactions: txs,
          today: today,
        );
        expect(s.ledger.first.tx.id, ids.$2, reason: 'newest = the waiver');
        expect(s.ledger.first.balanceAfter, Money.zero);
        expect(s.ledger[1].tx.id, ids.$1);
        expect(s.ledger[1].balanceAfter, rs(2000));
      });
    }

    test('falls back to id for two same-type docs', () {
      final a = tx('c1', rs(1), today, id: 'a');
      final b = tx('c1', rs(1), today, id: 'b');
      expect(compareTxChronological(a, b), lessThan(0));
    });
  });
}
