// Tester — Sprint 5: createContract batch, adversarial terms.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/contracts/data/contract_repository.dart';

import '../contract_test_support.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ContractRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = ContractRepository(firestore: db, clock: clockAt(d(2025, 1, 10)));
    await seedCompany(db);
  });

  CreateContractCommand cmd({
    int sanctionedRs = 100000,
    int installmentRs = 30000,
    UpfrontMode mode = UpfrontMode.flat,
    int upfrontInput = 0,
    Frequency frequency = Frequency.monthly,
    int? monthDay = 31,
    CivilDate? first,
    CivilDate? disbursed,
  }) => CreateContractCommand(
    cid: kCid,
    borrower: anita(),
    sanctioned: rs(sanctionedRs),
    upfrontMode: mode,
    upfrontInput: upfrontInput,
    installmentAmount: rs(installmentRs),
    frequency: frequency,
    preferredWeekday: null,
    preferredMonthDay: monthDay,
    firstDueDate: first ?? d(2025, 1, 31),
    disbursedOn: disbursed ?? d(2025, 1, 10),
    cachedNextLoanNo: 3,
    actor: kActor,
  );

  Future<List<Map<String, dynamic>>> inst() async {
    final q = await db.collection('companies/$kCid/installments').get();
    return q.docs.map((s) => s.data()).toList()
      ..sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
  }

  Future<int> count(String col) async =>
      (await db.collection('companies/$kCid/$col').get()).docs.length;

  test(
    'monthly on the 31st from Jan: Feb clamps; 4 rows, last ₹10,000',
    () async {
      final r = await repo.createContract(cmd());
      final rows = await inst();
      expect(rows.map((m) => m['dueDate']), <String>[
        '2025-01-31',
        '2025-02-28',
        '2025-03-31',
        '2025-04-30',
      ]);
      expect(rows.map((m) => m['amountDuePaise']), <int>[
        3000000,
        3000000,
        3000000,
        1000000,
      ]);
      final c = (await db.doc('companies/$kCid/contracts/${r.id}').get())
          .data()!;
      expect(c['baseInstallmentCount'], 4);
      expect(c['preferredMonthDay'], 31);
      expect(c['preferredWeekday'], isNull);
      expect(c['netDisbursedPaise'], 10000000);
    },
  );

  test('leap year: 31 Jan 2024 → 29 Feb 2024', () async {
    await repo.createContract(
      cmd(first: d(2024, 1, 31), disbursed: d(2024, 1, 10)),
    );
    expect((await inst())[1]['dueDate'], '2024-02-29');
  });

  test('percent 7.5% → upfront ₹7,500, net ₹92,500 (contract + tx)', () async {
    final r = await repo.createContract(
      cmd(mode: UpfrontMode.percent, upfrontInput: 750),
    );
    final c = (await db.doc('companies/$kCid/contracts/${r.id}').get()).data()!;
    expect(c['upfrontPaise'], 750000);
    expect(c['netDisbursedPaise'], 9250000);
    final tx = (await db.collection('companies/$kCid/transactions').get())
        .docs
        .single
        .data();
    expect(tx['amountPaise'], 9250000);
  });

  Future<void> rejects(CreateContractCommand c, String field) async {
    await expectLater(
      repo.createContract(c),
      throwsA(isA<ValidationFailure>().having((f) => f.field, 'field', field)),
    );
    expect(await count('contracts'), 0);
    expect(await count('installments'), 0);
    expect(await count('transactions'), 0);
    expect((await db.doc('companies/$kCid').get()).data()!['nextLoanNo'], 3);
  }

  test(
    'upfront = sanctioned (flat ₹1,00,000) rejected, nothing written',
    () => rejects(cmd(upfrontInput: 10000000), 'upfrontInput'),
  );

  test('upfront 100% rejected', () async {
    await expectLater(
      repo.createContract(cmd(mode: UpfrontMode.percent, upfrontInput: 10000)),
      throwsA(isA<ValidationFailure>()),
    );
    expect(await count('contracts'), 0);
  });

  test(
    'daily ₹1 on ₹367 → 367 installments rejected',
    () => rejects(
      cmd(
        sanctionedRs: 367,
        installmentRs: 1,
        frequency: Frequency.daily,
        monthDay: null,
      ),
      'installmentCount',
    ),
  );

  test('daily ₹1 on ₹366 → allowed boundary (366 rows)', () async {
    await repo.createContract(
      cmd(
        sanctionedRs: 366,
        installmentRs: 1,
        frequency: Frequency.daily,
        monthDay: null,
      ),
    );
    expect(await count('installments'), 366);
  });

  test('monthly without a preferred day rejected', () async {
    await expectLater(
      repo.createContract(cmd(monthDay: null)),
      throwsA(isA<ValidationFailure>()),
    );
    expect(await count('contracts'), 0);
  });
}
