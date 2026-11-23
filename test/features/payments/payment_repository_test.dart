import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
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

  RecordPaymentCommand pay(
    ContractSnapshot snap,
    int rupees, {
    PaymentMode mode = PaymentMode.upi,
    String? reference = ' UTR 4471 ',
    String? note = '  ',
  }) => RecordPaymentCommand(
    cid: kCid,
    snapshot: snap,
    amount: rs(rupees),
    paidOn: d(2023, 11, 7),
    mode: mode,
    reference: reference,
    note: note,
    actor: kActor,
  );

  test('payment batch: exact transaction and contract fields', () async {
    final l = smallLoan(paidRs: 10000);
    await seedLoan(db, l.contract, txs: l.txs);
    final r = await repo.recordPayment(pay(await readSnapshot(db, 'c1'), 4000));
    expect(r.outcome, WriteOutcome.synced);
    expect(r.closed, isFalse);
    expect(r.balanceAfter, rs(16000));

    final t = (await db.doc('companies/$kCid/transactions/${r.id}').get())
        .data()!;
    expect(t['contractId'], 'c1');
    expect(t['type'], 'payment');
    expect(t['amountPaise'], 400000);
    expect(t['paidOn'], '2023-11-07');
    expect(t['mode'], 'upi');
    expect(t['reference'], 'UTR 4471');
    expect(t['note'], isNull);
    expect(t['contractActive'], isTrue);
    expect(t['borrowerId'], 'b-c1');
    expect(t['borrowerName'], 'Anita Sharma');
    expect(t['loanNo'], 1);
    expect(t['reversesTxId'], isNull);
    expect(t['recordedBy'], kOwnerUid);
    expect(t['recordedByName'], 'Ravi');
    expect(t['recordedAt'], isA<Timestamp>());
    expect(t['clientRecordedAt'], isA<Timestamp>());
    expect(t['deviceId'], 'dev-1');

    final c = await rawContract(db, 'c1');
    expect(c['totalPaidPaise'], 1400000);
    expect(c['lastPaymentOn'], '2023-11-07');
    expect(c['updatedAt'], isA<Timestamp>());
    expect(c['status'], 'active');
    expect(c['closedAt'], isNull);
  });

  test('a partial payment leaves the contract active and docs live', () async {
    final l = smallLoan();
    await seedLoan(db, l.contract, txs: l.txs);
    await repo.recordPayment(pay(await readSnapshot(db, 'c1'), 6000));
    expect((await rawContract(db, 'c1'))['status'], 'active');
    for (final i in await rawDocs(db, 'installments', 'c1')) {
      expect(i['contractActive'], isTrue);
    }
  });

  test('the final payment closes the loan and flips contractActive', () async {
    final l = smallLoan(paidRs: 20000);
    await seedLoan(db, l.contract, txs: l.txs);
    final r = await repo.recordPayment(
      pay(await readSnapshot(db, 'c1'), 10000, mode: PaymentMode.cash),
    );
    expect(r.closed, isTrue);
    expect(r.balanceAfter, rs(0));
    final c = await rawContract(db, 'c1');
    expect(c['status'], 'closed');
    expect(c['closedAt'], isA<Timestamp>());
    expect(c['totalPaidPaise'], 3000000);
    final inst = await rawDocs(db, 'installments', 'c1');
    final txs = await rawDocs(db, 'transactions', 'c1');
    expect(inst, hasLength(3));
    expect(txs, hasLength(3)); // disbursement, earlier payment, this one
    for (final doc in <Map<String, dynamic>>[...inst, ...txs]) {
      expect(doc['contractActive'], isFalse, reason: '${doc['id']}');
    }
  });

  test('amount above outstanding or ₹0 is rejected; nothing written', () async {
    final l = smallLoan(paidRs: 20000);
    await seedLoan(db, l.contract, txs: l.txs);
    final snap = await readSnapshot(db, 'c1');
    await expectLater(
      repo.recordPayment(pay(snap, 10001)),
      throwsA(
        isA<ValidationFailure>().having(
          (ValidationFailure f) => f.message,
          'message',
          'Amount cannot exceed the outstanding ₹10,000.',
        ),
      ),
    );
    await expectLater(
      repo.recordPayment(pay(snap, 0)),
      throwsA(isA<ValidationFailure>()),
    );
    expect(await rawDocs(db, 'transactions', 'c1'), hasLength(2));
    expect((await rawContract(db, 'c1'))['totalPaidPaise'], 2000000);
  });

  test('a closed loan refuses payments', () async {
    final l = smallLoan(paidRs: 30000, status: ContractStatus.closed);
    await seedLoan(db, l.contract, txs: l.txs);
    await expectLater(
      repo.recordPayment(pay(await readSnapshot(db, 'c1'), 100)),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('late payment on a rolled-over loan: allowed beyond outstanding, '
      'stays rolled over and inactive', () async {
    final l = smallLoan(paidRs: 30000, status: ContractStatus.rolledOver);
    await seedLoan(db, l.contract, txs: l.txs);
    final r = await repo.recordPayment(
      pay(await readSnapshot(db, 'c1'), 10000),
    );
    final c = await rawContract(db, 'c1');
    expect(c['status'], 'rolledOver');
    expect(c['totalPaidPaise'], 4000000);
    final t = (await db.doc('companies/$kCid/transactions/${r.id}').get())
        .data()!;
    expect(t['contractActive'], isFalse);
    expect(r.closed, isFalse);
  });
}
