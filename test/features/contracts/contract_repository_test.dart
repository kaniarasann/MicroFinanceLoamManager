import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/contracts/data/contract_repository.dart';

import 'contract_test_support.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ContractRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = ContractRepository(firestore: db, clock: clockAt(d(2023, 10, 24)));
    await seedCompany(db);
  });

  CreateContractCommand cmd({
    UpfrontMode mode = UpfrontMode.flat,
    int upfrontInput = 700000,
    int installmentRs = 10000,
    int sanctionedRs = 100000,
    String? guarantor = 'Mohan Sharma',
  }) => CreateContractCommand(
    cid: kCid,
    borrower: anita(),
    sanctioned: rs(sanctionedRs),
    upfrontMode: mode,
    upfrontInput: upfrontInput,
    installmentAmount: rs(installmentRs),
    frequency: Frequency.weekly,
    preferredWeekday: 2,
    preferredMonthDay: 15, // ignored for weekly
    firstDueDate: d(2023, 10, 31),
    disbursedOn: d(2023, 10, 24),
    cachedNextLoanNo: 3,
    actor: kActor,
    guarantor: guarantor,
    notes: '  ',
    purpose: 'Shop stock',
  );

  Future<List<Map<String, dynamic>>> all(
    String col,
  ) async => <Map<String, dynamic>>[
    for (final d in (await db.collection('companies/$kCid/$col').get()).docs)
      d.data(),
  ];

  group('createContract', () {
    test(
      '₹1,00,000 flat ₹7,000 weekly ₹10,000: one batch, exact fields',
      () async {
        final r = await repo.createContract(cmd());
        expect(r.outcome, WriteOutcome.synced);

        final c = (await db.doc('companies/$kCid/contracts/${r.id}').get())
            .data()!;
        expect(c['borrowerId'], 'b1');
        expect(c['borrowerName'], 'Anita Sharma');
        expect(c['borrowerPhoneE164'], '+919845012890');
        expect(c['loanNo'], 4);
        expect(c['purpose'], 'Shop stock');
        expect(c['status'], 'active');
        expect(c['sanctionedPaise'], 10000000);
        expect(c['upfrontMode'], 'flat');
        expect(c['upfrontInput'], 700000);
        expect(c['upfrontPaise'], 700000);
        expect(c['netDisbursedPaise'], 9300000);
        expect(c['frequency'], 'weekly');
        expect(c['preferredWeekday'], 2);
        expect(c['preferredMonthDay'], isNull);
        expect(c['installmentPaise'], 1000000);
        expect(c['baseInstallmentCount'], 10);
        expect(c['firstDueDate'], '2023-10-31');
        expect(c['disbursedOn'], '2023-10-24');
        expect(c['guarantor'], 'Mohan Sharma');
        expect(c['notes'], isNull);
        expect(c['totalPaidPaise'], 0);
        expect(c['createdBy'], kOwnerUid);
        expect(c['createdAt'], isA<Timestamp>());
        expect(c['schemaVersion'], 1);

        final inst = await all('installments')
          ..sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
        expect(inst, hasLength(10));
        expect(inst.map((m) => m['seq']), <int>[
          for (var i = 1; i <= 10; i++) i,
        ]);
        expect(inst.first['dueDate'], '2023-10-31');
        expect(inst.last['dueDate'], '2024-01-02');
        for (final m in inst) {
          expect(m['contractId'], r.id);
          expect(m['kind'], 'base');
          expect(m['amountDuePaise'], 1000000);
          expect(m['rescheduledOutPaise'], 0);
          expect(m['rescheduledToIds'], isEmpty);
          expect(m['rescheduledFromId'], isNull);
          expect(m['contractActive'], true);
          expect(m['borrowerId'], 'b1');
          expect(m['borrowerName'], 'Anita Sharma');
          expect(m['loanNo'], 4);
        }

        final txs = await all('transactions');
        expect(txs, hasLength(1));
        final t = txs.single;
        expect(t['type'], 'disbursement');
        expect(t['amountPaise'], 9300000);
        expect(t['paidOn'], '2023-10-24');
        expect(t['contractId'], r.id);
        expect(t['contractActive'], true);
        expect(t['recordedBy'], kOwnerUid);
        expect(t['recordedByName'], 'Ravi');
        expect(t['deviceId'], 'dev-1');
        expect(t['recordedAt'], isA<Timestamp>()); // serverTimestamp
        expect(t['clientRecordedAt'], isA<Timestamp>());

        final company = (await db.doc('companies/$kCid').get()).data()!;
        expect(company['nextLoanNo'], 4);
      },
    );

    test(
      'percent mode: 7.5% of ₹1,00,000 → upfront ₹7,500, net ₹92,500',
      () async {
        final r = await repo.createContract(
          cmd(mode: UpfrontMode.percent, upfrontInput: 750),
        );
        final c = (await db.doc('companies/$kCid/contracts/${r.id}').get())
            .data()!;
        expect(c['upfrontMode'], 'percent');
        expect(c['upfrontInput'], 750);
        expect(c['upfrontPaise'], 750000);
        expect(c['netDisbursedPaise'], 9250000);
        expect((await all('transactions')).single['amountPaise'], 9250000);
      },
    );

    test(
      'rejects upfront ≥ sanctioned and 367 installments; writes nothing',
      () async {
        await expectLater(
          repo.createContract(cmd(upfrontInput: 10000000)),
          throwsA(
            isA<ValidationFailure>().having(
              (f) => f.field,
              'field',
              'upfrontInput',
            ),
          ),
        );
        await expectLater(
          repo.createContract(
            cmd(sanctionedRs: 367, installmentRs: 1, upfrontInput: 0),
          ),
          throwsA(
            isA<ValidationFailure>().having(
              (f) => f.field,
              'field',
              'installmentCount',
            ),
          ),
        );
        expect(await all('contracts'), isEmpty);
        expect(await all('installments'), isEmpty);
        expect(
          (await db.doc('companies/$kCid').get()).data()!['nextLoanNo'],
          3,
        );
      },
    );
  });
}
