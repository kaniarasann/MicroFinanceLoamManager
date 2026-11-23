import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/payments/data/payment_repository.dart';

import 'payment_test_support.dart';

/// ₹30,000 loan with ₹20,000 paid: outstanding ₹10,000.
void main() {
  late FakeFirebaseFirestore db;
  late PaymentRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = PaymentRepository(firestore: db, clock: clockAt(d(2023, 11, 7)));
    final l = smallLoan(paidRs: 20000);
    await seedLoan(db, l.contract, txs: l.txs);
  });

  Future<CloseWithWaiverCommand> close({
    int cashRs = 8000,
    int waiverRs = 2000,
    String reason = 'Early closure discount',
    Role role = Role.owner,
  }) async => CloseWithWaiverCommand(
    cid: kCid,
    snapshot: await readSnapshot(db, 'c1'),
    cashAmount: rs(cashRs),
    waiverAmount: rs(waiverRs),
    reason: reason,
    paidOn: d(2023, 11, 7),
    mode: PaymentMode.cash,
    actor: kActor,
    role: role,
  );

  Future<Map<String, dynamic>> txDoc(String id) async =>
      (await db.doc('companies/$kCid/transactions/$id').get()).data()!;

  test('close-with-waiver writes payment + waiver + closed contract', () async {
    final r = await repo.closeWithWaiver(await close());

    final pay = await txDoc(r.paymentId!);
    expect(pay['type'], 'payment');
    expect(pay['amountPaise'], 800000);
    expect(pay['mode'], 'cash');
    expect(pay['contractActive'], isFalse);
    expect(pay['recordedBy'], kOwnerUid);

    final w = await txDoc(r.waiverId);
    expect(w['type'], 'waiver');
    expect(w['amountPaise'], 200000);
    expect(w['note'], 'Early closure discount');
    expect(w['mode'], isNull);
    expect(w['paidOn'], '2023-11-07');
    expect(w['contractActive'], isFalse);
    expect(w['recordedBy'], kOwnerUid);

    final c = await rawContract(db, 'c1');
    expect(c['totalPaidPaise'], 2800000);
    expect(c['totalWaivedPaise'], 200000);
    expect(c['status'], 'closed');
    expect(c['closedAt'], isNotNull);
    expect(c['lastPaymentOn'], '2023-11-07');
    for (final doc in <Map<String, dynamic>>[
      ...await rawDocs(db, 'installments', 'c1'),
      ...await rawDocs(db, 'transactions', 'c1'),
    ]) {
      expect(doc['contractActive'], isFalse, reason: '${doc['id']}');
    }
    final snap = await readSnapshot(db, 'c1');
    expect(snap.outstanding, Money.zero);
  });

  test('no cash: only the waiver is written', () async {
    final r = await repo.closeWithWaiver(
      await close(cashRs: 0, waiverRs: 10000),
    );
    expect(r.paymentId, isNull);
    final txs = await rawDocs(db, 'transactions', 'c1');
    expect(
      txs.where((Map<String, dynamic> t) => t['type'] == 'payment'),
      hasLength(1),
    );
    expect((await rawContract(db, 'c1'))['totalPaidPaise'], 2000000);
  });

  Future<void> expectRejected(
    Future<CloseWithWaiverCommand> cmd,
    Matcher failure,
  ) async {
    await expectLater(repo.closeWithWaiver(await cmd), throwsA(failure));
    final c = await rawContract(db, 'c1');
    expect(c['status'], 'active');
    expect(c['totalPaidPaise'], 2000000);
    expect(await rawDocs(db, 'transactions', 'c1'), hasLength(2));
  }

  test('cash + waiver ≠ outstanding is rejected', () async {
    await expectRejected(close(waiverRs: 1500), isA<ValidationFailure>());
  });

  test('a ₹0 waiver is rejected', () async {
    await expectRejected(
      close(cashRs: 10000, waiverRs: 0),
      isA<ValidationFailure>(),
    );
  });

  test('an empty reason is rejected', () async {
    await expectRejected(close(reason: '   '), isA<ValidationFailure>());
  });

  test('a collector call is rejected', () async {
    await expectRejected(
      close(role: Role.collector),
      isA<PermissionDeniedFailure>(),
    );
  });

  ReversePaymentCommand reverse(ContractSnapshot snap, String id) =>
      ReversePaymentCommand(
        cid: kCid,
        snapshot: snap,
        transactionId: id,
        reason: 'Discount cancelled',
        today: d(2023, 11, 8),
        actor: kActor,
      );

  test('waiver reversal reopens and decrements totalWaivedPaise', () async {
    final w = await repo.closeWithWaiver(await close());
    final r = await repo.reversePayment(
      reverse(await readSnapshot(db, 'c1'), w.waiverId),
    );
    final t = await txDoc(r.id);
    expect(t['type'], 'reversal');
    expect(t['amountPaise'], 200000);
    expect(t['reversesTxId'], w.waiverId);
    expect(t['contractActive'], isTrue);

    final c = await rawContract(db, 'c1');
    expect(c['status'], 'active');
    expect(c['closedAt'], isNull);
    expect(c['totalWaivedPaise'], 0);
    expect(c['totalPaidPaise'], 2800000, reason: 'cash untouched');
    expect(r.balanceAfter, rs(2000));
    for (final doc in await rawDocs(db, 'installments', 'c1')) {
      expect(doc['contractActive'], isTrue);
    }
  });

  test('a waiver cannot be reversed twice', () async {
    final w = await repo.closeWithWaiver(await close());
    await repo.reversePayment(
      reverse(await readSnapshot(db, 'c1'), w.waiverId),
    );
    await expectLater(
      repo.reversePayment(reverse(await readSnapshot(db, 'c1'), w.waiverId)),
      throwsA(isA<ValidationFailure>()),
    );
    expect((await rawContract(db, 'c1'))['totalWaivedPaise'], 0);
  });
}
