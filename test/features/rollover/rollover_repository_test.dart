import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/rollover/data/rollover_repository.dart';

import '../payments/payment_test_support.dart';

void main() {
  late FakeFirebaseFirestore db;
  late RolloverRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = RolloverRepository(firestore: db, clock: clockAt(d(2023, 12, 5)));
  });

  /// ₹1,00,000 weekly ₹10,000 with ₹82,000 paid → ₹18,000 outstanding.
  Future<ContractSnapshot> seedOld({int paidRs = 82000, Contract? c}) async {
    final old = c ?? makeContract().copyWith(totalPaid: rs(paidRs));
    await seedLoan(
      db,
      old,
      txs: <LedgerTransaction>[
        tx(
          'c1',
          rs(93000),
          d(2023, 10, 24),
          type: TxType.disbursement,
          id: 'tx-d',
        ),
        tx('c1', rs(paidRs), d(2023, 11, 28), id: 'tx-p1'),
      ],
    );
    return readSnapshot(db, 'c1');
  }

  RolloverCommand cmd(
    ContractSnapshot old, {
    int sanctionedRs = 100000,
    int flatRs = 7000,
    int installmentRs = 10000,
    Frequency frequency = Frequency.weekly,
  }) => RolloverCommand(
    cid: kCid,
    old: old,
    sanctioned: rs(sanctionedRs),
    upfrontMode: UpfrontMode.flat,
    upfrontInput: rs(flatRs).paise,
    installmentAmount: rs(installmentRs),
    frequency: frequency,
    preferredWeekday: 2,
    firstDueDate: d(2023, 12, 12),
    disbursedOn: d(2023, 12, 5),
    cachedNextLoanNo: 3,
    actor: kActor,
  );

  test('₹18,000 outstanding into ₹1,00,000 flat ₹7,000: net ₹75,000, '
      'exact batch', () async {
    final r = await repo.rollover(cmd(await seedOld()));
    final newId = r.id;

    final old = await rawContract(db, 'c1');
    expect(old['status'], 'rolledOver');
    expect(old['rolledOverToContractId'], newId);
    expect(old['closedAt'], isNotNull);
    expect(old['totalPaidPaise'], 10000000);
    expect(old['rolloverSettledPaise'], 1800000);

    final oldTx = await rawDocs(db, 'transactions', 'c1');
    final settle = oldTx.singleWhere(
      (Map<String, dynamic> t) => t['type'] == 'rolloverSettlement',
    );
    expect(settle['amountPaise'], 1800000);
    expect(settle['relatedContractId'], newId);
    expect(settle['paidOn'], '2023-12-05');
    expect(settle['recordedBy'], kOwnerUid);
    for (final doc in <Map<String, dynamic>>[
      ...oldTx,
      ...await rawDocs(db, 'installments', 'c1'),
    ]) {
      expect(doc['contractActive'], isFalse, reason: '${doc['id']}');
    }

    final n = await rawContract(db, newId);
    expect(n['status'], 'active');
    expect(n['rolledOverFromContractId'], 'c1');
    expect(n['loanNo'], 4);
    expect(n['borrowerId'], 'b-c1');
    expect(n['sanctionedPaise'], 10000000);
    expect(n['upfrontPaise'], 700000);
    expect(n['netDisbursedPaise'], 7500000);
    expect(n['totalPaidPaise'], 0);
    expect(n['baseInstallmentCount'], 10);
    expect(n['disbursedOn'], '2023-12-05');
    expect(await rawDocs(db, 'installments', newId), hasLength(10));
    final disb = await rawDocs(db, 'transactions', newId);
    expect(disb, hasLength(1));
    expect(disb.single['type'], 'disbursement');
    expect(disb.single['amountPaise'], 7500000);
    expect(disb.single['relatedContractId'], 'c1');
    expect(disb.single['contractActive'], isTrue);

    final co = (await db.doc('companies/$kCid').get()).data()!;
    expect(co['nextLoanNo'], 4);
  });

  test('negative net cash is rejected and nothing is written', () async {
    final old = await seedOld(
      paidRs: 5000,
    ); // ₹95,000 outstanding → net −₹2,000
    await expectLater(
      repo.rollover(cmd(old)),
      throwsA(
        isA<ValidationFailure>().having(
          (ValidationFailure f) => f.field,
          'field',
          rolloverNetField,
        ),
      ),
    );
    expect((await rawContract(db, 'c1'))['status'], 'active');
    final all = await db.collection('companies/$kCid/contracts').get();
    expect(all.docs, hasLength(1));
  });

  test('net cash ₹0: no disbursement transaction, netDisbursed 0', () async {
    // ₹18,000 outstanding = ₹25,000 − ₹7,000 upfront → exactly ₹0.
    final r = await repo.rollover(
      cmd(await seedOld(), sanctionedRs: 25000, installmentRs: 5000),
    );
    final n = await rawContract(db, r.id);
    expect(n['netDisbursedPaise'], 0);
    expect(await rawDocs(db, 'transactions', r.id), isEmpty);
    expect(await rawDocs(db, 'installments', r.id), hasLength(5));
  });

  test('an inactive loan cannot be rolled over', () async {
    final old = await seedOld(c: makeContract(status: ContractStatus.closed));
    await expectLater(
      repo.rollover(cmd(old)),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test(
    '366-day loan into a 366-day loan: flips spill, everything lands',
    () async {
      final old = makeContract(
        sanctioned: rs(366),
        installment: rs(1),
        frequency: Frequency.daily,
        weekday: null,
        upfrontInput: 0,
      );
      final snap = await seedOld(c: old, paidRs: 0);
      final r = await repo.rollover(
        cmd(
          snap,
          sanctionedRs: 732,
          flatRs: 0,
          installmentRs: 2,
          frequency: Frequency.daily,
        ),
      );
      expect(await rawDocs(db, 'installments', r.id), hasLength(366));
      for (final i in await rawDocs(db, 'installments', 'c1')) {
        expect(i['contractActive'], isFalse);
      }
      final n = await rawContract(db, r.id);
      expect(n['netDisbursedPaise'], const Money(36600).paise);
    },
  );
}
