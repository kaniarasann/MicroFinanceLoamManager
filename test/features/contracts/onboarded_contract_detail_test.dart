import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/contracts/application/contract_providers.dart';
import 'package:nordic_ledger/features/contracts/data/contract_repository.dart';
import 'package:uuid/uuid.dart';

import 'contract_test_support.dart';
import 'contract_widget_harness.dart';

// Today: Tue 7 Nov 2023 (fixtureClock).

/// An onboarded weekly loan (₹1,00,000, ₹10,000 on Tuesdays from 15 Aug
/// 2023, disbursed 8 Aug, previous ref "Book 3 / 117") with a ₹55,000
/// opening total spread over 6 payments. [dropLast] leaves the newest
/// payment out, as if its batch never synced.
LedgerSeed onboardedSeed({
  bool dropLast = false,
  ContractStatus status = ContractStatus.active,
}) {
  final terms = OnboardContractCommand(
    cid: kCid,
    borrower: anita(),
    sanctioned: rs(100000),
    upfrontMode: UpfrontMode.flat,
    upfrontInput: 500000,
    installmentAmount: rs(10000),
    frequency: Frequency.weekly,
    preferredWeekday: 2,
    firstDueDate: d(2023, 8, 15),
    disbursedOn: d(2023, 8, 8),
    cachedNextLoanNo: 3,
    actor: kActor,
    role: Role.owner,
    today: kToday,
    pastPayments: const <PastPaymentInput>[],
  );
  final spread = spreadOpeningTotal(
    schedule: generateSchedule(
      sanctioned: rs(100000),
      installmentAmount: rs(10000),
      frequency: Frequency.weekly,
      firstDueDate: d(2023, 8, 15),
      preferredWeekday: 2,
    ),
    total: rs(55000),
    mode: PaymentMode.cash,
    disbursedOn: d(2023, 8, 8),
    today: kToday,
  );
  final plan = planOnboarding(
    terms: terms,
    pastPayments: spread,
    today: kToday,
    previousRef: 'Book 3 / 117',
    contractId: 'onb',
    borrowerId: 'b1',
    borrowerName: 'Anita Sharma',
    borrowerPhoneE164: '+919845012890',
    now: DateTime.utc(2023, 11, 7),
    uuid: const Uuid(),
  );
  final pays = dropLast
      ? plan.payments.sublist(0, plan.payments.length - 1)
      : plan.payments;
  final c = plan.contract.copyWith(
    status: status,
    totalPaid: Money.sum(pays.map((LedgerTransaction t) => t.amount)),
  );
  return LedgerSeed()
    ..borrowers.add(anita())
    ..contracts.add(c)
    ..transactions.addAll(<LedgerTransaction>[
      ?plan.base.disbursement,
      ...pays,
    ]);
}

