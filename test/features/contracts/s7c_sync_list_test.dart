import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/contracts/application/onboarding_resumer.dart';
import 'package:nordic_ledger/features/contracts/data/contract_repository.dart';
import 'package:nordic_ledger/features/dashboard/application/portfolio_providers.dart';
import 'package:nordic_ledger/features/payments/data/payment_repository.dart';
import 'package:uuid/uuid.dart';

import '../payments/payment_test_support.dart';

/// Sprint 7c attempt 4: the onboarding sync list.
///
/// Production root cause (device, 2026-11-26): later onboarding batches
/// were evaluated before batch 1 (437 writes) had landed, so the contract
/// did not exist for their rules; capping the payments per batch (100,
/// then 10) changed nothing, while sending the rest only after batch 1's
/// ack synced all 328 payments. Batch 1 now carries a durable queue doc;
/// a resumer writes the rest only once batch 1 is on the server.
final CivilDate _today = d(2026, 11, 24);

/// Records each committed batch (for "one batch at a time" checks).
final class _CountingDb extends FakeFirebaseFirestore {
  int batches = 0;

  @override
  WriteBatch batch() {
    batches++;
    return super.batch();
  }
}

void main() {
  late _CountingDb db;
  late ContractRepository contracts;
  late PaymentRepository payments;

  setUp(() async {
    db = _CountingDb();
    contracts = ContractRepository(firestore: db, clock: clockAt(_today));
    payments = PaymentRepository(firestore: db, clock: clockAt(_today));
    await seedCompany(db);
  });

  /// Daily ₹1,00,000 at ₹300 (334 rows) like the smoke test, with [n]
  /// itemised payments of ₹10 (oldest first).
  OnboardContractCommand daily(int n, {Role? role = Role.owner}) {
    final first = _today.addDays(-399);
    return OnboardContractCommand(
      cid: kCid,
      borrower: anita(),
      sanctioned: rs(100000),
      upfrontMode: UpfrontMode.flat,
      upfrontInput: 0,
      installmentAmount: rs(300),
      frequency: Frequency.daily,
      firstDueDate: first,
      disbursedOn: _today.addDays(-400),
      cachedNextLoanNo: 3,
      actor: kActor,
      role: role,
      today: _today,
      pastPayments: <PastPaymentInput>[
        for (var i = 0; i < n; i++)
          PastPaymentInput(
            paidOn: first.addDays(i % 330),
            amount: rs(10),
            mode: PaymentMode.values[i % 3],
            openingBalance: i.isEven,
          ),
      ],
    );
  }

  ResumeOnboardingCommand resumeCmd(String id, {Role? role = Role.owner}) =>
      ResumeOnboardingCommand(
        cid: kCid,
        contractId: id,
        actor: kActor,
        role: role,
      );

  Future<Map<String, dynamic>?> queueRaw(String id) async =>
      (await db.doc('companies/$kCid/onboardingQueues/$id').get()).data();

  Future<List<Map<String, dynamic>>> paymentsRaw(String id) async =>
      <Map<String, dynamic>>[
        for (final m in await rawDocs(db, 'transactions', id))
          if (m['type'] == 'payment') m,
      ];

  group('batch 1 + sync list', () {
    test('only batch 1 is written: contract, schedule, 100 payments and the '
        'queue with the other 228 (compact entries)', () async {
      final r = await contracts.onboardContract(daily(328));
      expect(db.batches, 1);
      expect(await paymentsRaw(r.id), hasLength(100));
      expect(await rawDocs(db, 'installments', r.id), hasLength(334));
      final c = await rawContract(db, r.id);
      expect(c['totalPaidPaise'], 100 * 1000);
      expect(c['onboardedPaymentCount'], 328);
      final q = (await queueRaw(r.id))!;
      expect(q['status'], 'pending');
      expect(q['count'], 228);
      expect(q['totalPaise'], 228 * 1000);
      expect(q['createdBy'], kOwnerUid);
      final first = (q['entries'] as List<Object?>).first! as Map;
      expect(first.keys.toSet(), <String>{'i', 'd', 'a', 'm', 'o'});
      // The queue ids are the pre-generated tx ids the resumer will use.
      final queued = OnboardingQueue.fromFirestore(q);
      expect(queued.entries.first.amount, rs(10));
      expect(
        queued.entries.map((QueuedPayment e) => e.id).toSet(),
        hasLength(228),
      );
    });

    test('no queue when batch 1 holds every payment', () async {
      final r = await contracts.onboardContract(daily(50));
      expect(await queueRaw(r.id), isNull);
      expect(
        await contracts.resumeOnboarding(resumeCmd(r.id)),
        ResumeOutcome.nothingQueued,
      );
    });

    test('1,100 entries stay far below 1 MiB', () {
      final cmd = daily(1100);
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
      final q = plan.queue()!;
      expect(q.entries, hasLength(1000));
      // Rough size: keys + 36-char ids + dates + ints per entry.
      final bytes = q.entries
          .map((QueuedPayment e) => e.toMap().toString().length)
          .fold<int>(0, (int a, int b) => a + b);
      expect(bytes, lessThan(120 * 1000));
    });
  });

  group('resumer', () {
    test('completes the onboarding one balanced batch at a time', () async {
      final r = await contracts.onboardContract(daily(328));
      final before = db.batches;
      expect(
        await contracts.resumeOnboarding(resumeCmd(r.id)),
        ResumeOutcome.complete,
      );
      expect(db.batches - before, 3); // 100 + 100 + 28
      final pays = await paymentsRaw(r.id);
      expect(pays, hasLength(328));
      final sum = pays.fold<int>(
        0,
        (int s, m) => s + (m['amountPaise'] as int),
      );
      expect((await rawContract(db, r.id))['totalPaidPaise'], sum);
      expect(sum, 328 * 1000);
      expect((await queueRaw(r.id))!['status'], 'complete');
      for (final m in pays) {
        expect(m['origin'], 'onboarding');
        expect(m['recordedBy'], kOwnerUid);
        expect(m['mode'], isIn(<String>['upi', 'cash', 'bank']));
        expect(
          m['note'],
          m['openingBalance'] == true ? 'Opening balance' : null,
        );
      }
      final sync = OnboardingSync.of(await readSnapshot(db, r.id))!;
      expect(sync.isIncomplete, isFalse);
      expect(sync.isOvershoot, isFalse);
      // A second run has nothing to do.
      expect(
        await contracts.resumeOnboarding(resumeCmd(r.id)),
        ResumeOutcome.nothingQueued,
      );
    });

    test('idempotent: queued payments that already landed are skipped and '
        'never counted twice', () async {
      final r = await contracts.onboardContract(daily(328));
      final q = OnboardingQueue.fromFirestore((await queueRaw(r.id))!);
      // An earlier resumer run landed the first 30 queued payments with
      // their own increment, then stopped.
      final c = (await TypedRefs(db).contract(kCid, r.id).get()).data()!;
      final b = db.batch()
        ..update(db.doc('companies/$kCid/contracts/${r.id}'), <String, Object?>{
          'totalPaidPaise': FieldValue.increment(30 * 1000),
        });
      for (final e in q.entries.take(30)) {
        b.set(
          TypedRefs(db).transaction(kCid, e.id),
          onboardingPaymentTx(
            id: e.id,
            c: c,
            paidOn: e.paidOn,
            amount: e.amount,
            mode: e.mode,
            actor: kActor,
            now: DateTime.utc(2026, 11, 24),
          ),
        );
      }
      await b.commit();
      expect(
        await contracts.resumeOnboarding(resumeCmd(r.id)),
        ResumeOutcome.complete,
      );
      final pays = await paymentsRaw(r.id);
      expect(pays, hasLength(328));
      expect(pays.map((m) => m['id']).toSet(), hasLength(328));
      expect((await rawContract(db, r.id))['totalPaidPaise'], 328 * 1000);
    });

    test('offline / batch 1 not on the server yet: the queue waits; the '
        'resumer finishes it later', () async {
      final cmd = daily(328);
      final plan = planOnboarding(
        terms: cmd,
        pastPayments: cmd.pastPayments,
        today: _today,
        contractId: 'late',
        borrowerId: 'b1',
        borrowerName: 'Anita Sharma',
        borrowerPhoneE164: '+919845012890',
        now: DateTime.utc(2026, 11, 24),
        uuid: const Uuid(),
      );
      // The sync list is known (it is in batch 1 in the local cache), but
      // the server has no contract yet.
      await db
          .doc('companies/$kCid/onboardingQueues/late')
          .set(plan.queue()!.toFirestore());
      expect(
        await contracts.resumeOnboarding(resumeCmd('late')),
        ResumeOutcome.notReady,
      );
      expect(await paymentsRaw('late'), isEmpty);
      // Back online: batch 1 lands; the next trigger completes it.
      await plan.firstBatch(db, kCid).commit();
      expect(
        await contracts.resumeOnboarding(resumeCmd('late')),
        ResumeOutcome.complete,
      );
      expect(await paymentsRaw('late'), hasLength(328));
      expect((await rawContract(db, 'late'))['totalPaidPaise'], 328 * 1000);
    });

    test('a collector never resumes', () async {
      final r = await contracts.onboardContract(daily(328));
      final before = db.batches;
      expect(
        await contracts.resumeOnboarding(resumeCmd(r.id, role: Role.collector)),
        ResumeOutcome.notOwner,
      );
      expect(
        await contracts.resumeOnboarding(resumeCmd(r.id, role: null)),
        ResumeOutcome.notOwner,
      );
      expect(db.batches, before);
      expect(await paymentsRaw(r.id), hasLength(100));

      final container = ProviderContainer(
        overrides: contractOverrides(db, role: Role.collector),
      );
      addTearDown(container.dispose);
      expect(
        await container.read(onboardingResumerProvider).resume(r.id),
        isNull,
      );
      expect(await paymentsRaw(r.id), hasLength(100));
    });

    test('the owner resumer provider finishes a pending queue', () async {
      final r = await contracts.onboardContract(daily(328));
      final container = ProviderContainer(overrides: contractOverrides(db));
      addTearDown(container.dispose);
      expect(
        await container.read(onboardingResumerProvider).resume(r.id),
        ResumeOutcome.complete,
      );
      expect(await paymentsRaw(r.id), hasLength(328));
    });

    test('a cancelled contract stops the resumer', () async {
      final r = await contracts.onboardContract(daily(328));
      await db.doc('companies/$kCid/contracts/${r.id}').update(
        <String, Object?>{'status': 'cancelled'},
      );
      expect(
        await contracts.resumeOnboarding(resumeCmd(r.id)),
        ResumeOutcome.stopped,
      );
      expect(await paymentsRaw(r.id), hasLength(100));
    });
  });

  group('Cancel onboarded loan', () {
    Future<String> onboardAll(int n) async {
      final r = await contracts.onboardContract(daily(n));
      await contracts.resumeOnboarding(resumeCmd(r.id));
      return r.id;
    }

    CancelOnboardedCommand cancel(
      ContractSnapshot s, {
      Role? role = Role.owner,
      String reason = 'Onboarded by mistake',
      bool queuePending = false,
    }) => CancelOnboardedCommand(
      cid: kCid,
      snapshot: s,
      reason: reason,
      actor: kActor,
      role: role,
      queuePending: queuePending,
    );

    test('reverses every onboarding payment on its own date in batches of '
        '≤ 100, then cancels; every doc goes inactive', () async {
      final id = await onboardAll(250);
      final before = db.batches;
      await payments.cancelOnboardedLoan(cancel(await readSnapshot(db, id)));
      final s = await readSnapshot(db, id);
      expect(s.contract.status, ContractStatus.cancelled);
      expect(s.contract.totalPaid, Money.zero);
      final revs = s.transactions
          .where((LedgerTransaction t) => t.type == TxType.reversal)
          .toList();
      expect(revs, hasLength(250));
      final byId = <String, LedgerTransaction>{
        for (final t in s.transactions) t.id: t,
      };
      for (final v in revs) {
        final o = byId[v.reversesTxId]!;
        expect(v.paidOn, o.paidOn);
        expect(v.mode, o.mode);
        expect(v.origin, TxOrigin.onboarding);
        expect(v.note, 'Onboarded by mistake');
      }
      // 100 + 100 + 50 reversals, then the status + flips (> 450 ops).
      expect(db.batches - before, greaterThanOrEqualTo(4));
      expect(
        s.installments.every((Installment i) => !i.contractActive),
        isTrue,
      );
      expect(
        s.transactions.every((LedgerTransaction t) => !t.contractActive),
        isTrue,
      );
    });

    test('a pending sync list is marked cancelled with the status', () async {
      final r = await contracts.onboardContract(daily(328));
      await payments.cancelOnboardedLoan(
        cancel(await readSnapshot(db, r.id), queuePending: true),
      );
      expect((await queueRaw(r.id))!['status'], 'cancelled');
      expect(
        await contracts.resumeOnboarding(resumeCmd(r.id)),
        ResumeOutcome.nothingQueued,
      );
      final s = await readSnapshot(db, r.id);
      expect(s.contract.status, ContractStatus.cancelled);
      expect(s.contract.totalPaid, Money.zero);
    });

    test('refusals: collector, no reason, live payments, standard, rolled '
        'over', () async {
      final id = await onboardAll(20);
      final s = await readSnapshot(db, id);
      await expectLater(
        payments.cancelOnboardedLoan(cancel(s, role: Role.collector)),
        throwsA(isA<PermissionDeniedFailure>()),
      );
      await expectLater(
        payments.cancelOnboardedLoan(cancel(s, reason: '  ')),
        throwsA(isA<ValidationFailure>()),
      );
      final withLive = ContractSnapshot(
        contract: s.contract,
        installments: s.installments,
        transactions: <LedgerTransaction>[
          ...s.transactions,
          tx(id, rs(300), _today, id: 'live-1'),
        ],
      );
      expect(
        cancelOnboardedBlocker(withLive),
        contains('Reverse the payments recorded after onboarding'),
      );
      await expectLater(
        payments.cancelOnboardedLoan(cancel(withLive)),
        throwsA(isA<ValidationFailure>()),
      );
      for (final c in <Contract>[
        s.contract.copyWith(origin: ContractOrigin.standard),
        s.contract.copyWith(status: ContractStatus.rolledOver),
      ]) {
        await expectLater(
          payments.cancelOnboardedLoan(
            cancel(
              ContractSnapshot(
                contract: c,
                installments: s.installments,
                transactions: s.transactions,
              ),
            ),
          ),
          throwsA(isA<ValidationFailure>()),
        );
      }
      expect(
        (await readSnapshot(db, id)).contract.status,
        ContractStatus.active,
      );
      // Attempt 5 (F2): a cancelled loan with unreversed onboarding payments
      // is no longer refused; it can be finished ("Finish cancelling").
      expect(
        cancelOnboardedBlocker(
          ContractSnapshot(
            contract: s.contract.copyWith(status: ContractStatus.cancelled),
            installments: s.installments,
            transactions: s.transactions,
          ),
        ),
        isNull,
      );
    });
  });

  group('KPI exclusion of a cancelled onboarded loan', () {
    test('it drops out of net disbursed, receivable, collected, overdue, '
        'the chart and the calendar', () async {
      final r = await contracts.onboardContract(daily(250));
      await contracts.resumeOnboarding(resumeCmd(r.id));
      await payments.cancelOnboardedLoan(
        CancelOnboardedCommand(
          cid: kCid,
          snapshot: await readSnapshot(db, r.id),
          reason: 'Wrong loan',
          actor: kActor,
          role: Role.owner,
        ),
      );
      // What the dashboard listeners load: active contracts / txs (none),
      // history contracts (closed / rolled over: none) and inactive txs in
      // the window (the cancelled loan's).
      final refs = TypedRefs(db);
      final active = await refs
          .contracts(kCid)
          .where('status', isEqualTo: 'active')
          .get();
      expect(active.docs, isEmpty);
      final inactive = await refs
          .transactions(kCid)
          .where('contractActive', isEqualTo: false)
          .get();
      expect(inactive.docs, isNotEmpty);
      final txs = dashboardTransactions(
        active: const <LedgerTransaction>[],
        history: <LedgerTransaction>[for (final d in inactive.docs) d.data()],
        historyContractIds: const <String>{},
      );
      expect(txs, isEmpty);
      final m = computePortfolio(
        projections: const <ContractProjection>[],
        allTransactions: txs,
        today: _today,
        contractsById: const <String, Contract>{},
      );
      expect(m.totalNetDisbursed, Money.zero);
      expect(m.sanctionedReceivable, Money.zero);
      expect(m.totalCollected, Money.zero);
      expect(m.totalOverdue, Money.zero);
      expect(m.overdueList, isEmpty);
      for (final day in m.calendarBuckets(_today.year, _today.month)) {
        expect(day.collectedCount, 0);
      }
      expect(
        SeriesTotals.of(m.collectionsSeries(ChartPeriod.months12)).collected,
        Money.zero,
      );
    });

    test('dashboardTransactions keeps active txs and closed / rolled-over '
        'history, drops other inactive ones; active wins by id', () {
      final a = tx('A', rs(10), _today, id: 'a');
      final h = tx('H', rs(20), _today, id: 'h');
      final x = tx('X', rs(30), _today, id: 'x');
      final dupHistory = tx('A', rs(99), _today, id: 'a');
      final out = dashboardTransactions(
        active: <LedgerTransaction>[a],
        history: <LedgerTransaction>[h, x, dupHistory],
        historyContractIds: const <String>{'H', 'A'},
      );
      expect(out.map((LedgerTransaction t) => t.id).toSet(), <String>{
        'a',
        'h',
      });
      expect(
        out.firstWhere((LedgerTransaction t) => t.id == 'a').amount,
        rs(10),
      );
    });
  });
}
