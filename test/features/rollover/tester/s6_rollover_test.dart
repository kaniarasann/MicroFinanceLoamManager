import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/rollover/data/rollover_repository.dart';

import '../../payments/payment_test_support.dart';

/// Tester S6: rollover net cash, links, negative net, non-active refusal.
void main() {
  late FakeFirebaseFirestore db;
  late RolloverRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = RolloverRepository(firestore: db, clock: clockAt(d(2023, 12, 5)));
  });

  Future<ContractSnapshot> seedOld({
    ContractStatus status = ContractStatus.active,
  }) async {
    final old = makeContract(status: status).copyWith(totalPaid: rs(82000));
    await seedLoan(
      db,
      old,
      txs: <LedgerTransaction>[
        tx('c1', rs(93000), d(2023, 10, 24),
            type: TxType.disbursement, id: 'tx-d'),
        tx('c1', rs(82000), d(2023, 11, 28), id: 'tx-p1'),
      ],
    );
    return readSnapshot(db, 'c1');
  }

  RolloverCommand cmd(ContractSnapshot old, {int sanctionedRs = 100000}) =>
      RolloverCommand(
        cid: kCid,
        old: old,
        sanctioned: rs(sanctionedRs),
        upfrontMode: UpfrontMode.flat,
        upfrontInput: rs(7000).paise,
        installmentAmount: rs(10000),
        frequency: Frequency.weekly,
        preferredWeekday: 2,
        firstDueDate: d(2023, 12, 12),
        disbursedOn: d(2023, 12, 5),
        cachedNextLoanNo: 3,
        actor: kActor,
      );

  test('₹18,000 outstanding → new ₹1,00,000 flat ₹7,000: net ₹75,000; '
      'links both ways', () async {
    final snap = await seedOld();
    expect(snap.outstanding, rs(18000));
    final r = await repo.rollover(cmd(snap));

    final old = await rawContract(db, 'c1');
    expect(old['status'], 'rolledOver');
    expect(old['rolledOverToContractId'], r.id);

    final neu = await rawContract(db, r.id);
    expect(neu['status'], 'active');
    expect(neu['rolledOverFromContractId'], 'c1');
    expect(neu['sanctionedPaise'], 10000000);
    expect(neu['netDisbursedPaise'], 7500000);

    final disb = (await rawDocs(db, 'transactions', r.id)).where(
      (t) => t['type'] == 'disbursement',
    );
    expect(disb, hasLength(1));
    expect(disb.single['amountPaise'], 7500000);

    for (final i in await rawDocs(db, 'installments', 'c1')) {
      expect(i['contractActive'], isFalse);
    }
  });

  test('a negative net cash is rejected and nothing changes', () async {
    final snap = await seedOld();
    // ₹20,000 − ₹7,000 − ₹18,000 = −₹5,000.
    await expectLater(
      repo.rollover(cmd(snap, sanctionedRs: 20000)),
      throwsA(isA<ValidationFailure>()),
    );
    final old = await rawContract(db, 'c1');
    expect(old['status'], 'active');
    expect(old['totalPaidPaise'], 8200000);
    final all = await db.collection('companies/$kCid/contracts').get();
    expect(all.docs, hasLength(1));
  });

  test('a closed loan cannot be rolled over', () async {
    final snap = await seedOld(status: ContractStatus.closed);
    await expectLater(
      repo.rollover(cmd(snap)),
      throwsA(isA<ValidationFailure>()),
    );
  });
}
