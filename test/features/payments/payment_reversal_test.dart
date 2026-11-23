import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/firebase/chunked_batch.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/payments/data/payment_repository.dart';

import 'payment_test_support.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PaymentRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = PaymentRepository(firestore: db, clock: clockAt(d(2023, 11, 7)));
  });

  ReversePaymentCommand reverse(
    ContractSnapshot snap,
    String txId, {
    String reason = 'Duplicate entry',
  }) => ReversePaymentCommand(
    cid: kCid,
    snapshot: snap,
    transactionId: txId,
    reason: reason,
    today: d(2023, 11, 7),
    actor: kActor,
  );

  RecordPaymentCommand pay(ContractSnapshot snap, int rupees) =>
      RecordPaymentCommand(
        cid: kCid,
        snapshot: snap,
        amount: rs(rupees),
        paidOn: d(2023, 11, 7),
        mode: PaymentMode.cash,
        actor: kActor,
      );

  test(
    'reversal reopens a closed loan and flips contractActive back',
    () async {
      final l = smallLoan(paidRs: 20000);
      await seedLoan(db, l.contract, txs: l.txs);
      final paid = await repo.recordPayment(
        pay(await readSnapshot(db, 'c1'), 10000),
      );
      expect((await rawContract(db, 'c1'))['status'], 'closed');

      final r = await repo.reversePayment(
        reverse(await readSnapshot(db, 'c1'), paid.id),
      );
      final t = (await db.doc('companies/$kCid/transactions/${r.id}').get())
          .data()!;
      expect(t['type'], 'reversal');
      expect(t['amountPaise'], 1000000);
      expect(t['reversesTxId'], paid.id);
      expect(t['note'], 'Duplicate entry');
      expect(t['recordedBy'], kOwnerUid);
      expect(t['contractActive'], isTrue);

      final c = await rawContract(db, 'c1');
      expect(c['status'], 'active');
      expect(c['closedAt'], isNull);
      expect(c['totalPaidPaise'], 2000000);
      for (final doc in <Map<String, dynamic>>[
        ...await rawDocs(db, 'installments', 'c1'),
        ...await rawDocs(db, 'transactions', 'c1'),
      ]) {
        expect(doc['contractActive'], isTrue, reason: '${doc['id']}');
      }
      expect(r.balanceAfter, rs(10000));
    },
  );

  test('reversing on an active loan keeps it active', () async {
    final l = smallLoan(paidRs: 10000);
    await seedLoan(db, l.contract, txs: l.txs);
    await repo.reversePayment(reverse(await readSnapshot(db, 'c1'), 'tx-p1'));
    final c = await rawContract(db, 'c1');
    expect(c['status'], 'active');
    expect(c['totalPaidPaise'], 0);
  });

  test('a payment cannot be reversed twice', () async {
    final l = smallLoan(paidRs: 10000);
    await seedLoan(db, l.contract, txs: l.txs);
    await repo.reversePayment(reverse(await readSnapshot(db, 'c1'), 'tx-p1'));
    await expectLater(
      repo.reversePayment(reverse(await readSnapshot(db, 'c1'), 'tx-p1')),
      throwsA(
        isA<ValidationFailure>().having(
          (ValidationFailure f) => f.message,
          'message',
          'This payment has already been reversed.',
        ),
      ),
    );
    final reversals = (await rawDocs(
      db,
      'transactions',
      'c1',
    )).where((Map<String, dynamic> t) => t['type'] == 'reversal');
    expect(reversals, hasLength(1));
  });

  test('a reason is required; only payments can be reversed', () async {
    final l = smallLoan(paidRs: 10000);
    await seedLoan(db, l.contract, txs: l.txs);
    final snap = await readSnapshot(db, 'c1');
    await expectLater(
      repo.reversePayment(reverse(snap, 'tx-p1', reason: '   ')),
      throwsA(isA<ValidationFailure>()),
    );
    await expectLater(
      repo.reversePayment(reverse(snap, 'tx-d')),
      throwsA(isA<NotFoundFailure>()),
    );
  });

  test('closing a 366-installment daily loan spills the flips into '
      'follow-up batches and flips every doc', () async {
    final c = makeContract(
      sanctioned: rs(366),
      installment: rs(1),
      frequency: Frequency.daily,
      weekday: null,
      upfrontInput: 0,
    );
    final txs = <LedgerTransaction>[
      tx('c1', rs(366), d(2023, 10, 24), type: TxType.disbursement, id: 'tx-d'),
      for (var i = 0; i < 100; i++)
        tx('c1', rs(1), d(2023, 10, 31), id: 'tx-p$i'),
    ];
    await seedLoan(db, c.copyWith(totalPaid: rs(100)), txs: txs);
    final snap = await readSnapshot(db, 'c1');
    expect(snap.installments, hasLength(366));

    // 2 money ops + 366 + 101 + 1 (new tx written inactive) flips.
    final probe = ChunkedBatch(db)..primary((_) {}, ops: 2);
    for (var i = 0; i < 467; i++) {
      probe.spill((_) {});
    }
    expect(probe.batchCount, 2);

    final r = await repo.recordPayment(pay(snap, 266));
    expect(r.closed, isTrue);
    final inst = await rawDocs(db, 'installments', 'c1');
    final all = await rawDocs(db, 'transactions', 'c1');
    expect(all, hasLength(102));
    for (final doc in <Map<String, dynamic>>[...inst, ...all]) {
      expect(doc['contractActive'], isFalse, reason: '${doc['id']}');
    }
    expect((await rawContract(db, 'c1'))['status'], 'closed');
  });
}
