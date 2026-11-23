import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/payments/data/payment_repository.dart';

import '../payment_test_support.dart';

/// Tester S6: close at ₹0, overpay rejection, reversal reopen, double
/// reversal on a ₹1,00,000 loan.
void main() {
  late FakeFirebaseFirestore db;
  late PaymentRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = PaymentRepository(firestore: db, clock: clockAt(d(2023, 11, 7)));
    final c = makeContract().copyWith(totalPaid: rs(60000));
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
  });

  Future<PaymentWriteResult> pay(int rupees) async => repo.recordPayment(
    RecordPaymentCommand(
      cid: kCid,
      snapshot: await readSnapshot(db, 'c1'),
      amount: rs(rupees),
      paidOn: d(2023, 11, 7),
      mode: PaymentMode.upi,
      actor: kActor,
    ),
  );

  Future<PaymentWriteResult> reverse(String id) async => repo.reversePayment(
    ReversePaymentCommand(
      cid: kCid,
      snapshot: await readSnapshot(db, 'c1'),
      transactionId: id,
      reason: 'Entered twice',
      today: d(2023, 11, 7),
      actor: kActor,
    ),
  );

  test('paying exactly the outstanding closes; contractActive false on all '
      'docs', () async {
    final r = await pay(40000);
    expect(r.closed, isTrue);
    expect(r.balanceAfter, rs(0));
    final c = await rawContract(db, 'c1');
    expect(c['status'], 'closed');
    expect(c['closedAt'], isNotNull);
    expect(c['totalPaidPaise'], 10000000);
    for (final col in <String>['installments', 'transactions']) {
      final docs = await rawDocs(db, col, 'c1');
      expect(docs, isNotEmpty);
      for (final doc in docs) {
        expect(doc['contractActive'], isFalse, reason: '$col ${doc['id']}');
      }
    }
  });

  test('paying above the outstanding is rejected, nothing written', () async {
    await expectLater(pay(40001), throwsA(isA<ValidationFailure>()));
    expect((await rawContract(db, 'c1'))['totalPaidPaise'], 6000000);
    expect(await rawDocs(db, 'transactions', 'c1'), hasLength(2));
  });

  test('a zero payment is rejected', () async {
    await expectLater(pay(0), throwsA(isA<ValidationFailure>()));
  });

  test(
    'reversing the final payment reopens the loan with an outstanding',
    () async {
      final last = await pay(40000);
      await reverse(last.id);
      final c = await rawContract(db, 'c1');
      expect(c['status'], 'active');
      expect(c['closedAt'], isNull);
      expect(c['totalPaidPaise'], 6000000);
      for (final doc in await rawDocs(db, 'installments', 'c1')) {
        expect(doc['contractActive'], isTrue);
      }
      final snap = await readSnapshot(db, 'c1');
      expect(snap.outstanding, rs(40000));
    },
  );

  test('reversing the same payment twice is rejected', () async {
    await reverse('tx-p1');
    await expectLater(
      reverse('tx-p1'),
      throwsA(
        isA<ValidationFailure>().having(
          (f) => f.message,
          'message',
          contains('already been reversed'),
        ),
      ),
    );
    expect((await rawContract(db, 'c1'))['totalPaidPaise'], 0);
  });
}
