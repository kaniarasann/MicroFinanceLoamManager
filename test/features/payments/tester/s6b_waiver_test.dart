import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/payments/application/payment_providers.dart';
import 'package:nordic_ledger/features/payments/data/payment_repository.dart';

import '../payment_test_support.dart';

/// Tester S6 Task 12b: close-with-waiver on a ₹1,00,000 weekly loan
/// (₹93,000 disbursed, 10 × ₹10,000 from 31 Oct 2023) with ₹60,000 already
/// paid, so the outstanding is ₹40,000. "Today" is Tue 7 Nov 2023.
void main() {
  final today = d(2023, 11, 7);
  late FakeFirebaseFirestore db;
  late PaymentRepository repo;

  Future<void> seed({ContractStatus status = ContractStatus.active}) async {
    final c = makeContract(status: status).copyWith(totalPaid: rs(60000));
    await seedLoan(
      db,
      c,
      txs: <LedgerTransaction>[
        tx(
          'c1',
          rs(93000),
          d(2023, 10, 24),
          type: TxType.disbursement,
          id: 'tx-d',
        ),
        tx('c1', rs(60000), d(2023, 10, 31), id: 'tx-p1'),
      ],
    );
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = PaymentRepository(firestore: db, clock: clockAt(today));
    await seed();
  });

  Future<CloseWithWaiverCommand> close({
    int cashRs = 38500,
    int waiverRs = 1500,
    String reason = 'Early closure discount',
    Role? role = Role.owner,
    PaymentMode? mode = PaymentMode.cash,
  }) async => CloseWithWaiverCommand(
    cid: kCid,
    snapshot: await readSnapshot(db, 'c1'),
    cashAmount: rs(cashRs),
    waiverAmount: rs(waiverRs),
    reason: reason,
    paidOn: today,
    mode: mode,
    actor: kActor,
    role: role,
  );

  Future<PaymentWriteResult> reverse(String id) async => repo.reversePayment(
    ReversePaymentCommand(
      cid: kCid,
      snapshot: await readSnapshot(db, 'c1'),
      transactionId: id,
      reason: 'Discount withdrawn',
      today: d(2023, 11, 8),
      actor: kActor,
    ),
  );

  /// Expects [cmd] to fail with [matcher] and nothing to be written.
  Future<void> expectRejected(
    Future<CloseWithWaiverCommand> cmd,
    Matcher matcher,
  ) async {
    await expectLater(repo.closeWithWaiver(await cmd), throwsA(matcher));
    final c = await rawContract(db, 'c1');
    expect(c['status'], 'active');
    expect(c['totalPaidPaise'], 6000000);
    expect(c['totalWaivedPaise'] ?? 0, 0);
    expect(await rawDocs(db, 'transactions', 'c1'), hasLength(2));
  }

  Matcher validation(String field) => isA<ValidationFailure>().having(
    (ValidationFailure f) => f.field,
    'field',
    field,
  );

  group('happy', () {
    test(
      'cash ₹38,500 + waiver ₹1,500 = outstanding closes the loan',
      () async {
        final r = await repo.closeWithWaiver(await close());
        expect(r.paymentId, isNotNull);
        final c = await rawContract(db, 'c1');
        expect(c['status'], 'closed');
        expect(c['closedAt'], isNotNull);
        expect(c['totalPaidPaise'], 9850000);
        expect(c['totalWaivedPaise'], 150000);
        final txs = await rawDocs(db, 'transactions', 'c1');
        final w = txs.singleWhere(
          (Map<String, dynamic> t) => t['id'] == r.waiverId,
        );
        expect(w['type'], 'waiver');
        expect(w['note'], 'Early closure discount');
        expect(w['mode'], isNull);
        expect(w['recordedByName'], 'Ravi');
        expect(w['clientRecordedAt'], isNotNull);

        final snap = await readSnapshot(db, 'c1');
        final p = project(snap.contract, snap.transactions, today);
        expect(p.outstanding, Money.zero);
        expect(p.totalWaived, rs(1500));
        expect(p.excess, Money.zero);
        expect(
          p.rows.every((ProjectedRow r) => r.status == RowStatus.paid),
          isTrue,
        );
      },
    );

    test(
      'cash ₹0: a full write-off writes only the waiver and closes',
      () async {
        final r = await repo.closeWithWaiver(
          await close(cashRs: 0, waiverRs: 40000, mode: null),
        );
        expect(r.paymentId, isNull);
        final txs = await rawDocs(db, 'transactions', 'c1');
        expect(txs, hasLength(3));
        expect(
          txs.where((Map<String, dynamic> t) => t['type'] == 'payment'),
          hasLength(1),
          reason: 'only the seeded ₹60,000 payment',
        );
        final c = await rawContract(db, 'c1');
        expect(c['status'], 'closed');
        expect(c['totalPaidPaise'], 6000000);
        expect(c['totalWaivedPaise'], 4000000);
      },
    );

    test('receipt with cash: received sentence + "(₹W waived)"', () {
      expect(
        receiptMessage(
          amount: rs(38500),
          borrowerName: 'Anita Sharma',
          loanNo: 1,
          paidOn: today,
          mode: PaymentMode.cash,
          balance: Money.zero,
          companyName: 'Sri Lakshmi Finance',
          waived: rs(1500),
        ),
        'Received ₹38,500 from Anita Sharma for Loan #01 on 7 Nov 2023 via '
        'Cash. Loan #01 closed (₹1,500 waived). — Sri Lakshmi Finance',
      );
    });

    test('receipt with no cash: no "Received" sentence, no balance', () {
      final m = receiptMessage(
        amount: Money.zero,
        borrowerName: 'Anita Sharma',
        loanNo: 1,
        paidOn: today,
        mode: null,
        balance: Money.zero,
        companyName: 'Sri Lakshmi Finance',
        waived: rs(40000),
      );
      expect(m, 'Loan #01 closed (₹40,000 waived). — Sri Lakshmi Finance');
      expect(m, isNot(contains('Received')));
      expect(m, isNot(contains('Balance')));
    });
  });

  group('failure', () {
    test('cash + waiver below the outstanding is rejected', () async {
      await expectRejected(close(cashRs: 38000), validation(waiverAmountField));
    });

    test('cash + waiver above the outstanding is rejected', () async {
      await expectRejected(close(cashRs: 39000), validation(waiverAmountField));
    });

    test('W = 0 (cash = outstanding) is rejected', () async {
      await expectRejected(
        close(cashRs: 40000, waiverRs: 0),
        validation(waiverAmountField),
      );
    });

    test('an empty or whitespace reason is rejected', () async {
      await expectRejected(close(reason: ''), validation(waiverReasonField));
      await expectRejected(
        close(reason: ' \n '),
        validation(waiverReasonField),
      );
    });

    test('cash > 0 with no mode is rejected', () async {
      await expectRejected(close(mode: null), validation(waiverModeField));
    });

    test(
      'a collector (or unknown role) calling closeWithWaiver is rejected',
      () async {
        await expectRejected(
          close(role: Role.collector),
          isA<PermissionDeniedFailure>(),
        );
        await expectRejected(close(role: null), isA<PermissionDeniedFailure>());
      },
    );

    for (final status in <ContractStatus>[
      ContractStatus.closed,
      ContractStatus.rolledOver,
    ]) {
      test('a waiver on a ${status.name} contract is rejected', () async {
        db = FakeFirebaseFirestore();
        repo = PaymentRepository(firestore: db, clock: clockAt(today));
        await seed(status: status);
        await expectLater(
          repo.closeWithWaiver(await close()),
          throwsA(validation(LedgerFields.amount)),
        );
        final c = await rawContract(db, 'c1');
        expect(c['status'], status.name);
        expect(await rawDocs(db, 'transactions', 'c1'), hasLength(2));
      });
    }
  });

  group('edge', () {
    test(
      'reversing the waiver reopens: totalWaived 0, totalPaid untouched',
      () async {
        final w = await repo.closeWithWaiver(await close());
        final r = await reverse(w.waiverId);
        expect(r.closed, isFalse);
        expect(r.balanceAfter, rs(1500));
        final c = await rawContract(db, 'c1');
        expect(c['status'], 'active');
        expect(c['closedAt'], isNull);
        expect(c['totalWaivedPaise'], 0);
        expect(c['totalPaidPaise'], 9850000);
        final snap = await readSnapshot(db, 'c1');
        expect(snap.outstanding, rs(1500));
        final p = project(snap.contract, snap.transactions, d(2023, 11, 8));
        expect(p.totalWaived, Money.zero);
        for (final doc in <Map<String, dynamic>>[
          ...await rawDocs(db, 'installments', 'c1'),
          ...await rawDocs(db, 'transactions', 'c1'),
        ]) {
          expect(doc['contractActive'], isTrue, reason: '${doc['id']}');
        }
      },
    );

    test('a second reversal of the same waiver is blocked', () async {
      final w = await repo.closeWithWaiver(await close());
      await reverse(w.waiverId);
      await expectLater(
        reverse(w.waiverId),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure f) => f.message,
            'message',
            'This waiver has already been reversed.',
          ),
        ),
      );
      final c = await rawContract(db, 'c1');
      expect(c['totalWaivedPaise'], 0);
      expect(c['totalPaidPaise'], 9850000);
      expect(
        (await rawDocs(
          db,
          'transactions',
          'c1',
        )).where((Map<String, dynamic> t) => t['type'] == 'reversal'),
        hasLength(1),
      );
    });

    test(
      'after a waiver reversal the loan can be re-closed with a new waiver',
      () async {
        final w = await repo.closeWithWaiver(await close());
        await reverse(w.waiverId);
        await repo.closeWithWaiver(
          await close(cashRs: 500, waiverRs: 1000, reason: 'Second offer'),
        );
        final c = await rawContract(db, 'c1');
        expect(c['status'], 'closed');
        expect(c['totalWaivedPaise'], 100000);
        expect(c['totalPaidPaise'], 9900000);
      },
    );

    /// Portfolio from the docs the repository actually wrote.
    Future<PortfolioMetrics> portfolio(CivilDate on) async {
      final snap = await readSnapshot(db, 'c1');
      return computePortfolio(
        projections: <ContractProjection>[
          project(snap.contract, snap.transactions, on),
        ],
        allTransactions: snap.transactions,
        today: on,
        contractsById: <String, Contract>{'c1': snap.contract},
      );
    }

    test(
      'portfolio cash metrics exclude the waiver (and its reversal)',
      () async {
        final w = await repo.closeWithWaiver(await close());
        final m = await portfolio(today);
        expect(m.totalCollected, rs(98500));
        expect(m.todayDue.received, rs(38500));
        expect(m.receivableBreakdown.collectedThisMonth.amount, rs(38500));
        final week = m
            .collectionsSeries(ChartPeriod.weeks8)
            .firstWhere((CollectionBucket b) => b.isCurrent);
        expect(week.collected, rs(38500));
        expect(m.calendarBuckets(2023, 11)[6].collected, rs(38500));
        expect(m.totalWaived, rs(1500));

        await reverse(w.waiverId);
        final after = await portfolio(today);
        expect(after.totalCollected, rs(98500), reason: 'cash unchanged');
        expect(after.todayDue.received, rs(38500));
        expect(after.totalWaived, Money.zero);
      },
    );

    test('borrower summary collected excludes the waiver', () async {
      await repo.closeWithWaiver(await close());
      final snap = await readSnapshot(db, 'c1');
      final s = summarizeBorrower(
        active: const <ContractProjection>[],
        contracts: <Contract>[snap.contract],
        transactions: snap.transactions,
        today: today,
      );
      expect(s.collected, rs(98500));
      expect(
        s.recentReceipts.any((LedgerEntry e) => e.tx.type == TxType.waiver),
        isFalse,
      );
      // Newest first: whichever of the pair sorts last ends at ₹0.
      expect(s.ledger.first.balanceAfter, Money.zero);
    });

    // Bug 2 (low): the payment and the waiver of one close share paidOn and
    // recordedAt, so `_chronological` falls back to the random uuid. The
    // waiver lands before the payment about half the time, and the ledger
    // then reads "Waived ₹1,500 → ₹38,500" followed by "₹38,500 → ₹0".
    test(
      'borrower ledger: the waiver sorts after the cash of the same close',
      () async {
        for (var i = 0; i < 8; i++) {
          db = FakeFirebaseFirestore();
          repo = PaymentRepository(firestore: db, clock: clockAt(today));
          await seed();
          await repo.closeWithWaiver(await close());
          final snap = await readSnapshot(db, 'c1');
          final s = summarizeBorrower(
            active: const <ContractProjection>[],
            contracts: <Contract>[snap.contract],
            transactions: snap.transactions,
            today: today,
          );
          expect(s.ledger.first.tx.type, TxType.waiver, reason: 'run $i');
          expect(s.ledger.first.balanceAfter, Money.zero);
        }
      },
    );
  });
}
