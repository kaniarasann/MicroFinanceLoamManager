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
import 'package:nordic_ledger/features/payments/data/payment_repository.dart';
import 'package:uuid/uuid.dart';

import '../../payments/payment_test_support.dart';

/// Sprint 7b tester: the onboarding write path (Task 20) end to end on
/// `fake_cloud_firestore`: onboard → read the docs back → project →
/// portfolio, plus reversals, live payments, refusals and backward
/// compatibility.
///
/// Weekly scenario: ₹1,00,000 at ₹10,000 on Tuesdays, first due Tue 15 Sep
/// 2026 (10 weeks before today), disbursed Tue 8 Sep, ₹5,000 upfront.
/// Today Tue 24 Nov 2026. Opening total ₹55,000 cash.

final CivilDate _today = d(2026, 11, 24);
final CivilDate _disbursed = d(2026, 9, 8);
final CivilDate _firstDue = d(2026, 9, 15);

/// Exact keys of each doc the Dart write path produces. Mirrored in
/// `firebase/test/tester_s7b.test.js`, so the rules replay sends the same
/// shape; if this test fails, update both.
const Set<String> kContractKeys = <String>{
  'baseInstallmentCount',
  'borrowerId',
  'borrowerName',
  'borrowerPhoneE164',
  'closedAt',
  'createdAt',
  'createdBy',
  'disbursedOn',
  'firstDueDate',
  'frequency',
  'guarantor',
  'installmentPaise',
  'lastPaymentOn',
  'loanNo',
  'netDisbursedPaise',
  'notes',
  'onboardedOn',
  'origin',
  'preferredMonthDay',
  'preferredWeekday',
  'previousRef',
  'purpose',
  'rolledOverFromContractId',
  'rolledOverToContractId',
  'rolloverSettledPaise',
  'sanctionedPaise',
  'schemaVersion',
  'status',
  'totalPaidPaise',
  'totalWaivedPaise',
  'updatedAt',
  'upfrontInput',
  'upfrontMode',
  'upfrontPaise',
};
const Set<String> kInstallmentKeys = <String>{
  'amountDuePaise',
  'borrowerId',
  'borrowerName',
  'contractActive',
  'contractId',
  'createdAt',
  'createdBy',
  'dueDate',
  'kind',
  'loanNo',
  'rescheduledFromId',
  'rescheduledOutPaise',
  'rescheduledToIds',
  'schemaVersion',
  'seq',
};
const Set<String> kTxKeys = <String>{
  'amountPaise',
  'borrowerId',
  'borrowerName',
  'clientRecordedAt',
  'contractActive',
  'contractId',
  'deviceId',
  'loanNo',
  'mode',
  'note',
  'openingBalance',
  'origin',
  'paidOn',
  'recordedAt',
  'recordedBy',
  'recordedByName',
  'reference',
  'relatedContractId',
  'rescheduleInfo',
  'reversesTxId',
  'schemaVersion',
  'type',
};

