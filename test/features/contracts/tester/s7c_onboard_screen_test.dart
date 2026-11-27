import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_ledger/core/firebase/firebase_providers.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/core/time/clock_provider.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/borrowers/presentation/screens/borrower_profile_screen.dart';
import 'package:nordic_ledger/features/contracts/application/contract_draft.dart';
import 'package:nordic_ledger/features/contracts/application/contract_providers.dart';
import 'package:nordic_ledger/features/contracts/application/onboarding_draft.dart';
import 'package:nordic_ledger/features/contracts/data/contract_repository.dart';
import 'package:nordic_ledger/features/contracts/presentation/screens/contract_detail_screen.dart';
import 'package:nordic_ledger/features/contracts/presentation/screens/create_contract_screen.dart';
import 'package:nordic_ledger/features/contracts/presentation/screens/onboard_contract_screen.dart';
import 'package:nordic_ledger/features/dashboard/presentation/screens/dashboard_screen.dart';

import '../contract_test_support.dart';
import '../contract_widget_harness.dart' show k, pumpFrames, typeInto;

// Tester, Sprint 7c (Task 21 UI + L1 + O2). Today: Tue 7 Nov 2023
// (fixtureClock). The scenario loan: ₹1,00,000 weekly at ₹10,000,
// disbursed Tue 29 Aug 2023 (10 weeks ago), so rows run 5 Sep … 7 Nov and
// row 10 is due TODAY.

final CivilDate _disbursed = d(2023, 8, 29);

/// Reports every onboarding as queued, as when the device is offline.
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