Future<List<Map<String, dynamic>>> txDocs(
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

void main() {
  for (final width in <double>[400, 1024]) {
    final w = width.toInt();

    testWidgets('labels: Onboarded pill, Ref, "Opening balance" rows, no '
        'incomplete banner @$w', (WidgetTester tester) async {
      await pumpContracts(
        tester,
        initial: '/contracts/onb',
        width: width,
        seed: onboardedSeed(),
      );
      expect(find.byKey(k('onboarded_pill')), findsOneWidget);
      expect(find.text('Onboarded 7 Nov 2023'), findsOneWidget);
      expect(find.text('Ref Book 3 / 117'), findsOneWidget);
      expect(find.text('Opening balance'), findsNWidgets(6));
      expect(find.byKey(k('onboarding_incomplete_banner')), findsNothing);
      expect(find.byKey(k('contract_menu')), findsOneWidget);
    });

    testWidgets('incomplete onboarding: banner and the owner repair @$w', (
      WidgetTester tester,
    ) async {
      final db = await pumpContracts(
        tester,
        initial: '/contracts/onb',
        width: width,
        seed: onboardedSeed(dropLast: true),
      );
      expect(
        find.textContaining(
          'Onboarding incomplete: 5 of 6 payments synced · ₹5,000 missing',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Check that phone first.'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(k('add_missing_onboarding_payment')),
      );
      await tester.tap(find.byKey(k('add_missing_onboarding_payment')));
      await tester.pumpAndSettle();
      expect(find.byKey(k('add_onboarding_payment_sheet')), findsOneWidget);
      expect(
        find.text('₹5,000 missing · at most ₹5,000 can be added'),
        findsOneWidget,
      );
      // An opening-total loan: no switch, the repair is an opening row.
      expect(find.byKey(k('add_onboarding_opening')), findsNothing);
      // The gap date (row 6, 19 Sep), never today.
      expect(find.textContaining('Tue, 19 Sep 2023'), findsOneWidget);
      // No receipt share is offered for an onboarding payment.
      expect(find.textContaining('receipt'), findsNothing);
      await typeInto(tester, 'add_onboarding_amount', '5001');
      expect(
        find.text('At most ₹5,000 is missing from this onboarding.'),
        findsOneWidget,
      );
      await typeInto(tester, 'add_onboarding_amount', '5000');
      await tester.tap(find.byKey(k('add_onboarding_save')));
      await pumpFrames(tester);
      expect(find.byKey(k('onboarding_incomplete_banner')), findsNothing);
      expect(find.byKey(k('onboarding_overshoot_banner')), findsNothing);
      final pays = (await txDocs(
        tester,
        db,
      )).where((Map<String, dynamic> m) => m['type'] == 'payment');
      final added = pays.singleWhere(
        (Map<String, dynamic> m) => m['paidOn'] == '2023-09-19',
      );
      expect(added['origin'], 'onboarding');
      expect(added['openingBalance'], true);
      expect(find.text('Opening balance'), findsNWidgets(6));
    });

    testWidgets('a cached / pending snapshot shows "Waiting for sync…" @$w', (
      WidgetTester tester,
    ) async {
      await pumpContracts(
        tester,
        initial: '/contracts/onb',
        width: width,
        seed: onboardedSeed(dropLast: true),
        extraOverrides: <Override>[
          contractTransactionsConfirmedProvider.overrideWith(
            (Ref ref, String id) => Stream<bool>.value(false),
          ),
        ],
      );
      expect(find.text('Waiting for sync…'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
        find.byKey(k('add_missing_onboarding_payment')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a duplicate repair shows the overshoot banner @$w', (
      WidgetTester tester,
    ) async {
      final seed = onboardedSeed();
      final c = seed.contracts.single;
      seed.transactions.add(
        tx(
          c.id,
          rs(5000),
          d(2023, 9, 19),
          id: 'dup',
        ).copyWith(origin: TxOrigin.onboarding, openingBalance: true),
      );
      await pumpContracts(
        tester,
        initial: '/contracts/onb',
        width: width,
        seed: seed,
      );
      expect(
        find.text(
          'Onboarding payments exceed what was onboarded by ₹5,000. Review '
          'and reverse the duplicate.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(k('onboarding_incomplete_banner')), findsNothing);
      expect(find.byKey(k('add_missing_onboarding_payment')), findsNothing);
    });
  }

  testWidgets('a collector sees the banner but no repair or reversal', (
    WidgetTester tester,
  ) async {
    await pumpContracts(
      tester,
      initial: '/contracts/onb',
      role: Role.collector,
      seed: onboardedSeed(dropLast: true),
    );
    expect(find.byKey(k('onboarding_incomplete_banner')), findsOneWidget);
    expect(find.byKey(k('add_missing_onboarding_payment')), findsNothing);
    expect(find.byKey(k('contract_menu')), findsNothing);
    expect(find.text('Reverse'), findsNothing);
  });

  testWidgets('owner "Reverse opening balance" with a required reason', (
    WidgetTester tester,
  ) async {
    final db = await pumpContracts(
      tester,
      initial: '/contracts/onb',
      width: 1024,
      seed: onboardedSeed(),
    );
    await tester.tap(find.byKey(k('contract_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reverse opening balance'));
    await tester.pumpAndSettle();
    expect(find.byKey(k('reverse_opening_dialog')), findsOneWidget);
    expect(find.textContaining('6 opening-balance payments'), findsOneWidget);
    expect(find.textContaining('₹55,000'), findsWidgets);
    final confirm = find.byKey(k('reverse_opening_confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(
      find.byKey(k('reverse_opening_reason')),
      'Wrong total',
    );
    await tester.pump();
    await tester.tap(confirm);
    await pumpFrames(tester);
    final reversals = (await txDocs(
      tester,
      db,
    )).where((Map<String, dynamic> m) => m['type'] == 'reversal').toList();
    expect(reversals, hasLength(6));
    expect(
      reversals.any((Map<String, dynamic> m) => m['paidOn'] == '2023-11-07'),
      isFalse,
    );
    expect(find.text('Reversed'), findsNWidgets(6));
    // Nothing left to reverse: that action is gone; the menu keeps
    // "Cancel onboarded loan" (attempt 4).
    await tester.tap(find.byKey(k('contract_menu')));
    await tester.pumpAndSettle();
    expect(find.text('Reverse opening balance'), findsNothing);
    expect(find.text('Cancel onboarded loan'), findsOneWidget);
  });

  for (final status in <ContractStatus>[
    ContractStatus.rolledOver,
    ContractStatus.cancelled,
  ]) {
    testWidgets('${status.name}: no Reverse / Reverse opening balance (L2)', (
      WidgetTester tester,
    ) async {
      await pumpContracts(
        tester,
        initial: '/contracts/onb',
        seed: onboardedSeed(status: status),
      );
      expect(find.text('Opening balance'), findsNWidgets(6));
      expect(find.text('Reverse'), findsNothing);
      if (status == ContractStatus.rolledOver) {
        expect(find.byKey(k('contract_menu')), findsNothing);
      } else {
        // Attempt 5 (F2): a cancelled loan whose onboarding payments are
        // not reversed offers only "Finish cancelling".
        await tester.tap(find.byKey(k('contract_menu')));
        await tester.pumpAndSettle();
        expect(find.text('Reverse opening balance'), findsNothing);
        expect(find.text('Finish cancelling'), findsWidgets);
      }
    });
  }

  group('attempt 4: sync list and Cancel onboarded loan', () {
    Future<void> addQueue(
      WidgetTester tester,
      FakeFirebaseFirestore db, {
      String status = 'pending',
    }) => tester.runAsync(
      () =>
          db.doc('companies/$kCid/onboardingQueues/onb').set(<String, Object?>{
            'contractId': 'onb',
            'status': status,
            'entries': <Map<String, Object?>>[
              <String, Object?>{
                'i': 'queued-1',
                'd': '2023-09-19',
                'a': 500000,
                'm': 'cash',
                'o': true,
              },
            ],
            'count': 1,
            'totalPaise': 500000,
            'createdBy': kOwnerUid,
          }),
    );

    for (final width in <double>[400, 1024]) {
      testWidgets('a pending sync list shows "Finishing onboarding sync…", '
          'no incomplete banner and no repair @${width.toInt()}', (
        WidgetTester tester,
      ) async {
        final db = await pumpContracts(
          tester,
          initial: '/contracts/onb',
          width: width,
          seed: onboardedSeed(dropLast: true),
        );
        await addQueue(tester, db);
        await pumpFrames(tester);
        expect(
          find.textContaining('Finishing onboarding sync… 5 of 6 payments'),
          findsOneWidget,
        );
        expect(find.byKey(k('onboarding_incomplete_banner')), findsNothing);
        expect(find.byKey(k('add_missing_onboarding_payment')), findsNothing);
      });
    }

    testWidgets('a completed sync list falls back to the incomplete banner '
        'and the repair', (WidgetTester tester) async {
      final db = await pumpContracts(
        tester,
        initial: '/contracts/onb',
        seed: onboardedSeed(dropLast: true),
      );
      await addQueue(tester, db, status: 'complete');
      await pumpFrames(tester);
      expect(find.byKey(k('onboarding_finishing_banner')), findsNothing);
      expect(find.byKey(k('onboarding_incomplete_banner')), findsOneWidget);
    });

    testWidgets('a collector sees "Finishing…" too, and no Cancel', (
      WidgetTester tester,
    ) async {
      final db = await pumpContracts(
        tester,
        initial: '/contracts/onb',
        role: Role.collector,
        seed: onboardedSeed(dropLast: true),
      );
      await addQueue(tester, db);
      await pumpFrames(tester);
      expect(find.byKey(k('onboarding_finishing_banner')), findsOneWidget);
      expect(find.byKey(k('contract_menu')), findsNothing);
    });

    testWidgets('owner "Cancel onboarded loan": reason required, every '
        'onboarding payment reversed on its date, status Cancelled', (
      WidgetTester tester,
    ) async {
      final db = await pumpContracts(
        tester,
        initial: '/contracts/onb',
        width: 1024,
        seed: onboardedSeed(),
      );
      await tester.tap(find.byKey(k('contract_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel onboarded loan'));
      await tester.pumpAndSettle();
      expect(find.byKey(k('cancel_onboarded_dialog')), findsOneWidget);
      expect(
        find.textContaining('6 onboarding payments totalling ₹55,000'),
        findsOneWidget,
      );
      final confirm = find.byKey(k('cancel_onboarded_confirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(
        find.byKey(k('cancel_onboarded_reason')),
        'Onboarded by mistake',
      );
      await tester.pump();
      await tester.tap(confirm);
      // Cancel sends its batches in order, each after the previous ack;
      // let them all run, then rebuild.
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await pumpFrames(tester);
      }
      final txs = await txDocs(tester, db);
      final revs = txs.where(
        (Map<String, dynamic> m) => m['type'] == 'reversal',
      );
      expect(revs, hasLength(6));
      expect(
        revs.any((Map<String, dynamic> m) => m['paidOn'] == '2023-11-07'),
        isFalse,
      );
      late Map<String, dynamic> craw;
      await tester.runAsync(() async {
        craw = (await db.doc('companies/$kCid/contracts/onb').get()).data()!;
      });
      expect(craw['status'], 'cancelled');
      expect(craw['totalPaidPaise'], 0);
      // fake_cloud_firestore does not re-emit a typed contract doc listener
      // for untyped batch updates, so the stored status is asserted here;
      // the status pill itself is covered by contract_header_card.
      await pumpFrames(tester);
      expect(find.text('Reverse'), findsNothing);
    });

    testWidgets('Cancel is blocked while live payments remain', (
      WidgetTester tester,
    ) async {
      final seed = onboardedSeed();
      seed.transactions.add(
        tx(seed.contracts.single.id, rs(1000), d(2023, 11, 7), id: 'live-1'),
      );
      await pumpContracts(
        tester,
        initial: '/contracts/onb',
        width: 1024,
        seed: seed,
      );
      await tester.tap(find.byKey(k('contract_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel onboarded loan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Reverse the payments recorded after onboarding first.'),
        findsOneWidget,
      );
      expect(find.byKey(k('cancel_onboarded_confirm')), findsNothing);
    });

    testWidgets('F4: a pending queue on a closed loan shows the incomplete '
        'fallback, not "Finishing…"', (WidgetTester tester) async {
      final db = await pumpContracts(
        tester,
        initial: '/contracts/onb',
        seed: onboardedSeed(dropLast: true, status: ContractStatus.closed),
      );
      await addQueue(tester, db);
      await pumpFrames(tester);
      expect(find.byKey(k('onboarding_finishing_banner')), findsNothing);
      expect(find.byKey(k('onboarding_incomplete_banner')), findsOneWidget);
      // The repair is only for active loans.
      expect(find.byKey(k('add_missing_onboarding_payment')), findsNothing);
    });

    for (final width in <double>[400, 1024]) {
      testWidgets('F2: a cancelled loan with unreversed onboarding payments '
          'offers "Finish cancelling" @${width.toInt()}', (
        WidgetTester tester,
      ) async {
        final db = await pumpContracts(
          tester,
          initial: '/contracts/onb',
          width: width,
          seed: onboardedSeed(status: ContractStatus.cancelled),
        );
        expect(
          find.text(
            'Cancel not finished: 6 onboarding payments are not reversed yet.',
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(find.byKey(k('finish_cancelling')));
        await tester.tap(find.byKey(k('finish_cancelling')));
        await tester.pumpAndSettle();
        expect(find.text('Finish cancelling?'), findsOneWidget);
        expect(
          find.textContaining('The loan stays Cancelled.'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(k('cancel_onboarded_reason')),
          'Finish the cancel',
        );
        await tester.pump();
        await tester.tap(find.byKey(k('cancel_onboarded_confirm')));
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await pumpFrames(tester);
        }
        final revs = (await txDocs(
          tester,
          db,
        )).where((Map<String, dynamic> m) => m['type'] == 'reversal');
        expect(revs, hasLength(6));
        expect(find.byKey(k('cancel_unfinished_banner')), findsNothing);
      });
    }

    testWidgets('F2: a collector sees the unfinished banner, no button', (
      WidgetTester tester,
    ) async {
      await pumpContracts(
        tester,
        initial: '/contracts/onb',
        role: Role.collector,
        seed: onboardedSeed(status: ContractStatus.cancelled),
      );
      expect(find.byKey(k('cancel_unfinished_banner')), findsOneWidget);
      expect(find.byKey(k('finish_cancelling')), findsNothing);
      expect(find.byKey(k('contract_menu')), findsNothing);
    });
  });
  group('attempt 6: a cancelled loan renders neutral', () {
    /// The Stitch-style onboarded loan, cancelled; [netted] adds a
    /// reversal for every onboarding payment (a finished cancel).
    LedgerSeed cancelledSeed({bool netted = true}) {
      final seed = onboardedSeed(status: ContractStatus.cancelled);
      if (netted) {
        final c = seed.contracts.single;
        final pays = seed.transactions
            .where((LedgerTransaction t) => t.type == TxType.payment)
            .toList();
        for (final p in pays) {
          seed.transactions.add(
            p.copyWith(
              id: 'rev-${p.id}',
              type: TxType.reversal,
              reversesTxId: p.id,
              openingBalance: false,
              note: 'Onboarded by mistake',
              contractActive: false,
            ),
          );
        }
        seed.contracts
          ..clear()
          ..add(c.copyWith(totalPaid: Money.zero));
      }
      return seed;
    }

    void expectNeutral(WidgetTester tester) {
      expect(find.byKey(k('overdue_banner')), findsNothing);
      expect(find.byKey(k('excess_banner')), findsNothing);
      expect(find.byKey(k('extension_note')), findsNothing);
      expect(find.byKey(k('cancelled_note')), findsOneWidget);
      expect(find.byKey(k('overdue_rail')), findsNothing);
      expect(find.textContaining('Overdue by'), findsNothing);
      expect(find.textContaining('· Added'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.textContaining('Collect '), findsNothing);
      expect(find.text('Reschedule'), findsNothing);
      expect(find.byKey(k('record_repayment')), findsNothing);
      expect(find.byKey(k('contract_footer_label')), findsNothing);
      expect(find.text('Not collected · loan cancelled'), findsWidgets);
      expect(find.byKey(k('cancelled_row_1')), findsOneWidget);
    }

    for (final width in <double>[400, 1024]) {
      testWidgets('finished cancel: no overdue banner, rows or actions '
          '@${width.toInt()}', (WidgetTester tester) async {
        await pumpContracts(
          tester,
          initial: '/contracts/onb',
          width: width,
          seed: cancelledSeed(),
        );
        expect(find.byKey(k('contract_status')), findsOneWidget);
        expect(find.text('Cancelled'), findsWidgets);
        expectNeutral(tester);
        expect(find.byKey(k('cancel_unfinished_banner')), findsNothing);
      });

      testWidgets('unfinished cancel: rows stay neutral (no Paid ticks) and '
          'only the "Cancel not finished" banner shows @${width.toInt()}', (
        WidgetTester tester,
      ) async {
        await pumpContracts(
          tester,
          initial: '/contracts/onb',
          width: width,
          seed: cancelledSeed(netted: false),
        );
        expectNeutral(tester);
        expect(find.byKey(k('cancel_unfinished_banner')), findsOneWidget);
      });
    }
  });
}