void main() {
  late FakeFirebaseFirestore db;
  late ContractRepository contracts;
  late PaymentRepository payments;

  setUp(() async {
    db = FakeFirebaseFirestore();
    contracts = ContractRepository(firestore: db, clock: clockAt(_today));
    payments = PaymentRepository(firestore: db, clock: clockAt(_today));
    await seedCompany(db);
  });

  List<PlannedInstallment> weeklySchedule() => generateSchedule(
    sanctioned: rs(100000),
    installmentAmount: rs(10000),
    frequency: Frequency.weekly,
    firstDueDate: _firstDue,
    preferredWeekday: 2,
  );

  List<PastPaymentInput> opening(int rupees) => spreadOpeningTotal(
    schedule: weeklySchedule(),
    total: rs(rupees),
    mode: PaymentMode.cash,
    disbursedOn: _disbursed,
    today: _today,
  );

  OnboardContractCommand weekly({
    List<PastPaymentInput>? past,
    Role? role = Role.owner,
    CivilDate? disbursedOn,
    CivilDate? firstDue,
    int upfrontInput = 500000,
    String? previousRef = 'Book 7 / 12',
  }) => OnboardContractCommand(
    cid: kCid,
    borrower: anita(),
    sanctioned: rs(100000),
    upfrontMode: UpfrontMode.flat,
    upfrontInput: upfrontInput,
    installmentAmount: rs(10000),
    frequency: Frequency.weekly,
    preferredWeekday: 2,
    firstDueDate: firstDue ?? _firstDue,
    disbursedOn: disbursedOn ?? _disbursed,
    cachedNextLoanNo: 3,
    actor: kActor,
    role: role,
    today: _today,
    pastPayments: past ?? opening(55000),
    previousRef: previousRef,
  );

  /// ₹36,600 daily ₹100 → 366 rows, disbursed 400 days ago.
  OnboardContractCommand daily(List<PastPaymentInput> past) =>
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
        pastPayments: past,
      );

  List<PastPaymentInput> itemisedDaily(int n, int rupees) => <PastPaymentInput>[
    for (var i = 0; i < n; i++)
      PastPaymentInput(
        paidOn: _today.addDays(-399 + i % 300),
        amount: rs(rupees),
        mode: PaymentMode.values[i % 3],
      ),
  ];

  Future<List<Map<String, dynamic>>> all(
    String col,
  ) async => <Map<String, dynamic>>[
    for (final doc in (await db.collection('companies/$kCid/$col').get()).docs)
      <String, dynamic>{...doc.data(), 'id': doc.id},
  ];

  Future<void> expectNothingWritten() async {
    expect(await all('contracts'), isEmpty);
    expect(await all('installments'), isEmpty);
    expect(await all('transactions'), isEmpty);
    expect((await db.doc('companies/$kCid').get()).data()!['nextLoanNo'], 3);
  }

  /// The dashboard's view of everything in [db]: every active contract
  /// projected, every transaction in the window.
  Future<PortfolioMetrics> portfolio() async {
    final refs = TypedRefs(db);
    final cs = [
      for (final x in (await refs.contracts(kCid).get()).docs) x.data(),
    ];
    final inst = [
      for (final x in (await refs.installments(kCid).get()).docs) x.data(),
    ];
    final txs = [
      for (final x in (await refs.transactions(kCid).get()).docs) x.data(),
    ];
    return computePortfolio(
      projections: <ContractProjection>[
        for (final c in cs)
          if (c.isActive)
            projectContract(
              contract: c,
              installments: inst
                  .where((Installment i) => i.contractId == c.id)
                  .toList(),
              transactions: txs,
              today: _today,
            ),
      ],
      allTransactions: txs,
      today: _today,
      contractsById: <String, Contract>{for (final c in cs) c.id: c},
    );
  }

  Future<ContractProjection> projectSaved(String id) async {
    final s = await readSnapshot(db, id);
    return projectContract(
      contract: s.contract,
      installments: s.installments,
      transactions: s.transactions,
      today: _today,
    );
  }

  group('R1 weekly ₹55,000 opening total, end to end', () {
    test('docs: 6 spread payments on the due dates, totals, stamps, '
        'nothing dated today', () async {
      final r = await contracts.onboardContract(weekly());
      final c = await rawContract(db, r.id);
      expect(c['origin'], 'onboarded');
      expect(c['onboardedOn'], '2026-11-24');
      expect(c['disbursedOn'], '2026-09-08');
      expect(c['totalPaidPaise'], 5500000);
      expect(c['lastPaymentOn'], '2026-10-20');
      expect(c['netDisbursedPaise'], 9500000);
      final txs = await rawDocs(db, 'transactions', r.id);
      final pays = txs.where((m) => m['type'] == 'payment').toList()
        ..sort(
          (a, b) => (a['paidOn'] as String).compareTo(b['paidOn'] as String),
        );
      expect(pays.map((m) => (m['paidOn'], m['amountPaise'])), <(String, int)>[
        ('2026-09-15', 1000000),
        ('2026-09-22', 1000000),
        ('2026-09-29', 1000000),
        ('2026-10-06', 1000000),
        ('2026-10-13', 1000000),
        ('2026-10-20', 500000),
      ]);
      for (final m in txs) {
        expect(m['origin'], 'onboarding');
        expect(m['recordedBy'], kOwnerUid);
        expect(m['recordedByName'], 'Ravi');
        expect(m['recordedAt'], isA<Timestamp>());
        expect(m['clientRecordedAt'], isA<Timestamp>());
        expect(m['paidOn'], isNot('2026-11-24'));
      }
      for (final m in pays) {
        expect(m['openingBalance'], true);
        expect(m['mode'], 'cash');
        expect(m['note'], 'Opening balance');
      }
      expect(
        txs.singleWhere((m) => m['type'] == 'disbursement')['paidOn'],
        '2026-09-08',
      );
    });

    test('as of today: rows 6–10 partial/overdue with days late, '
        'extensions at the end, outstanding ₹45,000', () async {
      final r = await contracts.onboardContract(weekly());
      final p = await projectSaved(r.id);
      final base = p.rows.where((ProjectedRow x) => !x.isExtension).toList();
      expect(
        base.take(5).every((ProjectedRow x) => x.status == RowStatus.paid),
        isTrue,
      );
      expect(
        base.skip(5).map((ProjectedRow x) => (x.status, x.paid, x.daysOverdue)),
        <(RowStatus, Money, int)>[
          (RowStatus.overdue, rs(5000), 35),
          (RowStatus.overdue, Money.zero, 28),
          (RowStatus.overdue, Money.zero, 21),
          (RowStatus.overdue, Money.zero, 14),
          (RowStatus.overdue, Money.zero, 7),
        ],
      );
      expect(base[5].isPartial, isTrue);
      final ext = p.extensionRows.toList();
      expect(ext, isNotEmpty);
      expect(p.rows.last.isExtension, isTrue);
      expect(
        ext.every((ProjectedRow x) => !x.dueDate.isBefore(_today)),
        isTrue,
      );
      expect(Money.sum(ext.map((ProjectedRow x) => x.remaining)), rs(45000));
      expect(p.outstanding, rs(45000));
      expect(p.overdueAmount, rs(45000));
      expect(p.overdueCount, 5);
      expect(p.maxDaysOverdue, 35);
    });

    test('dashboard: Total collected ₹55,000, chart and calendar on the '
        'original dates, received today and this month ₹0', () async {
      await contracts.onboardContract(weekly());
      final m = await portfolio();
      expect(m.totalCollected, rs(55000));
      expect(m.totalNetDisbursed, rs(95000));
      expect(m.sanctionedReceivable, rs(45000));
      expect(m.totalOverdue, rs(45000));
      expect(m.todayDue.received, Money.zero);
      expect(m.receivableBreakdown.collectedThisMonth.amount, Money.zero);
      final months = m.collectionsSeries(ChartPeriod.months6);
      expect(
        <int, Money>{for (final b in months) b.start.month: b.collected},
        <int, Money>{
          6: Money.zero,
          7: Money.zero,
          8: Money.zero,
          9: rs(30000),
          10: rs(25000),
          11: Money.zero,
        },
      );
      final sep = m.calendarBuckets(2026, 9);
      expect(
        <int>[
          for (final x in sep)
            if (x.collected.isPositive) x.date.day,
        ],
        <int>[15, 22, 29],
      );
      final oct = m.calendarBuckets(2026, 10);
      expect(
        <(int, Money)>[
          for (final x in oct)
            if (x.collected.isPositive) (x.date.day, x.collected),
        ],
        <(int, Money)>[(6, rs(10000)), (13, rs(10000)), (20, rs(5000))],
      );
    });
  });

  group('R2 daily loan, 300 itemised payments', () {
    test('2 balanced batches, totals, projection == plan preview', () async {
      final cmd = daily(itemisedDaily(300, 100));
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
      final chunks = plan.chunks(db, kCid);
      expect(chunks.batchCount, inInclusiveRange(1, 4));
      expect(chunks.chunkSizes, <int>[81, 219]);
      expect(chunks.opsPerBatch, <int>[450, 220]);
      expect(chunks.chunkSums, <Money>[rs(8100), rs(21900)]);
      expect(plan.totalCollected, rs(30000));

      final r = await contracts.onboardContract(cmd);
      final c = await rawContract(db, r.id);
      final pays = (await rawDocs(
        db,
        'transactions',
        r.id,
      )).where((m) => m['type'] == 'payment').toList();
      expect(pays, hasLength(300));
      final sum = pays.fold<int>(0, (s, m) => s + (m['amountPaise'] as int));
      expect(sum, 3000000);
      expect(c['totalPaidPaise'], sum);
      expect(pays.every((m) => m['openingBalance'] == false), isTrue);

      final preview = projectContract(
        contract: plan.contract,
        installments: plan.installments,
        transactions: plan.transactions,
        today: _today,
      );
      final saved = await projectSaved(r.id);
      expect(saved.totalPaid, preview.totalPaid);
      expect(saved.outstanding, preview.outstanding);
      expect(saved.overdueAmount, preview.overdueAmount);
      expect(saved.overdueCount, preview.overdueCount);
      expect(saved.maxDaysOverdue, preview.maxDaysOverdue);
      expect(saved.maturityDate, preview.maturityDate);
      expect(saved.cyclesPaid, preview.cyclesPaid);
      expect(saved.cyclesTotal, preview.cyclesTotal);
      expect(
        saved.rows.map(
          (ProjectedRow x) =>
              (x.seq, x.dueDate, x.due, x.paid, x.status, x.daysOverdue),
        ),
        preview.rows.map(
          (ProjectedRow x) =>
              (x.seq, x.dueDate, x.due, x.paid, x.status, x.daysOverdue),
        ),
      );
    });

    test('1,100 payments → 4 batches, each balanced, Σ == totalPaid', () async {
      final cmd = daily(itemisedDaily(1100, 10));
      final plan = planOnboarding(
        terms: cmd,
        pastPayments: cmd.pastPayments,
        today: _today,
        contractId: 'x',
        borrowerId: 'b1',
        borrowerName: 'Anita Sharma',
        borrowerPhoneE164: '+919845012890',
        now: DateTime.utc(2026, 11, 24),
        uuid: const Uuid(),
      );
      final chunks = plan.chunks(db, kCid);
      expect(chunks.opsPerBatch, <int>[450, 450, 450, 122]);
      expect(chunks.chunkSums, <Money>[rs(810), rs(4490), rs(4490), rs(1210)]);
      final r = await contracts.onboardContract(cmd);
      expect((await rawContract(db, r.id))['totalPaidPaise'], 1100000);
    });
  });

  group('R3 refusals write nothing', () {
    PastPaymentInput pay(CivilDate on, int rupees, {PaymentMode? mode}) =>
        PastPaymentInput(paidOn: on, amount: rs(rupees), mode: mode);

    final cases = <String, (OnboardContractCommand Function(), String)>{};
    setUp(() {
      cases
        ..clear()
        ..addAll(<String, (OnboardContractCommand Function(), String)>{
          'opening total == sanctioned (fully repaid)': (
            () => weekly(past: opening(100000)),
            LedgerFields.openingTotal,
          ),
          'total > sanctioned': (
            () => weekly(
              past: <PastPaymentInput>[
                pay(_firstDue, 100000, mode: PaymentMode.cash),
                pay(_firstDue, 1, mode: PaymentMode.cash),
              ],
            ),
            LedgerFields.pastPayments,
          ),
          'a payment before disbursedOn': (
            () => weekly(
              past: <PastPaymentInput>[
                pay(_disbursed.addDays(-1), 100, mode: PaymentMode.cash),
              ],
            ),
            LedgerFields.pastPayment(0),
          ),
          'a future payment': (
            () => weekly(
              past: <PastPaymentInput>[
                pay(_today.addDays(1), 100, mode: PaymentMode.upi),
              ],
            ),
            LedgerFields.pastPayment(0),
          ),
          'disbursedOn more than 3 years back': (
            () => weekly(
              disbursedOn: _today.addDays(-1097),
              firstDue: _today.addDays(-1090),
              past: const <PastPaymentInput>[],
            ),
            LedgerFields.disbursedOn,
          ),
          'firstDueDate before disbursedOn': (
            () => weekly(firstDue: _disbursed.addDays(-1)),
            LedgerFields.firstDueDate,
          ),
          'firstDueDate more than 366 days after disbursedOn': (
            () => weekly(
              firstDue: _disbursed.addDays(367),
              past: const <PastPaymentInput>[],
            ),
            LedgerFields.firstDueDate,
          ),
          'a missing mode': (
            () => weekly(past: <PastPaymentInput>[pay(_firstDue, 100)]),
            LedgerFields.pastPayment(0),
          ),
          'previousRef longer than 40 characters': (
            () => weekly(previousRef: 'R' * 41),
            LedgerFields.previousRef,
          ),
          '1,101 itemised payments': (
            () => daily(itemisedDaily(1101, 10)),
            LedgerFields.pastPayments,
          ),
        });
    });

    for (final name in <String>[
      'opening total == sanctioned (fully repaid)',
      'total > sanctioned',
      'a payment before disbursedOn',
      'a future payment',
      'disbursedOn more than 3 years back',
      'firstDueDate before disbursedOn',
      'firstDueDate more than 366 days after disbursedOn',
      'a missing mode',
      'previousRef longer than 40 characters',
      '1,101 itemised payments',
    ]) {
      test(name, () async {
        final (build, field) = cases[name]!;
        await expectLater(
          contracts.onboardContract(build()),
          throwsA(
            isA<ValidationFailure>().having(
              (ValidationFailure f) => f.field,
              'field',
              field,
            ),
          ),
        );
        await expectNothingWritten();
      });
    }

    test('a collector, or a null role', () async {
      for (final role in <Role?>[Role.collector, null]) {
        await expectLater(
          contracts.onboardContract(weekly(role: role)),
          throwsA(isA<PermissionDeniedFailure>()),
          reason: '$role',
        );
      }
      await expectNothingWritten();
    });

    test('edge: previousRef of exactly 40 characters is stored', () async {
      final r = await contracts.onboardContract(weekly(previousRef: 'R' * 40));
      expect((await rawContract(db, r.id))['previousRef'], 'R' * 40);
    });
  });

  test('R4 upfront ₹0 is allowed: net disbursed = sanctioned', () async {
    final r = await contracts.onboardContract(weekly(upfrontInput: 0));
    final c = await rawContract(db, r.id);
    expect(c['upfrontPaise'], 0);
    expect(c['netDisbursedPaise'], 10000000);
    expect(
      (await rawDocs(
        db,
        'transactions',
        r.id,
      )).singleWhere((m) => m['type'] == 'disbursement')['amountPaise'],
      10000000,
    );
    expect((await portfolio()).totalNetDisbursed, rs(100000));
  });

  group('R5 reversals', () {
    test('one onboarding payment: dated on its original date, origin and '
        'mode copied; outstanding up, received today unchanged', () async {
      final r = await contracts.onboardContract(
        weekly(
          past: <PastPaymentInput>[
            PastPaymentInput(
              paidOn: d(2026, 9, 15),
              amount: rs(10000),
              mode: PaymentMode.upi,
            ),
            PastPaymentInput(
              paidOn: d(2026, 9, 22),
              amount: rs(10000),
              mode: PaymentMode.bank,
            ),
          ],
        ),
      );
      final before = await portfolio();
      expect(before.sanctionedReceivable, rs(80000));
      final snap = await readSnapshot(db, r.id);
      final original = snap.transactions.firstWhere(
        (LedgerTransaction t) => t.paidOn == d(2026, 9, 22),
      );
      await payments.reversePayment(
        ReversePaymentCommand(
          cid: kCid,
          snapshot: snap,
          transactionId: original.id,
          reason: 'Not paid',
          today: _today,
          actor: kActor,
        ),
      );
      final rev = (await rawDocs(
        db,
        'transactions',
        r.id,
      )).singleWhere((m) => m['type'] == 'reversal');
      expect(rev['paidOn'], '2026-09-22');
      expect(rev['origin'], 'onboarding');
      expect(rev['mode'], 'bank');
      expect(rev['openingBalance'], false);
      expect(rev['reversesTxId'], original.id);
      expect(rev['recordedBy'], kOwnerUid);
      expect(rev['recordedAt'], isA<Timestamp>());

      final after = await portfolio();
      expect(after.sanctionedReceivable, rs(90000));
      expect(after.totalCollected, rs(10000));
      expect(after.todayDue.received, Money.zero);
      expect(after.receivableBreakdown.collectedThisMonth.amount, Money.zero);
      expect(after.calendarBuckets(2026, 9)[21].collected, Money.zero);
    });

    test('reverseOpeningBalance reverses only the opening rows (itemised '
        'and live payments untouched); a second run writes nothing', () async {
      // Mixed command: 6 spread rows + 1 itemised row (the repository accepts
      // both kinds in one command).
      final r = await contracts.onboardContract(
        weekly(
          past: <PastPaymentInput>[
            ...opening(55000),
            PastPaymentInput(
              paidOn: d(2026, 11, 3),
              amount: rs(2000),
              mode: PaymentMode.upi,
            ),
          ],
        ),
      );
      await payments.recordPayment(
        RecordPaymentCommand(
          cid: kCid,
          snapshot: await readSnapshot(db, r.id),
          amount: rs(3000),
          paidOn: _today,
          mode: PaymentMode.cash,
          actor: kActor,
        ),
      );
      final snap = await readSnapshot(db, r.id);
      expect(unreversedOpeningBalance(snap), hasLength(6));
      final res = await payments.reverseOpeningBalance(
        ReverseOpeningCommand(
          cid: kCid,
          snapshot: snap,
          reason: 'Wrong total',
          actor: kActor,
          role: Role.owner,
        ),
      );
      expect(res.balanceAfter, rs(95000));
      final txs = await rawDocs(db, 'transactions', r.id);
      final revs = txs.where((m) => m['type'] == 'reversal').toList();
      expect(revs, hasLength(6));
      final openingIds = <Object?>{
        for (final m in txs)
          if (m['type'] == 'payment' && m['openingBalance'] == true) m['id'],
      };
      expect(revs.map((m) => m['reversesTxId']).toSet(), openingIds);
      for (final rev in revs) {
        final o = txs.singleWhere((m) => m['id'] == rev['reversesTxId']);
        expect(rev['paidOn'], o['paidOn']);
        expect(rev['mode'], o['mode']);
        expect(rev['origin'], 'onboarding');
      }
      expect((await rawContract(db, r.id))['totalPaidPaise'], 500000);
      final m = await portfolio();
      expect(m.totalCollected, rs(5000));
      expect(m.todayDue.received, rs(3000), reason: 'only the live payment');

      final count = txs.length;
      await expectLater(
        payments.reverseOpeningBalance(
          ReverseOpeningCommand(
            cid: kCid,
            snapshot: await readSnapshot(db, r.id),
            reason: 'Again',
            actor: kActor,
            role: Role.owner,
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await rawDocs(db, 'transactions', r.id), hasLength(count));
      expect((await rawContract(db, r.id))['totalPaidPaise'], 500000);
    });
  });

  group('R6 live payments on an onboarded loan', () {
    test('a payment today is origin live, counts today, and can close the '
        'loan', () async {
      final r = await contracts.onboardContract(weekly());
      final res = await payments.recordPayment(
        RecordPaymentCommand(
          cid: kCid,
          snapshot: await readSnapshot(db, r.id),
          amount: rs(45000),
          paidOn: _today,
          mode: PaymentMode.upi,
          actor: kActor,
        ),
      );
      expect(res.closed, isTrue);
      final live = (await rawDocs(
        db,
        'transactions',
        r.id,
      )).singleWhere((m) => m['id'] == res.id);
      expect(live['origin'], 'live');
      expect(live['openingBalance'], false);
      expect(live['paidOn'], '2026-11-24');
      final c = await rawContract(db, r.id);
      expect(c['status'], 'closed');
      expect(c['totalPaidPaise'], 10000000);
      expect(c['origin'], 'onboarded', reason: 'unchanged by the close');
      for (final col in <String>['installments', 'transactions']) {
        for (final m in await rawDocs(db, col, r.id)) {
          expect(m['contractActive'], false, reason: '$col ${m['id']}');
        }
      }
    });

    test('a partial live payment today: received today = amount', () async {
      final r = await contracts.onboardContract(weekly());
      await payments.recordPayment(
        RecordPaymentCommand(
          cid: kCid,
          snapshot: await readSnapshot(db, r.id),
          amount: rs(5000),
          paidOn: _today,
          mode: PaymentMode.cash,
          actor: kActor,
        ),
      );
      final m = await portfolio();
      expect(m.todayDue.received, rs(5000));
      expect(m.totalCollected, rs(60000));
      expect(m.sanctionedReceivable, rs(40000));
      expect((await projectSaved(r.id)).overdueCount, 4);
    });
  });

  group('R7 doc shapes (mirrored by the rules replay)', () {
    test(
      'contract / installment / tx keys are exactly the mirrored sets',
      () async {
        final r = await contracts.onboardContract(weekly());
        expect((await rawContract(db, r.id)).keys.toSet(), kContractKeys);
        for (final m in await rawDocs(db, 'installments', r.id)) {
          expect(m.keys.toSet()..remove('id'), kInstallmentKeys);
        }
        for (final m in await rawDocs(db, 'transactions', r.id)) {
          expect(m.keys.toSet()..remove('id'), kTxKeys);
        }
      },
    );
  });

  group('R8 backward compatibility', () {
    test('old docs without the new fields read with the defaults and take a '
        'payment as before', () async {
      final legacy = makeContract(id: 'old', upfrontInput: 0);
      final raw = ModelCodecs.contract.toFirestore(legacy, null)
        ..remove('origin')
        ..remove('onboardedOn')
        ..remove('previousRef');
      await db.doc('companies/$kCid/contracts/old').set(raw);
      for (final i in scheduleFor(legacy)) {
        await TypedRefs(db).installment(kCid, i.id).set(i);
      }
      final oldTx = tx('old', rs(10000), d(2023, 10, 31), id: 'old-p');
      final rawTx = ModelCodecs.transaction.toFirestore(oldTx, null)
        ..remove('origin')
        ..remove('openingBalance');
      await db.doc('companies/$kCid/transactions/old-p').set(rawTx);
      await db.doc('companies/$kCid/contracts/old').update(<String, Object?>{
        'totalPaidPaise': 1000000,
      });

      final snap = await readSnapshot(db, 'old');
      expect(snap.contract.origin, ContractOrigin.standard);
      expect(snap.contract.onboardedOn, isNull);
      expect(snap.contract.previousRef, isNull);
      expect(snap.contract.isOnboarded, isFalse);
      final t = snap.transactions.single;
      expect(t.origin, TxOrigin.live);
      expect(t.openingBalance, isFalse);
      expect(t.isOnboarding, isFalse);
      expect(unreversedOpeningBalance(snap), isEmpty);

      final res = await payments.recordPayment(
        RecordPaymentCommand(
          cid: kCid,
          snapshot: snap,
          amount: rs(1000),
          paidOn: _today,
          mode: PaymentMode.cash,
          actor: kActor,
        ),
      );
      final written = (await rawDocs(
        db,
        'transactions',
        'old',
      )).singleWhere((m) => m['id'] == res.id);
      expect(written['origin'], 'live');
      expect(written['openingBalance'], false);
      // A live reversal of the old payment is still dated today.
      await payments.reversePayment(
        ReversePaymentCommand(
          cid: kCid,
          snapshot: await readSnapshot(db, 'old'),
          transactionId: 'old-p',
          reason: 'x',
          today: _today,
          actor: kActor,
        ),
      );
      final rev = (await rawDocs(
        db,
        'transactions',
        'old',
      )).singleWhere((m) => m['type'] == 'reversal');
      expect(rev['paidOn'], '2026-11-24');
      expect(rev['origin'], 'live');
    });

    test('createContract still writes a standard contract with a live '
        'disbursement dated as given and totalPaid 0', () async {
      final r = await contracts.createContract(
        CreateContractCommand(
          cid: kCid,
          borrower: anita(),
          sanctioned: rs(50000),
          upfrontMode: UpfrontMode.flat,
          upfrontInput: 0,
          installmentAmount: rs(5000),
          frequency: Frequency.weekly,
          preferredWeekday: 2,
          firstDueDate: d(2026, 12, 1),
          disbursedOn: _today,
          cachedNextLoanNo: 3,
          actor: kActor,
        ),
      );
      final c = await rawContract(db, r.id);
      expect(c.keys.toSet(), kContractKeys);
      expect(c['origin'], 'standard');
      expect(c['onboardedOn'], isNull);
      expect(c['previousRef'], isNull);
      expect(c['totalPaidPaise'], 0);
      final disb = (await rawDocs(db, 'transactions', r.id)).single;
      expect(disb['origin'], 'live');
      expect(disb['openingBalance'], false);
      expect(disb['paidOn'], '2026-11-24');
    });
  });
}