/// Pumps /home (the real dashboard), /borrowers/:id, /contracts/new,
/// /contracts/onboard and /contracts/:id over one fake Firestore.
Future<({FakeFirebaseFirestore db, GoRouter router})> _pump(
  WidgetTester tester, {
  required String initial,
  double width = 400,
  double height = 4000,
  Role role = Role.owner,
  double textScale = 1,
  List<Override> extra = const <Override>[],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  final db = FakeFirebaseFirestore();
  await tester.runAsync(() async {
    await seedCompany(db);
    await (LedgerSeed()..borrowers.add(anita())).writeTo(db);
  });
  final router = GoRouter(
    initialLocation: initial,
    routes: <RouteBase>[
      GoRoute(
        path: '/home',
        builder: (BuildContext c, GoRouterState s) =>
            const Scaffold(body: DashboardScreen()),
      ),
      GoRoute(
        path: '/borrowers/:id',
        builder: (BuildContext c, GoRouterState s) =>
            BorrowerProfileScreen(borrowerId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/contracts/new',
        builder: (BuildContext c, GoRouterState s) => CreateContractScreen(
          borrowerId: s.uri.queryParameters['borrowerId'],
        ),
      ),
      GoRoute(
        path: '/contracts/onboard',
        builder: (BuildContext c, GoRouterState s) => OnboardContractScreen(
          borrowerId: s.uri.queryParameters['borrowerId'],
        ),
      ),
      GoRoute(
        path: '/contracts/:id',
        builder: (BuildContext c, GoRouterState s) =>
            ContractDetailScreen(contractId: s.pathParameters['id']!),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ...contractOverrides(db, role: role),
        ...extra,
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: (BuildContext c, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            c,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await pumpFrames(tester);
  return (db: db, router: router);
}

const String _onboard = '/contracts/onboard?borrowerId=b1';

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(k(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(k(key)));
  await tester.pumpAndSettle();
}

String _mdy(CivilDate d) =>
    '${d.month.toString().padLeft(2, '0')}/'
    '${d.day.toString().padLeft(2, '0')}/${d.year}';

/// In an open date picker: switch to text input and type [d] (no OK).
Future<void> _typePickerDate(WidgetTester tester, CivilDate d) async {
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.byType(TextField),
    ),
    _mdy(d),
  );
}

Future<void> _enterPickerDate(WidgetTester tester, CivilDate d) async {
  await _typePickerDate(tester, d);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _pickDate(WidgetTester tester, String key, CivilDate d) async {
  await _tap(tester, key);
  await _enterPickerDate(tester, d);
}

Future<void> _weeklyTerms(
  WidgetTester tester, {
  String upfront = '5000',
}) async {
  await typeInto(tester, 'sanctioned_field', '100000');
  await typeInto(tester, 'upfront_flat_field', upfront);
  await typeInto(tester, 'installment_field', '10000');
  await _pickDate(tester, 'disbursed_on_field', _disbursed);
}

Future<void> _itemisedMode(WidgetTester tester) async {
  await _tap(tester, 'past_payments_mode');
  await tester.tap(find.text('Itemised payments'));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(k('onboard_submit')));
  await tester.tap(find.byKey(k('onboard_submit')));
  await pumpFrames(tester);
  await pumpFrames(tester);
}

Future<List<Map<String, dynamic>>> _docs(
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

Future<List<Map<String, dynamic>>> _payments(
  WidgetTester tester,
  FakeFirebaseFirestore db,
) async => (await _docs(
  tester,
  db,
  'transactions',
)).where((Map<String, dynamic> m) => m['type'] == 'payment').toList();

Finder _inTimeline(Finder f) =>
    find.descendant(of: find.byKey(k('projected_schedule')), matching: f);

Future<void> _scrollTimelineTo(WidgetTester tester, Finder f) =>
    tester.scrollUntilVisible(
      f,
      60,
      scrollable: find
          .descendant(
            of: find.byKey(k('projected_schedule')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

void main() {
  group('owner, opening total (10-week weekly loan, ₹55,000)', () {
    testWidgets('helper, L1 today open, preview rows, save → detail, '
        'labels, no receipt share, dashboard Received today ₹0', (
      WidgetTester tester,
    ) async {
      final (:db, :router) = await _pump(tester, initial: _onboard);
      await _weeklyTerms(tester);
      await typeInto(tester, 'previous_ref_field', 'Book 3 / 117');
      await typeInto(tester, 'opening_total_field', '55000');
      await tester.pumpAndSettle();
      // Rows 1–9 are before today; ₹55,000 covers 1–5 and part of 6.
      expect(
        find.text(
          "Spread across 6 installments due before today. Today's "
          'installment stays open.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('4 installments · highest 28 days late'),
        findsOneWidget,
      );
      expect(find.text('Outstanding ₹45,000 · 4 overdue'), findsOneWidget);
      expect(_inTimeline(find.text('Paid')), findsWidgets);
      await _scrollTimelineTo(
        tester,
        _inTimeline(find.textContaining('Partially paid · 28d late')),
      );
      for (final late in <int>[21, 14, 7]) {
        await _scrollTimelineTo(
          tester,
          _inTimeline(find.textContaining('Overdue · $late days late')),
        );
      }
      await _scrollTimelineTo(tester, _inTimeline(find.text('Due today')));
      await _scrollTimelineTo(tester, _inTimeline(find.text('Added')));

      await _submit(tester);
      expect(find.text('Loan schedule'), findsOneWidget);
      expect(find.text('Onboarded 7 Nov 2023'), findsOneWidget);
      expect(find.text('Ref Book 3 / 117'), findsOneWidget);
      // Same figures as the preview.
      expect(
        find.text('4 overdue installments · ₹35,000 · 28d late'),
        findsOneWidget,
      );
      expect(find.text('Opening balance'), findsNWidgets(6));
      expect(find.textContaining('Send receipt'), findsNothing);

      final pays = await _payments(tester, db);
      expect(pays, hasLength(6));
      expect(
        pays.map((Map<String, dynamic> m) => m['paidOn']).toSet(),
        <String>{
          '2023-09-05',
          '2023-09-12',
          '2023-09-19',
          '2023-09-26',
          '2023-10-03',
          '2023-10-10',
        },
      );
      expect(
        pays.every(
          (Map<String, dynamic> m) =>
              m['openingBalance'] == true &&
              m['origin'] == 'onboarding' &&
              m['recordedBy'] == kOwnerUid &&
              m['recordedByName'] == 'Ravi' &&
              m['clientRecordedAt'] != null,
        ),
        isTrue,
      );
      final c = (await _docs(tester, db, 'contracts')).single;
      expect(c['previousRef'], 'Book 3 / 117');
      expect(c['totalPaidPaise'], 5500000);

      router.go('/home');
      await pumpFrames(tester);
      await pumpFrames(tester);
      expect(find.byKey(k('today_due_card')), findsOneWidget);
      // Nothing received today; today's ₹10,000 row stays due (L1).
      expect(
        tester.widget<Text>(find.byKey(k('today_received'))).data,
        '₹0 / ₹10,000 (0%)',
      );
    });

    testWidgets('L1: a total reaching today dates the advance on the last '
        'due date before today, never today', (WidgetTester tester) async {
      final (:db, :router) = await _pump(tester, initial: _onboard);
      await _weeklyTerms(tester);
      await typeInto(tester, 'opening_total_field', '95000');
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Spread across 9 installments due before today · ₹5,000 '
          "advance. Today's installment stays open.",
        ),
        findsOneWidget,
      );
      expect(find.text('Outstanding ₹5,000 · 0 overdue'), findsOneWidget);
      await _submit(tester);
      final pays = await _payments(tester, db);
      expect(pays, hasLength(10));
      expect(
        pays.where((Map<String, dynamic> m) => m['paidOn'] == '2023-11-07'),
        isEmpty,
      );
      expect(
        pays.where((Map<String, dynamic> m) => m['paidOn'] == '2023-10-31'),
        hasLength(2),
      );
      router.go('/home');
      await pumpFrames(tester);
      await pumpFrames(tester);
      // Received today stays ₹0 (the ₹5,000 advance is dated 31 Oct).
      expect(
        tester.widget<Text>(find.byKey(k('today_received'))).data,
        startsWith('₹0 /'),
      );
    });

    testWidgets('offline save confirms "Saved · will sync" and opens the '
        'detail', (WidgetTester tester) async {
      await _pump(tester, initial: _onboard, extra: _offline);
      await _weeklyTerms(tester);
      await typeInto(tester, 'opening_total_field', '55000');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(k('onboard_submit')));
      await tester.tap(find.byKey(k('onboard_submit')));
      await pumpFrames(tester);
      expect(find.text('Saved · will sync'), findsOneWidget);
      await pumpFrames(tester);
      expect(find.text('Onboarded 7 Nov 2023'), findsOneWidget);
    });
  });

  group('owner, itemised', () {
    testWidgets('fill from schedule, edit, delete; switching from an opening '
        'total saves only the itemised rows (O2)', (WidgetTester tester) async {
      final (:db, router: _) = await _pump(tester, initial: _onboard);
      await _weeklyTerms(tester);
      await typeInto(tester, 'opening_total_field', '55000');
      await _itemisedMode(tester);
      expect(find.text('0 payments'), findsOneWidget);

      await _tap(tester, 'fill_from_schedule');
      await _enterPickerDate(tester, d(2023, 10, 31));
      expect(find.text('9 payments'), findsOneWidget);
      expect(find.text('₹90,000'), findsWidgets);

      // Edit the newest row (index 8, 31 Oct) to ₹7,000.
      await _tap(tester, 'past_payment_8');
      expect(find.text('Edit past payment'), findsOneWidget);
      await typeInto(tester, 'past_payment_amount', '7000');
      await tester.tap(find.byKey(k('past_payment_save')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(k('itemised_total')),
          matching: find.text('₹87,000'),
        ),
        findsOneWidget,
      );
      // Delete row 7 (24 Oct).
      await _tap(tester, 'delete_past_payment_7');
      expect(find.text('8 payments'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(k('itemised_total')),
          matching: find.text('₹77,000'),
        ),
        findsOneWidget,
      );

      await _submit(tester);
      expect(find.text('Recorded at onboarding'), findsNWidgets(8));
      final pays = await _payments(tester, db);
      expect(pays, hasLength(8));
      expect(
        pays.every((Map<String, dynamic> m) => m['openingBalance'] == false),
        isTrue,
      );
      expect(
        pays.map((Map<String, dynamic> m) => m['paidOn']),
        isNot(contains('2023-10-24')),
      );
      final c = (await _docs(tester, db, 'contracts')).single;
      expect(c['onboardedPaymentCount'], 8);
      expect(c['onboardedTotalPaise'], 7700000);
      expect(c['totalPaidPaise'], 7700000);
    });

    testWidgets('per-row inline error: a row before Disbursed on blocks save', (
      WidgetTester tester,
    ) async {
      final (:db, router: _) = await _pump(tester, initial: _onboard);
      await _weeklyTerms(tester);
      await _itemisedMode(tester);
      await _tap(tester, 'add_past_payment');
      await _pickDate(tester, 'past_payment_date', d(2023, 8, 30));
      await typeInto(tester, 'past_payment_amount', '2000');
      await tester.tap(find.byKey(k('past_payment_save')));
      await tester.pumpAndSettle();
      expect(find.byKey(k('past_payment_error_0')), findsNothing);
      await _pickDate(tester, 'disbursed_on_field', d(2023, 9, 1));
      expect(
        find.text('A payment cannot be dated before the disbursement date.'),
        findsOneWidget,
      );
      await _submit(tester);
      expect(find.byKey(k('onboard_fix_fields')), findsOneWidget);
      expect(await _docs(tester, db, 'contracts'), isEmpty);
    });

    test('row errors for a future date and a missing mode (the sheet cannot '
        'produce them, the draft still flags them per row)', () {
      final terms = ContractDraft(
        frequency: Frequency.weekly,
        firstDueDate: d(2023, 9, 5),
        disbursedOn: _disbursed,
        sanctioned: rs(100000),
        upfrontInput: 0,
        installmentAmount: rs(10000),
        weekday: 2,
      );
      final draft = OnboardingDraft(
        terms: terms,
        today: kToday,
        mode: PastPaymentsMode.itemised,
        rows: <PastPaymentInput>[
          PastPaymentInput(
            paidOn: d(2023, 9, 5),
            amount: rs(10000),
            mode: PaymentMode.cash,
          ),
          PastPaymentInput(
            paidOn: d(2023, 11, 8),
            amount: rs(10000),
            mode: PaymentMode.upi,
          ),
          PastPaymentInput(
            paidOn: d(2023, 9, 12),
            amount: rs(10000),
            mode: null,
          ),
        ],
      );
      expect(draft.rowError(0), isNull);
      expect(draft.rowError(1), 'A payment cannot be in the future.');
      expect(draft.rowError(2), 'Choose a payment mode.');
      expect(draft.plan, isNull);
      expect(draft.preview, isNull);
    });
  });

  group('field validation in the UI', () {
    testWidgets('Disbursed on: the picker spans exactly [today − 3y, today] '
        'and rejects an earlier date', (WidgetTester tester) async {
      await _pump(tester, initial: _onboard);
      await _tap(tester, 'disbursed_on_field');
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(
        picker.firstDate,
        DateTime(2023, 11, 7).subtract(const Duration(days: 1096)),
      );
      expect(picker.lastDate, DateTime(2023, 11, 7));
      await _typePickerDate(tester, d(2020, 11, 5));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Out of range.'), findsOneWidget);
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('First collection date: picker spans [disbursedOn, '
        'disbursedOn + 366] and rejects a date outside', (
      WidgetTester tester,
    ) async {
      await _pump(tester, initial: _onboard);
      await _weeklyTerms(tester);
      await _tap(tester, 'first_due_field');
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, DateTime(2023, 8, 29));
      expect(picker.lastDate, DateTime(2024, 8, 29));
      await _typePickerDate(tester, d(2023, 8, 28));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Out of range.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('previous ref is capped at 40 characters', (
      WidgetTester tester,
    ) async {
      final (:db, router: _) = await _pump(tester, initial: _onboard);
      await _weeklyTerms(tester);
      await typeInto(tester, 'previous_ref_field', 'R' * 45);
      final field = tester.widget<TextField>(
        find.byKey(k('previous_ref_field')),
      );
      expect(field.controller!.text, hasLength(40));
      await _submit(tester);
      final c = (await _docs(tester, db, 'contracts')).single;
      expect(c['previousRef'], 'R' * 40);
    });

    testWidgets('fully repaid is blocked and writes nothing', (
      WidgetTester tester,
    ) async {
      final (:db, router: _) = await _pump(tester, initial: _onboard);
      await _weeklyTerms(tester);
      await typeInto(tester, 'opening_total_field', '100000');
      await tester.pumpAndSettle();
      expect(find.textContaining('already fully repaid'), findsOneWidget);
      await _submit(tester);
      expect(find.byKey(k('onboard_fix_fields')), findsOneWidget);
      expect(await _docs(tester, db, 'contracts'), isEmpty);
      expect(await _docs(tester, db, 'transactions'), isEmpty);
    });

    testWidgets('upfront ₹0 shows the helper and is accepted (net = '
        'sanctioned)', (WidgetTester tester) async {
      final (:db, router: _) = await _pump(tester, initial: _onboard);
      expect(
        find.text(
          'Enter what was deducted at disbursement. Unknown? Enter ₹0.',
        ),
        findsOneWidget,
      );
      await _weeklyTerms(tester, upfront: '0');
      await typeInto(tester, 'opening_total_field', '55000');
      await _submit(tester);
      final c = (await _docs(tester, db, 'contracts')).single;
      expect(c['upfrontPaise'], 0);
      expect(c['netDisbursedPaise'], 10000000);
      final disb = (await _docs(
        tester,
        db,
        'transactions',
      )).singleWhere((Map<String, dynamic> m) => m['type'] == 'disbursement');
      expect(disb['amountPaise'], 10000000);
      expect(disb['paidOn'], '2023-08-29');
    });
  });

  group('entry points', () {
    testWidgets('owner: borrower profile "Existing loan" opens onboarding '
        'with the borrower preselected; the toggle keeps it', (
      WidgetTester tester,
    ) async {
      await _pump(tester, initial: '/borrowers/b1');
      await _tap(tester, 'borrower_existing_loan');
      expect(find.text('Onboard existing loan'), findsOneWidget);
      expect(find.text('Anita Sharma'), findsWidgets);
      await tester.tap(find.text('New loan').first);
      await tester.pumpAndSettle();
      expect(find.text('New loan contract'), findsOneWidget);
      expect(find.byKey(k('loan_kind_toggle')), findsOneWidget);
      expect(find.text('Anita Sharma'), findsWidgets);
    });

    testWidgets('collector: no Existing loan button on the profile', (
      WidgetTester tester,
    ) async {
      await _pump(tester, initial: '/borrowers/b1', role: Role.collector);
      expect(find.byKey(k('borrower_existing_loan')), findsNothing);
      expect(find.byKey(k('borrower_new_loan')), findsNothing);
    });

    testWidgets('collector on /contracts/new sees no toggle', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        initial: '/contracts/new?borrowerId=b1',
        role: Role.collector,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(k('loan_kind_toggle')), findsNothing);
    });

    testWidgets('collector opening /contracts/onboard directly: told, sent '
        'away, nothing saveable', (WidgetTester tester) async {
      final (:db, router: _) = await _pump(
        tester,
        initial: _onboard,
        role: Role.collector,
      );
      expect(find.byKey(k('onboard_submit')), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Only owners can onboard loans.'), findsOneWidget);
      expect(find.byKey(k('onboard_submit')), findsNothing);
      expect(find.byKey(k('opening_total_field')), findsNothing);
      expect(await _docs(tester, db, 'contracts'), isEmpty);
    });
  });

  group('layout', () {
    testWidgets('360 wide at 1.3× text: no overflow with preview, itemised '
        'rows and the row editor', (WidgetTester tester) async {
      await _pump(tester, initial: _onboard, width: 360, textScale: 1.3);
      await _weeklyTerms(tester);
      await typeInto(tester, 'opening_total_field', '55000');
      await tester.pumpAndSettle();
      expect(find.byKey(k('onboarding_preview')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _itemisedMode(tester);
      await _tap(tester, 'fill_from_schedule');
      await _enterPickerDate(tester, d(2023, 10, 31));
      expect(tester.takeException(), isNull);
      await _tap(tester, 'add_past_payment');
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1024: 7/5 two-pane layout and the row editor is a dialog '
        '(≤ 560 wide)', (WidgetTester tester) async {
      await _pump(tester, initial: _onboard, width: 1024, height: 1400);
      final form = find.byKey(k('onboard_form'));
      final pane = find.byKey(k('onboard_preview_pane'));
      expect(form, findsOneWidget);
      expect(pane, findsOneWidget);
      final ratio = tester.getSize(form).width / tester.getSize(pane).width;
      expect(ratio, closeTo(7 / 5, 0.01));
      expect(
        tester.getTopLeft(pane).dx,
        greaterThan(tester.getTopLeft(form).dx),
      );
      await _weeklyTerms(tester);
      await _itemisedMode(tester);
      await _tap(tester, 'add_past_payment');
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester.getSize(find.byKey(k('past_payment_sheet'))).width,
        lessThanOrEqualTo(560),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
