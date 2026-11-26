import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/contracts/data/contract_repository.dart';
import 'package:uuid/uuid.dart';

import 'contract_test_support.dart';

/// Onboarding "today": Mon 24 Nov 2026.
final CivilDate _today = d(2026, 11, 24);

void main() {
  late FakeFirebaseFirestore db;
  late ContractRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = ContractRepository(firestore: db, clock: clockAt(_today));
    await seedCompany(db);
  });

  /// ₹1,00,000 weekly ₹10,000 on Tuesdays, disbursed Tue 25 Aug 2026,
  /// first due Tue 1 Sep 2026: all 10 rows are before today.
  OnboardContractCommand weekly({
    List<PastPaymentInput> payments = const <PastPaymentInput>[],
    Role? role = Role.owner,
    CivilDate? disbursedOn,
    CivilDate? firstDue,
    int upfrontInput = 500000,
    String? previousRef = '  Book 3 / 117 ',
  }) => OnboardContractCommand(
    cid: kCid,
    borrower: anita(),
    sanctioned: rs(100000),
    upfrontMode: UpfrontMode.flat,
    upfrontInput: upfrontInput,
    installmentAmount: rs(10000),
    frequency: Frequency.weekly,
    preferredWeekday: 2,
    firstDueDate: firstDue ?? d(2026, 9, 1),
    disbursedOn: disbursedOn ?? d(2026, 8, 25),
    cachedNextLoanNo: 3,
    actor: kActor,
    role: role,
    today: _today,
    pastPayments: payments,
    previousRef: previousRef,
    guarantor: 'Mohan',
    purpose: 'Shop stock',
  );

  /// ₹36,600 daily ₹100 → 366 rows, disbursed 400 days ago: the largest
  /// schedule, all in the past.
  OnboardContractCommand daily(List<PastPaymentInput> payments) =>
      OnboardContractCommand(
        cid: kCid,
        borrower: anita(),
        sanctioned: rs(36600),
        upfrontMode: UpfrontMode.flat,
        upfrontInput: 0,
        installmentAmount: rs(100),
        frequency: Frequency.daily,
        firstDueDate: _today.addDays(-399),
        disbursedOn: _today.addDays(-400),
        cachedNextLoanNo: 3,
        actor: kActor,
        role: Role.owner,
        today: _today,
        pastPayments: payments,
      );

  /// [n] itemised cash payments of [rupees] on days 1…300 after the daily
  /// loan's disbursement.
  List<PastPaymentInput> itemised(int n, int rupees) => <PastPaymentInput>[
    for (var i = 0; i < n; i++)
      PastPaymentInput(
        paidOn: _today.addDays(-400 + 1 + i % 300),
        amount: rs(rupees),
        mode: PaymentMode.values[i % 3],
        reference: i.isEven ? 'R$i' : null,
      ),
  ];

  Future<List<Map<String, dynamic>>> all(
    String col,
  ) async => <Map<String, dynamic>>[
    for (final doc in (await db.collection('companies/$kCid/$col').get()).docs)
      <String, dynamic>{...doc.data(), 'id': doc.id},
  ];

  Future<Map<String, dynamic>> contractRaw(String id) async =>
      (await db.doc('companies/$kCid/contracts/$id').get()).data()!;

  Future<ContractProjection> projectSaved(String id) async {
    final refs = TypedRefs(db);
    final c = (await refs.contract(kCid, id).get()).data()!;
    final inst = await refs.installments(kCid).get();
    final txs = await refs.transactions(kCid).get();
    return projectContract(
      contract: c,
      installments: <Installment>[for (final x in inst.docs) x.data()],
      transactions: <LedgerTransaction>[for (final x in txs.docs) x.data()],
      today: _today,
    );
  }

  Future<void> expectNothingWritten() async {
    expect(await all('contracts'), isEmpty);
    expect(await all('installments'), isEmpty);
    expect(await all('transactions'), isEmpty);
    final company = (await db.doc('companies/$kCid').get()).data()!;
    expect(company['nextLoanNo'], 3);
  }

  group('onboardContract: opening total spread', () {
    test('weekly ₹75,000 opening total: one batch, exact docs', () async {
      final cmd = weekly(
        payments: spreadOpeningTotal(
          schedule: generateSchedule(
            sanctioned: rs(100000),
            installmentAmount: rs(10000),
            frequency: Frequency.weekly,
            firstDueDate: d(2026, 9, 1),
            preferredWeekday: 2,
          ),
          total: rs(75000),
          mode: PaymentMode.cash,
          disbursedOn: d(2026, 8, 25),
          today: _today,
        ),
      );
      final r = await repo.onboardContract(cmd);
      expect(r.outcome, WriteOutcome.synced);

      final c = await contractRaw(r.id);
      expect(c['origin'], 'onboarded');
      expect(c['onboardedOn'], '2026-11-24');
      expect(c['previousRef'], 'Book 3 / 117');
      expect(c['disbursedOn'], '2026-08-25');
      expect(c['firstDueDate'], '2026-09-01');
      expect(c['totalPaidPaise'], 7500000);
      expect(c['totalWaivedPaise'], 0);
      expect(c['lastPaymentOn'], '2026-10-20');
      expect(c['sanctionedPaise'], 10000000);
      expect(c['upfrontPaise'], 500000);
      expect(c['netDisbursedPaise'], 9500000);
      expect(c['rolledOverFromContractId'], isNull);
      expect(c['status'], 'active');
      expect(c['loanNo'], 4);
      expect(c['createdBy'], kOwnerUid);
      expect(c['createdAt'], isA<Timestamp>());

      final company = (await db.doc('companies/$kCid').get()).data()!;
      expect(company['nextLoanNo'], 4);
      expect(await all('installments'), hasLength(10));

      final txs = await all('transactions');
      final disb = txs.singleWhere((m) => m['type'] == 'disbursement');
      expect(disb['origin'], 'onboarding');
      expect(disb['paidOn'], '2026-08-25');
      expect(disb['amountPaise'], 9500000);
      expect(disb['openingBalance'], false);

      final pays = txs.where((m) => m['type'] == 'payment').toList()
        ..sort(
          (a, b) => (a['paidOn'] as String).compareTo(b['paidOn'] as String),
        );
      expect(pays, hasLength(8));
      expect(pays.map((m) => m['paidOn']), <String>[
        '2026-09-01',
        '2026-09-08',
        '2026-09-15',
        '2026-09-22',
        '2026-09-29',
        '2026-10-06',
        '2026-10-13',
        '2026-10-20',
      ]);
      expect(pays.last['amountPaise'], 500000);
      for (final m in <Map<String, dynamic>>[disb, ...pays]) {
        expect(m['contractId'], r.id);
        expect(m['contractActive'], true);
        expect(m['recordedBy'], kOwnerUid);
        expect(m['recordedByName'], 'Ravi');
        expect(m['deviceId'], 'dev-1');
        expect(m['recordedAt'], isA<Timestamp>());
        expect(m['clientRecordedAt'], isA<Timestamp>());
        expect(m['loanNo'], 4);
      }
      for (final m in pays) {
        expect(m['origin'], 'onboarding');
        expect(m['openingBalance'], true);
        expect(m['note'], 'Opening balance');
        expect(m['mode'], 'cash');
      }
      // Nothing is dated today.
      expect(txs.any((m) => m['paidOn'] == '2026-11-24'), isFalse);

      // As of today: 20 Oct partial, 27 Oct and 3 Nov missed.
      final p = await projectSaved(r.id);
      expect(p.totalPaid, rs(75000));
      expect(p.outstanding, rs(25000));
      expect(p.overdueAmount, rs(25000));
      expect(p.overdueCount, 3);
      expect(p.maxDaysOverdue, 35);
      expect(p.rows.where((ProjectedRow r) => r.isExtension), isNotEmpty);
    });

    test('₹0 collected: only the contract, rows and disbursement', () async {
      final r = await repo.onboardContract(weekly(previousRef: null));
      final c = await contractRaw(r.id);
      expect(c['totalPaidPaise'], 0);
      expect(c['lastPaymentOn'], isNull);
      expect(c['previousRef'], isNull);
      final txs = await all('transactions');
      expect(txs.single['type'], 'disbursement');
      final p = await projectSaved(r.id);
      expect(p.overdueCount, 10);
      expect(p.overdueAmount, rs(100000));
    });

    test('upfront ₹0 is allowed: net = sanctioned', () async {
      final r = await repo.onboardContract(weekly(upfrontInput: 0));
      final c = await contractRaw(r.id);
      expect(c['upfrontPaise'], 0);
      expect(c['netDisbursedPaise'], 10000000);
    });
  });

  group('onboardContract: itemised payments and balanced chunks', () {
    test('daily loan, 300 itemised payments → 2 balanced batches', () async {
      final cmd = daily(itemised(300, 100));
      final plan = planOnboarding(
        terms: cmd,
        pastPayments: cmd.pastPayments,
        today: _today,
        contractId: 'c-x',
        borrowerId: 'b1',
        borrowerName: 'Anita Sharma',
        borrowerPhoneE164: '+919845012890',
        now: DateTime.utc(2026, 11, 24),
        uuid: const Uuid(),
      );
      final chunks = plan.chunks(db, kCid);
      expect(chunks.fixedOps, 366 + 1 + 1); // installments, disb, company
      expect(chunks.chunkSizes, <int>[81, 219]);
      expect(chunks.batchCount, 2);
      expect(chunks.opsPerBatch, <int>[450, 220]);
      expect(Money.sum(chunks.chunkSums), rs(30000));

      final r = await repo.onboardContract(cmd);
      final c = await contractRaw(r.id);
      expect(c['totalPaidPaise'], 3000000);
      expect(await all('installments'), hasLength(366));
      final pays = (await all(
        'transactions',
      )).where((m) => m['type'] == 'payment').toList();
      expect(pays, hasLength(300));
      expect(
        pays.fold<int>(0, (int s, m) => s + (m['amountPaise'] as int)),
        c['totalPaidPaise'],
      );
      expect(pays.map((m) => m['id']).toSet(), hasLength(300));
      for (final m in pays) {
        expect(m['mode'], isIn(<String>['upi', 'cash', 'bank']));
        expect(m['origin'], 'onboarding');
        expect(m['openingBalance'], false);
        expect(m['note'], isNull);
      }
      expect(pays.where((m) => m['reference'] != null), hasLength(150));
      expect(c['lastPaymentOn'], _today.addDays(-400 + 300).toString());
    });

    for (final (n, rupees, batches) in <(int, int, int)>[
      (81, 100, 1),
      (82, 100, 2),
      (600, 50, 3),
      (1100, 10, 4),
    ]) {
      test('$n payments → $batches batch(es): Σ payments == Σ increments '
          '== totalPaid', () async {
        final cmd = daily(itemised(n, rupees));
        final plan = planOnboarding(
          terms: cmd,
          pastPayments: cmd.pastPayments,
          today: _today,
          contractId: 'c-x',
          borrowerId: 'b1',
          borrowerName: 'Anita Sharma',
          borrowerPhoneE164: '+919845012890',
          now: DateTime.utc(2026, 11, 24),
          uuid: const Uuid(),
        );
        final chunks = plan.chunks(db, kCid);
        expect(chunks.batchCount, batches);
        expect(chunks.opsPerBatch.every((int o) => o <= 450), isTrue);
        for (var i = 0; i < batches; i++) {
          expect(
            chunks.chunkSums[i],
            rs(rupees) * chunks.chunkSizes[i],
            reason: 'batch $i balances its own payments',
          );
        }
        expect(Money.sum(chunks.chunkSums), plan.totalCollected);

        final r = await repo.onboardContract(cmd);
        final c = await contractRaw(r.id);
        final pays = (await all(
          'transactions',
        )).where((m) => m['type'] == 'payment').toList();
        expect(pays, hasLength(n));
        final sum = pays.fold<int>(
          0,
          (int s, m) => s + (m['amountPaise'] as int),
        );
        expect(sum, n * rupees * 100);
        expect(c['totalPaidPaise'], sum);
        final ids = <Object?>{
          for (final m in await all('transactions')) m['id'],
          for (final m in await all('installments')) m['id'],
          r.id,
        };
        expect(ids, hasLength(n + 1 + 366 + 1));
      });
    }

    test('preview of the plan equals the saved projection', () async {
      final cmd = daily(itemised(120, 100));
      final plan = planOnboarding(
        terms: cmd,
        pastPayments: cmd.pastPayments,
        today: _today,
        contractId: 'preview',
        borrowerId: 'b1',
        borrowerName: 'Anita Sharma',
        borrowerPhoneE164: '+919845012890',
        now: DateTime.utc(2026, 11, 24),
        uuid: const Uuid(),
      );
      final preview = projectContract(
        contract: plan.contract,
        installments: plan.installments,
        transactions: plan.transactions,
        today: _today,
      );
      final r = await repo.onboardContract(cmd);
      final saved = await projectSaved(r.id);
      expect(saved.totalPaid, preview.totalPaid);
      expect(saved.outstanding, preview.outstanding);
      expect(saved.overdueAmount, preview.overdueAmount);
      expect(saved.overdueCount, preview.overdueCount);
      expect(saved.maturityDate, preview.maturityDate);
      expect(
        saved.rows.map((ProjectedRow x) => (x.dueDate, x.paid, x.status)),
        preview.rows.map((ProjectedRow x) => (x.dueDate, x.paid, x.status)),
      );
    });
  });

  group('onboardContract: refusals write nothing', () {
    Future<void> expectValidation(
      OnboardContractCommand cmd,
      String field,
    ) async {
      await expectLater(
        repo.onboardContract(cmd),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure f) => f.field,
            'field',
            field,
          ),
        ),
      );
      await expectNothingWritten();
    }

    PastPaymentInput pay(CivilDate on, int rupees, {PaymentMode? mode}) =>
        PastPaymentInput(paidOn: on, amount: rs(rupees), mode: mode);

    test('a payment dated before disbursedOn', () async {
      await expectValidation(
        weekly(
          payments: <PastPaymentInput>[
            pay(d(2026, 8, 24), 100, mode: PaymentMode.cash),
          ],
        ),
        LedgerFields.pastPayment(0),
      );
    });

    test('a payment dated after today', () async {
      await expectValidation(
        weekly(
          payments: <PastPaymentInput>[
            pay(d(2026, 9, 1), 100, mode: PaymentMode.cash),
            pay(_today.addDays(1), 100, mode: PaymentMode.cash),
          ],
        ),
        LedgerFields.pastPayment(1),
      );
    });

    test('a payment without a mode', () async {
      await expectValidation(
        weekly(payments: <PastPaymentInput>[pay(d(2026, 9, 1), 100)]),
        LedgerFields.pastPayment(0),
      );
    });

    test('total == sanctioned (fully repaid)', () async {
      await expectValidation(
        weekly(
          payments: <PastPaymentInput>[
            pay(d(2026, 9, 1), 100000, mode: PaymentMode.bank),
          ],
        ),
        LedgerFields.pastPayments,
      );
    });

    test('total > sanctioned', () async {
      await expectValidation(
        weekly(
          payments: <PastPaymentInput>[
            pay(d(2026, 9, 1), 60000, mode: PaymentMode.bank),
            pay(d(2026, 9, 8), 60000, mode: PaymentMode.bank),
          ],
        ),
        LedgerFields.pastPayments,
      );
    });

    test('disbursedOn in the future or more than 3 years back', () async {
      await expectValidation(
        weekly(disbursedOn: _today.addDays(1), firstDue: _today.addDays(7)),
        LedgerFields.disbursedOn,
      );
      await expectValidation(
        weekly(
          disbursedOn: _today.addDays(-1097),
          firstDue: _today.addDays(-1090),
        ),
        LedgerFields.disbursedOn,
      );
    });

    test('first due more than 366 days after disbursement', () async {
      await expectValidation(
        weekly(firstDue: d(2027, 8, 31)),
        LedgerFields.firstDueDate,
      );
    });

    test('a term error (installment > sanctioned) comes first', () async {
      final bad = OnboardContractCommand(
        cid: kCid,
        borrower: anita(),
        sanctioned: rs(1000),
        upfrontMode: UpfrontMode.flat,
        upfrontInput: 0,
        installmentAmount: rs(2000),
        frequency: Frequency.monthly,
        preferredMonthDay: 5,
        firstDueDate: d(2026, 9, 5),
        disbursedOn: d(2026, 8, 25),
        cachedNextLoanNo: 3,
        actor: kActor,
        role: Role.owner,
        today: _today,
        pastPayments: const <PastPaymentInput>[],
      );
      await expectValidation(bad, LedgerFields.installmentAmount);
    });

    test('a collector (or no role) is refused', () async {
      for (final role in <Role?>[Role.collector, null]) {
        await expectLater(
          repo.onboardContract(weekly(role: role)),
          throwsA(isA<PermissionDeniedFailure>()),
        );
      }
      await expectNothingWritten();
    });
  });

  test('planNewContract defaults keep create and rollover standard', () {
    final cmd = weekly();
    final plan = planNewContract(
      cmd: cmd,
      contractId: 'c-s',
      borrowerId: 'b1',
      borrowerName: 'Anita Sharma',
      borrowerPhoneE164: '+919845012890',
      now: DateTime.utc(2026, 11, 24),
      uuid: const Uuid(),
      // Ignored unless the origin is onboarded.
      onboardedOn: _today,
      previousRef: 'X',
    );
    expect(plan.contract.origin, ContractOrigin.standard);
    expect(plan.contract.onboardedOn, isNull);
    expect(plan.contract.previousRef, isNull);
    expect(plan.disbursement!.origin, TxOrigin.live);
  });

  test('planOnboarding refuses a mode-less payment (validate first)', () {
    final cmd = weekly(
      payments: <PastPaymentInput>[
        PastPaymentInput(paidOn: d(2026, 9, 1), amount: rs(1), mode: null),
      ],
    );
    expect(
      () => planOnboarding(
        terms: cmd,
        pastPayments: cmd.pastPayments,
        today: _today,
        contractId: 'c',
        borrowerId: 'b1',
        borrowerName: 'A',
        borrowerPhoneE164: '+919845012890',
        now: DateTime.utc(2026, 11, 24),
        uuid: const Uuid(),
      ),
      throwsArgumentError,
    );
  });
}
