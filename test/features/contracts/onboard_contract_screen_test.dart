import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/firebase/firebase_providers.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/core/time/clock_provider.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/contracts/application/contract_providers.dart';
import 'package:nordic_ledger/features/contracts/data/contract_repository.dart';

import 'contract_test_support.dart';
import 'contract_widget_harness.dart';

// Today: Tue 7 Nov 2023 (fixtureClock).
const String _onboard = '/contracts/onboard?borrowerId=b1';

LedgerSeed _oneBorrower() => LedgerSeed()..borrowers.add(anita());

/// Reports every onboarding as queued (as when the device is offline: the
/// batches are in the local cache, waiting for the server).
final class _OfflineRepo extends ContractRepository {
  _OfflineRepo({required super.firestore, required super.clock});

  @override
  Future<LedgerWriteResult> onboardContract(OnboardContractCommand cmd) async {
    final r = await super.onboardContract(cmd);
    return LedgerWriteResult(r.id, WriteOutcome.queued);
  }
}

final List<Override> _offline = <Override>[
  contractRepositoryProvider.overrideWith(
    (Ref ref) => _OfflineRepo(
      firestore: ref.watch(firestoreProvider),
      clock: ref.watch(clockProvider),
    ),
  ),
];

/// Opens the date picker of [fieldKey] and enters [d] in its input mode.
Future<void> pickDate(WidgetTester tester, String fieldKey, CivilDate d) async {
  await tester.ensureVisible(find.byKey(k(fieldKey)));
  await tester.tap(find.byKey(k(fieldKey)));
  await tester.pumpAndSettle();
  await enterPickerDate(tester, d);
}

/// In an open Material date picker: switch to text input, type [d] and OK.
Future<void> enterPickerDate(WidgetTester tester, CivilDate d) async {
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  await tester.enterText(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.byType(TextField),
    ),
    '$mm/$dd/${d.year}',
  );
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(k(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(k(key)));
  await tester.pumpAndSettle();
}

/// The Stitch-style weekly loan: ₹1,00,000, ₹5,000 upfront, ₹10,000 on
/// Tuesdays, disbursed Tue 8 Aug 2023, so the 10 rows run 15 Aug … 17 Oct,
/// all before today.
Future<void> enterWeeklyTerms(WidgetTester tester) async {
  await typeInto(tester, 'sanctioned_field', '100000');
  await typeInto(tester, 'upfront_flat_field', '5000');
  await typeInto(tester, 'installment_field', '10000');
  await pickDate(tester, 'disbursed_on_field', d(2023, 8, 8));
}

/// Daily ₹10,000 at ₹1,000, disbursed Fri 20 Oct 2023: rows 21 … 30 Oct.
Future<void> enterDailyTerms(WidgetTester tester) async {
  await typeInto(tester, 'sanctioned_field', '10000');
  await typeInto(tester, 'installment_field', '1000');
  await tester.ensureVisible(find.text('Daily'));
  await tester.tap(find.text('Daily'));
  await tester.pumpAndSettle();
  await pickDate(tester, 'disbursed_on_field', d(2023, 10, 20));
}

Future<List<Map<String, dynamic>>> docs(
  WidgetTester tester,
  FakeFirebaseFirestore db,
  String col,
) async {
  late List<Map<String, dynamic>> out;
  await tester.runAsync(() async {
    final snap = await db.collection('companies/$kCid/$col').get();
    out = <Map<String, dynamic>>[for (final x in snap.docs) x.data()];
  });
  return out;
}

