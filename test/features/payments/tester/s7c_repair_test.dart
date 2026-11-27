import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/firebase/balanced_chunks.dart'
    show maxLedgerItemsPerBatch;
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/contracts/data/contract_repository.dart';
import 'package:nordic_ledger/features/payments/data/payment_repository.dart';
import 'package:uuid/uuid.dart';

import '../../contracts/contract_widget_harness.dart';
import '../payment_test_support.dart';

// Tester, Sprint 7c: M1 (installment spill + balanced increments), M2
// (incomplete banner + repair), L2 (no reversal on rolled-over/cancelled,
// closed still reopens) and "Reverse opening balance" from the UI.
// Today: Tue 7 Nov 2023 (fixtureClock).

/// A fake Firestore on which only the first [landed] batches ever reach
/// the store; later batches "never sync" (their commit resolves, nothing
/// is written), as when the device dies between chunks.
final class _PartialDb extends FakeFirebaseFirestore {
  _PartialDb(this.landed);

  final int landed;
  int _made = 0;

  @override
  WriteBatch batch() => _made++ < landed ? super.batch() : _LostBatch();
}

final class _LostBatch implements WriteBatch {
  @override
  Future<void> commit() => Future<void>.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final CivilDate _disbursed = d(2023, 8, 29);

/// The 10-week weekly loan: ₹1,00,000 at ₹10,000 on Tuesdays from 5 Sep.
List<PlannedInstallment> _weekly() => generateSchedule(
  sanctioned: rs(100000),
  installmentAmount: rs(10000),
  frequency: Frequency.weekly,
  firstDueDate: d(2023, 9, 5),
  preferredWeekday: 2,
);

List<PastPaymentInput> _opening(int rupees) => spreadOpeningTotal(
  schedule: _weekly(),
  total: rs(rupees),
  mode: PaymentMode.cash,
  disbursedOn: _disbursed,
  today: kToday,
);

OnboardContractCommand _weeklyCmd(List<PastPaymentInput> past) =>
    OnboardContractCommand(
      cid: kCid,
      borrower: anita(),
      sanctioned: rs(100000),
      upfrontMode: UpfrontMode.flat,
      upfrontInput: 0,
      installmentAmount: rs(10000),
      frequency: Frequency.weekly,
      preferredWeekday: 2,
      firstDueDate: d(2023, 9, 5),
      disbursedOn: _disbursed,
      cachedNextLoanNo: 3,
      actor: kActor,
      role: Role.owner,
      today: kToday,
      pastPayments: past,
    );

/// Daily ₹1,00,000 at ₹500 from 2 May 2023 (200 rows) with [n] itemised
/// ₹100 payments, one a day from 2 May.
OnboardContractCommand _dailyCmd(int n) => OnboardContractCommand(
  cid: kCid,
  borrower: anita(),
  sanctioned: rs(100000),
  upfrontMode: UpfrontMode.flat,
  upfrontInput: 0,
  installmentAmount: rs(500),
  frequency: Frequency.daily,
  firstDueDate: d(2023, 5, 2),
  disbursedOn: d(2023, 5, 1),
  cachedNextLoanNo: 3,
  actor: kActor,
  role: Role.owner,
  today: kToday,
  pastPayments: <PastPaymentInput>[
    for (var i = 0; i < n; i++)
      PastPaymentInput(
        paidOn: d(2023, 5, 2).addDays(i),
        amount: rs(100),
        mode: PaymentMode.upi,
      ),
  ],
);

/// Onboards [cmd] on [db] the way the app does since 7c attempt 4: batch 1
/// (with the sync list), then the resumer. [maxItems] shrinks the
/// payments per batch. [legacyPartial] deletes the sync list afterwards,
/// which models a partly synced onboarding from an earlier build (no
/// queue to resume, so the manual repair is the fallback).
Future<String> _onboardOn(
  FakeFirebaseFirestore db,
  OnboardContractCommand cmd, {
  int maxItems = maxLedgerItemsPerBatch,
  bool legacyPartial = false,
}) async {
  await seedCompany(db);
  final repo = ContractRepository(
    firestore: db,
    clock: clockAt(kToday),
    batchMaxItems: maxItems,
  );
  final id = (await repo.onboardContract(cmd)).id;
  await repo.resumeOnboarding(
    ResumeOnboardingCommand(
      cid: kCid,
      contractId: id,
      actor: kActor,
      role: Role.owner,
    ),
  );
  if (legacyPartial) {
    await db.doc('companies/$kCid/onboardingQueues/$id').delete();
  }
  return id;
}

/// The saved docs as a seed for the widget harness.
LedgerSeed _seedOf(ContractSnapshot s) => LedgerSeed()
  ..borrowers.add(anita())
  ..contracts.add(s.contract)
  ..transactions.addAll(s.transactions);

Future<ContractSnapshot> _snap(
  WidgetTester tester,
  FakeFirebaseFirestore db,
  String id,
) async {
  late ContractSnapshot out;
  await tester.runAsync(() async => out = await readSnapshot(db, id));
  return out;
}

Future<List<Map<String, dynamic>>> _txs(
  WidgetTester tester,
  FakeFirebaseFirestore db,
) async {
  late List<Map<String, dynamic>> out;
  await tester.runAsync(() async {
    final snap = await db.collection('companies/$kCid/transactions').get();
    out = <Map<String, dynamic>>[for (final x in snap.docs) x.data()];
  });
  return out;
}

Future<Map<String, dynamic>> _contract(
  WidgetTester tester,
  FakeFirebaseFirestore db,
) async {
  late Map<String, dynamic> out;
  await tester.runAsync(() async {
    final snap = await db.collection('companies/$kCid/contracts').get();
    out = snap.docs.single.data();
  });
  return out;
}

Money _paymentSum(ContractSnapshot s) => Money.sum(<Money>[
  for (final t in s.transactions)
    if (t.type == TxType.payment) t.amount,
]);

void main() {
  group('M1: installments spill, every batch balanced', () {
    test(
      'maxItems 10: batch 1 + the resumer land every payment and installment; totals match',
      () async {
        final db = FakeFirebaseFirestore();
        final id = await _onboardOn(db, _dailyCmd(150), maxItems: 10);
        final s = await readSnapshot(db, id);
        expect(
          s.transactions.where(
            (LedgerTransaction t) => t.type == TxType.payment,
          ),
          hasLength(150),
        );
        expect(s.installments, hasLength(200));
        expect(s.contract.totalPaid, rs(15000));
        expect(s.contract.onboardedPaymentCount, 150);
        expect(s.contract.onboardedTotal, rs(15000));
      },
    );

    test('every prefix of batches that lands keeps totalPaid == Σ landed '
        'payments (balanced increments)', () async {
      final plan = planOnboarding(
        terms: _dailyCmd(150),
        pastPayments: _dailyCmd(150).pastPayments,
        today: kToday,
        contractId: 'x',
        borrowerId: 'b1',
        borrowerName: 'Anita Sharma',
        borrowerPhoneE164: '+919845012890',
        now: DateTime.utc(2023, 11, 7),
        uuid: const Uuid(),
      );
      final batches = plan.layout(maxItems: 10).batchCount;
      expect(batches, greaterThan(2));
      for (var n = 1; n <= batches; n++) {
        final db = _PartialDb(n);
        final id = await _onboardOn(db, _dailyCmd(150), maxItems: 10);
        final s = await readSnapshot(db, id);
        expect(s.contract.totalPaid, _paymentSum(s), reason: '$n batches');
        expect(s.contract.onboardedPaymentCount, 150, reason: '$n batches');
        // Attempt 4: the whole schedule is always in batch 1.
        expect(s.installments, hasLength(200));
      }
    });
  });

  group('M2: incomplete onboarding banner and repair', () {
    testWidgets(
      'first two batches only: banner reads "X of Y payments synced"',
      (WidgetTester tester) async {
        // Attempt 4: batch 1 (10 payments) and one resumed batch land; the
        // sync list is gone, as on a partial onboarding from an earlier
        // build, so the incomplete banner and the repair show.
        final db = _PartialDb(2);
        late String id;
        await tester.runAsync(
          () async => id = await _onboardOn(
            db,
            _dailyCmd(150),
            maxItems: 10,
            legacyPartial: true,
          ),
        );
        final s = await _snap(tester, db, id);
        final sync = OnboardingSync.of(s)!;
        expect(sync.expected, 150);
        expect(sync.synced, lessThan(150));
        expect(sync.synced, greaterThan(0));
        expect(s.contract.totalPaid, _paymentSum(s));

        await pumpContracts(
          tester,
          initial: '/contracts/$id',
          seed: _seedOf(s),
        );
        expect(
          find.textContaining(
            'Onboarding incomplete: ${sync.synced} of 150 payments synced',
          ),
          findsOneWidget,
        );
        expect(find.byKey(k('add_missing_onboarding_payment')), findsOneWidget);
      },
    );

    testWidgets('owner adds each missing payment; the count reconciles and '
        'the banner goes', (WidgetTester tester) async {
      // maxItems 2 → batch 1 holds 2 of the 6 spread payments; the rest
      // never land and there is no sync list (an earlier build).
      final partial = _PartialDb(1);
      late String id;
      await tester.runAsync(
        () async => id = await _onboardOn(
          partial,
          _weeklyCmd(_opening(55000)),
          maxItems: 2,
          legacyPartial: true,
        ),
      );
      final s = await _snap(tester, partial, id);
      final sync = OnboardingSync.of(s)!;
      expect(sync.expected, 6);
      final missing = 6 - sync.synced;
      expect(missing, greaterThan(0));

      final db = await pumpContracts(
        tester,
        initial: '/contracts/$id',
        seed: _seedOf(s),
      );
      for (var i = 0; i < missing; i++) {
        expect(
          find.textContaining(
            'Onboarding incomplete: ${sync.synced + i} of 6 payments synced',
          ),
          findsOneWidget,
        );
        // 7c: no ensureVisible here; it aligns the button to the top and
        // scrolls the (now taller) banner out of the lazily built list.
        await tester.tap(find.byKey(k('add_missing_onboarding_payment')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Send receipt'), findsNothing);
        // 7c R2: the repair is capped at the missing cash, and the banner
        // stays until the onboarded total is back; the last repair adds
        // the remainder.
        final amount = i < missing - 1
            ? 1000
            : 55000 - _paymentSum(s).rupeesPart - 1000 * (missing - 1);
        await typeInto(tester, 'add_onboarding_amount', '$amount');
        await tester.ensureVisible(find.byKey(k('add_onboarding_save')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(k('add_onboarding_save')));
        await pumpFrames(tester);
      }
      expect(find.byKey(k('onboarding_incomplete_banner')), findsNothing);
      final after = await _snap(tester, db, id);
      expect(OnboardingSync.of(after)!.isIncomplete, isFalse);
      expect(after.contract.totalPaid, _paymentSum(after));
      for (final m in (await _txs(tester, db)).where(
        (Map<String, dynamic> m) =>
            m['type'] == 'payment' && m['openingBalance'] == false,
      )) {
        expect(m['origin'], 'onboarding');
        expect(m['recordedBy'], kOwnerUid);
      }
    });

    testWidgets('a reversed onboarding payment raises no false banner', (
      WidgetTester tester,
    ) async {
      final full = FakeFirebaseFirestore();
      late String id;
      await tester.runAsync(
        () async => id = await _onboardOn(full, _weeklyCmd(_opening(55000))),
      );
      final db = await pumpContracts(
        tester,
        initial: '/contracts/$id',
        seed: _seedOf(await _snap(tester, full, id)),
      );
      expect(find.byKey(k('onboarding_incomplete_banner')), findsNothing);
      await tester.ensureVisible(find.text('Reverse').first);
      await tester.tap(find.text('Reverse').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(k('reverse_reason')), 'Typo');
      await tester.pump();
      await tester.tap(find.byKey(k('reverse_confirm')));
      await pumpFrames(tester);
      final txs = await _txs(tester, db);
      expect(
        txs.where((Map<String, dynamic> m) => m['type'] == 'reversal'),
        hasLength(1),
      );
      expect(find.byKey(k('onboarding_incomplete_banner')), findsNothing);
      expect(OnboardingSync.of(await _snap(tester, db, id))!.synced, 6);
    });

    testWidgets('collector: banner only, no repair; the repository refuses', (
      WidgetTester tester,
    ) async {
      final partial = _PartialDb(1);
      late String id;
      await tester.runAsync(
        () async => id = await _onboardOn(
          partial,
          _weeklyCmd(_opening(55000)),
          maxItems: 2,
          legacyPartial: true,
        ),
      );
      final s = await _snap(tester, partial, id);
      final db = await pumpContracts(
        tester,
        initial: '/contracts/$id',
        role: Role.collector,
        seed: _seedOf(s),
      );
      expect(find.byKey(k('onboarding_incomplete_banner')), findsOneWidget);
      expect(find.byKey(k('add_missing_onboarding_payment')), findsNothing);
      Object? err;
      await tester.runAsync(() async {
        try {
          await PaymentRepository(
            firestore: db,
            clock: clockAt(kToday),
          ).addOnboardingPayment(
            AddOnboardingPaymentCommand(
              cid: kCid,
              snapshot: s,
              amount: rs(1000),
              paidOn: d(2023, 10, 10),
              mode: PaymentMode.cash,
              actor: kActor,
              role: Role.collector,
            ),
          );
        } on Object catch (e) {
          err = e;
        }
      });
      expect(err, isA<PermissionDeniedFailure>());
      expect(
        OnboardingSync.of(await _snap(tester, db, id))!.synced,
        OnboardingSync.of(s)!.synced,
      );
    });
  });

  group('L2: reversal status guards', () {
    for (final status in <ContractStatus>[
      ContractStatus.rolledOver,
      ContractStatus.cancelled,
    ]) {
      testWidgets('${status.name}: Reverse and Reverse opening balance hidden '
          '@1024', (WidgetTester tester) async {
        final full = FakeFirebaseFirestore();
        late String id;
        await tester.runAsync(
          () async => id = await _onboardOn(full, _weeklyCmd(_opening(55000))),
        );
        final s = await _snap(tester, full, id);
        await pumpContracts(
          tester,
          initial: '/contracts/$id',
          width: 1024,
          seed: _seedOf(
            ContractSnapshot(
              contract: s.contract.copyWith(status: status),
              installments: s.installments,
              transactions: s.transactions,
            ),
          ),
        );
        expect(find.text('Opening balance'), findsNWidgets(6));
        expect(find.text('Reverse'), findsNothing);
        if (status == ContractStatus.rolledOver) {
          expect(find.byKey(k('contract_menu')), findsNothing);
        } else {
          // 7c attempt 5 (F2): a cancelled loan with unreversed onboarding
          // payments offers only "Finish cancelling".
          await tester.tap(find.byKey(k('contract_menu')));
          await tester.pumpAndSettle();
          expect(find.text('Reverse opening balance'), findsNothing);
          expect(find.text('Finish cancelling'), findsWidgets);
          await tester.tapAt(Offset.zero);
          await tester.pumpAndSettle();
        }
        expect(find.byKey(k('add_missing_onboarding_payment')), findsNothing);
      });
    }

    test('closed by a live payment: reverse an opening payment reopens it; '
        'reverse opening balance also allowed', () async {
      final db = FakeFirebaseFirestore();
      final id = await _onboardOn(db, _weeklyCmd(_opening(55000)));
      final payments = PaymentRepository(firestore: db, clock: clockAt(kToday));
      await payments.recordPayment(
        RecordPaymentCommand(
          cid: kCid,
          snapshot: await readSnapshot(db, id),
          amount: rs(45000),
          paidOn: kToday,
          mode: PaymentMode.cash,
          actor: kActor,
        ),
      );
      var s = await readSnapshot(db, id);
      expect(s.contract.status, ContractStatus.closed);
      final opening = unreversedOpeningBalance(s);
      await payments.reversePayment(
        ReversePaymentCommand(
          cid: kCid,
          snapshot: s,
          transactionId: opening.first.id,
          reason: 'Wrong date',
          today: kToday,
          actor: kActor,
        ),
      );
      s = await readSnapshot(db, id);
      expect(s.contract.status, ContractStatus.active);
      expect(s.outstanding, opening.first.amount);

      // Close again, then the bulk reversal on the closed loan.
      await payments.recordPayment(
        RecordPaymentCommand(
          cid: kCid,
          snapshot: s,
          amount: s.outstanding,
          paidOn: kToday,
          mode: PaymentMode.cash,
          actor: kActor,
        ),
      );
      s = await readSnapshot(db, id);
      expect(s.contract.status, ContractStatus.closed);
      await payments.reverseOpeningBalance(
        ReverseOpeningCommand(
          cid: kCid,
          snapshot: s,
          reason: 'Re-enter',
          actor: kActor,
          role: Role.owner,
        ),
      );
      s = await readSnapshot(db, id);
      expect(s.contract.status, ContractStatus.active);
      expect(unreversedOpeningBalance(s), isEmpty);
      // ₹45,000 + ₹10,000 live remain.
      expect(s.outstanding, rs(45000));
    });

    testWidgets('closed: Reverse is still offered in the UI', (
      WidgetTester tester,
    ) async {
      final full = FakeFirebaseFirestore();
      late String id;
      await tester.runAsync(() async {
        id = await _onboardOn(full, _weeklyCmd(_opening(55000)));
        final s = await readSnapshot(full, id);
        await PaymentRepository(
          firestore: full,
          clock: clockAt(kToday),
        ).recordPayment(
          RecordPaymentCommand(
            cid: kCid,
            snapshot: s,
            amount: rs(45000),
            paidOn: kToday,
            mode: PaymentMode.cash,
            actor: kActor,
          ),
        );
      });
      final s = await _snap(tester, full, id);
      expect(s.contract.status, ContractStatus.closed);
      await pumpContracts(tester, initial: '/contracts/$id', seed: _seedOf(s));
      expect(find.text('Reverse'), findsWidgets);
      expect(find.byKey(k('contract_menu')), findsOneWidget);
    });
  });

  group('Reverse opening balance from the UI', () {
    testWidgets('reason required; reverses the opening rows only; '
        'outstanding restored', (WidgetTester tester) async {
      final full = FakeFirebaseFirestore();
      late String id;
      late String liveId;
      await tester.runAsync(() async {
        id = await _onboardOn(full, _weeklyCmd(_opening(55000)));
        liveId =
            (await PaymentRepository(
                  firestore: full,
                  clock: clockAt(kToday),
                ).recordPayment(
                  RecordPaymentCommand(
                    cid: kCid,
                    snapshot: await readSnapshot(full, id),
                    amount: rs(10000),
                    paidOn: kToday,
                    mode: PaymentMode.upi,
                    actor: kActor,
                  ),
                ))
                .id;
      });
      final db = await pumpContracts(
        tester,
        initial: '/contracts/$id',
        width: 1024,
        seed: _seedOf(await _snap(tester, full, id)),
      );
      await tester.tap(find.byKey(k('contract_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reverse opening balance'));
      await tester.pumpAndSettle();
      expect(find.textContaining('6 opening-balance payments'), findsOneWidget);
      final confirm = find.byKey(k('reverse_opening_confirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(find.byKey(k('reverse_opening_reason')), '   ');
      await tester.pump();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(
        find.byKey(k('reverse_opening_reason')),
        'Wrong opening total',
      );
      await tester.pump();
      await tester.tap(confirm);
      await pumpFrames(tester);

      final txs = await _txs(tester, db);
      final reversed = <Object?>{
        for (final m in txs)
          if (m['type'] == 'reversal') m['reversesTxId'],
      };
      final openingIds = <Object?>{
        for (final t in (await _snap(tester, db, id)).transactions)
          if (t.openingBalance && t.type == TxType.payment) t.id,
      };
      expect(reversed, openingIds);
      expect(reversed, isNot(contains(liveId)));
      final c = await _contract(tester, db);
      expect(c['totalPaidPaise'], 1000000);
      expect(c['status'], 'active');
      expect((await _snap(tester, db, id)).outstanding, rs(90000));
      expect(find.text('Reversed'), findsNWidgets(6));
      // Attempt 4: the menu stays for "Cancel onboarded loan"; only the
      // opening-balance action is gone.
      await tester.tap(find.byKey(k('contract_menu')));
      await tester.pumpAndSettle();
      expect(find.text('Reverse opening balance'), findsNothing);
      expect(find.text('Cancel onboarded loan'), findsOneWidget);
    });
  });
}