void main() {
  for (final width in <double>[400, 1024]) {
    final w = width.toInt();

    testWidgets('owner, opening total: helper, preview and save @$w', (
      WidgetTester tester,
    ) async {
      final db = await pumpContracts(
        tester,
        initial: _onboard,
        width: width,
        seed: _oneBorrower(),
      );
      expect(find.text('Onboard existing loan'), findsOneWidget);
      expect(find.text('Anita Sharma'), findsOneWidget);
      expect(
        find.byKey(k(width < 840 ? 'onboard_form' : 'onboard_preview_pane')),
        findsOneWidget,
      );
      expect(find.textContaining('Unknown? Enter ₹0'), findsWidgets);
      await enterWeeklyTerms(tester);
      expect(find.textContaining('Tue, 15 Aug 2023'), findsWidgets);

      await typeInto(tester, 'opening_total_field', '55000');
      await tester.pumpAndSettle();
      expect(
        find.text('Spread across 6 installments due before today.'),
        findsOneWidget,
      );
      // "As of today": rows 1–5 paid, row 6 ₹5,000 short, 6–10 overdue.
      expect(find.byKey(k('onboarding_preview')), findsOneWidget);
      expect(find.text('₹55,000'), findsWidgets);
      expect(find.text('₹45,000'), findsWidgets);
      expect(
        find.text('5 installments · highest 49 days late'),
        findsOneWidget,
      );
      expect(find.text('Outstanding ₹45,000 · 5 overdue'), findsOneWidget);
      // The timeline is lazily built in a bounded list: scroll through it.
      final timeline = find.descendant(
        of: find.byKey(k('projected_schedule')),
        matching: find.byType(Scrollable),
      );
      expect(find.text('Paid'), findsWidgets);
      await tester.scrollUntilVisible(
        find.textContaining('Partially paid · 49d late'),
        80,
        scrollable: timeline,
      );
      await tester.scrollUntilVisible(
        find.textContaining('Overdue · 21 days late'),
        80,
        scrollable: timeline,
      );
      await tester.scrollUntilVisible(
        find.text('Added'),
        80,
        scrollable: timeline,
      );

      await tester.ensureVisible(find.byKey(k('onboard_submit')));
      await tester.tap(find.byKey(k('onboard_submit')));
      await pumpFrames(tester);
      await pumpFrames(tester);
      // The contract detail shows exactly what the preview showed.
      expect(find.text('Loan schedule'), findsOneWidget);
      expect(find.text('Onboarded 7 Nov 2023'), findsOneWidget);
      expect(
        find.text('5 overdue installments · ₹45,000 · 49d late'),
        findsOneWidget,
      );
      expect(find.text('Opening balance'), findsNWidgets(6));
      expect(find.text('Payment'), findsNothing);

      final contracts = await docs(tester, db, 'contracts');
      expect(contracts.single['origin'], 'onboarded');
      expect(contracts.single['onboardedOn'], '2023-11-07');
      expect(contracts.single['onboardedPaymentCount'], 6);
      expect(contracts.single['onboardedTotalPaise'], 5500000);
      expect(contracts.single['disbursedOn'], '2023-08-08');
      final pays = (await docs(
        tester,
        db,
        'transactions',
      )).where((Map<String, dynamic> m) => m['type'] == 'payment');
      expect(pays, hasLength(6));
      expect(
        pays.every((Map<String, dynamic> m) => m['openingBalance'] == true),
        isTrue,
      );
      expect(
        pays.any((Map<String, dynamic> m) => m['paidOn'] == '2023-11-07'),
        isFalse,
      );
    });

    testWidgets('owner, itemised: fill from schedule, delete, add, offline '
        'save @$w', (WidgetTester tester) async {
      final db = await pumpContracts(
        tester,
        initial: _onboard,
        width: width,
        seed: _oneBorrower(),
        extraOverrides: _offline,
      );
      await enterDailyTerms(tester);
      await tapKey(tester, 'past_payments_mode');
      await tester.tap(find.text('Itemised payments'));
      await tester.pumpAndSettle();
      expect(find.byKey(k('fill_from_schedule')), findsOneWidget);

      await tapKey(tester, 'fill_from_schedule');
      await enterPickerDate(tester, d(2023, 10, 25));
      expect(find.text('5 payments'), findsOneWidget);
      expect(find.byKey(k('past_payment_4')), findsOneWidget);

      await tapKey(tester, 'delete_past_payment_4');
      expect(find.text('4 payments'), findsOneWidget);

      // Add one through the row editor (bottom sheet / 560 dialog).
      await tapKey(tester, 'add_past_payment');
      expect(find.byKey(k('past_payment_sheet')), findsOneWidget);
      if (width >= 600) {
        expect(find.byType(Dialog), findsOneWidget);
      } else {
        expect(find.byType(BottomSheet), findsOneWidget);
      }
      await typeInto(tester, 'past_payment_amount', '1500');
      await tester.tap(find.byKey(k('past_payment_save')));
      await tester.pumpAndSettle();
      expect(find.text('5 payments'), findsOneWidget);
      expect(find.text('₹5,500'), findsWidgets);
      expect(find.text('Outstanding ₹4,500 · 5 overdue'), findsOneWidget);

      await tester.ensureVisible(find.byKey(k('onboard_submit')));
      await tester.tap(find.byKey(k('onboard_submit')));
      await pumpFrames(tester);
      expect(find.text('Saved · will sync'), findsOneWidget);
      await pumpFrames(tester);
      expect(find.text('Loan schedule'), findsOneWidget);
      expect(find.text('Recorded at onboarding'), findsNWidgets(5));

      final pays = (await docs(
        tester,
        db,
        'transactions',
      )).where((Map<String, dynamic> m) => m['type'] == 'payment').toList();
      expect(pays, hasLength(5));
      expect(
        pays.every((Map<String, dynamic> m) => m['openingBalance'] == false),
        isTrue,
      );
      expect(
        pays.map((Map<String, dynamic> m) => m['paidOn']).toSet(),
        <String>{
          '2023-10-21',
          '2023-10-22',
          '2023-10-23',
          '2023-10-24',
          '2023-11-07',
        },
      );
    });

    testWidgets('validation errors inline per field and per row @$w', (
      WidgetTester tester,
    ) async {
      await pumpContracts(tester, initial: '/contracts/onboard', width: width);
      await tapKey(tester, 'onboard_submit');
      expect(find.text('Choose a borrower.'), findsOneWidget);
      expect(find.byKey(k('onboard_fix_fields')), findsOneWidget);
      expect(find.byKey(k('onboarding_preview_empty')), findsOneWidget);

      await enterWeeklyTerms(tester);
      await typeInto(tester, 'opening_total_field', '100000');
      await tester.pumpAndSettle();
      expect(find.textContaining('already fully repaid'), findsOneWidget);

      // A row dated 8 Aug turns invalid once "Disbursed on" moves later.
      await tapKey(tester, 'past_payments_mode');
      await tester.tap(find.text('Itemised payments'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'add_past_payment');
      await pickDate(tester, 'past_payment_date', d(2023, 8, 8));
      await typeInto(tester, 'past_payment_amount', '2000');
      await tester.tap(find.byKey(k('past_payment_save')));
      await tester.pumpAndSettle();
      expect(find.byKey(k('past_payment_error_0')), findsNothing);
      await pickDate(tester, 'disbursed_on_field', d(2023, 8, 10));
      expect(
        find.text('A payment cannot be dated before the disbursement date.'),
        findsOneWidget,
      );
      expect(find.byKey(k('past_payment_error_0')), findsOneWidget);
    });
  }

  testWidgets('switching modes sends only the selected one (O2)', (
    WidgetTester tester,
  ) async {
    final db = await pumpContracts(
      tester,
      initial: _onboard,
      seed: _oneBorrower(),
    );
    await enterWeeklyTerms(tester);
    await typeInto(tester, 'opening_total_field', '55000');
    await tapKey(tester, 'past_payments_mode');
    await tester.tap(find.text('Itemised payments'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'add_past_payment');
    await typeInto(tester, 'past_payment_amount', '1000');
    await tester.tap(find.byKey(k('past_payment_save')));
    await tester.pumpAndSettle();
    expect(find.text('Outstanding ₹99,000 · 10 overdue'), findsOneWidget);

    await tester.tap(find.text('Opening total'));
    await tester.pumpAndSettle();
    // Both inputs are kept; the opening total is the one shown and saved.
    expect(find.text('Outstanding ₹45,000 · 5 overdue'), findsOneWidget);
    await tester.ensureVisible(find.byKey(k('onboard_submit')));
    await tester.tap(find.byKey(k('onboard_submit')));
    await pumpFrames(tester);
    await pumpFrames(tester);
    final pays = (await docs(
      tester,
      db,
      'transactions',
    )).where((Map<String, dynamic> m) => m['type'] == 'payment').toList();
    expect(pays, hasLength(6));
    expect(
      pays.every((Map<String, dynamic> m) => m['openingBalance'] == true),
      isTrue,
    );
  });

  testWidgets('survives text scale 1.3× with a full preview', (
    WidgetTester tester,
  ) async {
    await pumpContracts(
      tester,
      initial: _onboard,
      seed: _oneBorrower(),
      textScale: 1.3,
    );
    await enterWeeklyTerms(tester);
    await typeInto(tester, 'opening_total_field', '55000');
    await tester.pumpAndSettle();
    expect(find.byKey(k('onboarding_preview')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a collector is told and sent away', (WidgetTester tester) async {
    await pumpContracts(tester, initial: _onboard, role: Role.collector);
    await tester.pumpAndSettle();
    expect(find.text('Only owners can onboard loans.'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Onboard existing loan'), findsNothing);
  });

  testWidgets('"New loan · Existing loan" toggles between the screens', (
    WidgetTester tester,
  ) async {
    await pumpContracts(
      tester,
      initial: '/contracts/new?borrowerId=b1',
      seed: _oneBorrower(),
    );
    expect(find.text('New loan contract'), findsOneWidget);
    await tester.tap(find.text('Existing loan'));
    await tester.pumpAndSettle();
    expect(find.text('Onboard existing loan'), findsOneWidget);
    expect(find.text('Anita Sharma'), findsOneWidget);
    await tester.tap(find.text('New loan'));
    await tester.pumpAndSettle();
    expect(find.text('New loan contract'), findsOneWidget);
  });

  testWidgets('L3: "Fill from schedule" defaults to the last due date before '
      'today, and today can still be picked', (WidgetTester tester) async {
    await pumpContracts(tester, initial: _onboard, seed: _oneBorrower());
    await typeInto(tester, 'sanctioned_field', '100000');
    await typeInto(tester, 'installment_field', '10000');
    // Disbursed Tue 24 Oct: rows 31 Oct and 7 Nov (today), …
    await pickDate(tester, 'disbursed_on_field', d(2023, 10, 24));
    await tapKey(tester, 'past_payments_mode');
    await tester.tap(find.text('Itemised payments'));
    await tester.pumpAndSettle();

    await tapKey(tester, 'fill_from_schedule');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('1 payment'), findsOneWidget);
    expect(find.textContaining('31 Oct 2023'), findsWidgets);

    await tapKey(tester, 'fill_from_schedule');
    await enterPickerDate(tester, d(2023, 11, 7));
    await tester.tap(find.byKey(k('fill_replace_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('2 payments'), findsOneWidget);
  });
}
