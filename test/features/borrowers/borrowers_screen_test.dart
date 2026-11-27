import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/borrowers/presentation/screens/borrower_profile_screen.dart';
import 'package:nordic_ledger/features/borrowers/presentation/screens/borrowers_screen.dart';
import 'package:nordic_ledger/features/borrowers/data/borrower_repository.dart';
import 'package:nordic_ledger/features/borrowers/presentation/widgets/borrower_form.dart';
import 'package:nordic_ledger/features/contracts/presentation/screens/contract_placeholder_screen.dart';

import 'borrower_test_support.dart';

Key k(String v) => ValueKey<String>(v);

Future<FakeFirebaseFirestore> pumpBorrowers(
  WidgetTester tester, {
  required double width,
  Role role = Role.owner,
  LedgerSeed? seed,
  LaunchLog? launches,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1600);
  addTearDown(tester.view.reset);
  final db = FakeFirebaseFirestore();
  if (seed != null) await tester.runAsync(() => seed.writeTo(db));
  final router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext c, GoRouterState s) =>
            const Scaffold(body: BorrowersScreen()),
      ),
      GoRoute(
        path: '/borrowers/:id',
        builder: (BuildContext c, GoRouterState s) =>
            BorrowerProfileScreen(borrowerId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/contracts/new',
        builder: (BuildContext c, GoRouterState s) =>
            ContractPlaceholderScreen.newLoan(
              borrowerId: s.uri.queryParameters['borrowerId'],
            ),
      ),
      GoRoute(
        path: '/contracts/:id',
        builder: (BuildContext c, GoRouterState s) =>
            ContractPlaceholderScreen.detail(
              contractId: s.pathParameters['id']!,
            ),
        routes: <RouteBase>[
          GoRoute(
            path: 'pay',
            builder: (BuildContext c, GoRouterState s) =>
                ContractPlaceholderScreen.payment(
                  contractId: s.pathParameters['id']!,
                ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: borrowerOverrides(db, role: role, launches: launches),
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
  return db;
}

Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('empty states', () {
    testWidgets('owner: "Add your first borrower" with an add button', (
      WidgetTester tester,
    ) async {
      await pumpBorrowers(tester, width: 400);
      expect(find.text('Add your first borrower'), findsOneWidget);
      expect(find.byKey(k('borrowers_empty_add')), findsOneWidget);
      expect(find.byKey(k('borrowers_add')), findsOneWidget);
    });

    testWidgets('collector: "No borrowers yet", no add controls', (
      WidgetTester tester,
    ) async {
      await pumpBorrowers(tester, width: 400, role: Role.collector);
      expect(find.text('No borrowers yet'), findsOneWidget);
      expect(find.byKey(k('borrowers_empty_add')), findsNothing);
      expect(find.byKey(k('borrowers_add')), findsNothing);
    });
  });

  for (final width in <double>[400, 1200]) {
    final w = width.toInt();
    testWidgets('list rows and search @$w', (WidgetTester tester) async {
      await pumpBorrowers(tester, width: width, seed: listFixture());
      expect(find.text('Search name or phone'), findsOneWidget);
      for (final label in <String>[
        'All',
        'Active only',
        'Due this week',
        'Overdue',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Anita Sharma'), findsOneWidget);
      expect(find.text('+91 98450 12890'), findsOneWidget);
      expect(find.text('2 active loans'), findsOneWidget);
      expect(find.text('₹1,35,000'), findsOneWidget);
      expect(find.text('Overdue 7d'), findsOneWidget);
      expect(find.text('No active loan'), findsOneWidget);

      await tester.enterText(find.byKey(k('borrowers_search')), '99001');
      await pumpFrames(tester);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Anita Sharma'), findsNothing);

      await tester.enterText(find.byKey(k('borrowers_search')), '');
      await pumpFrames(tester);
      await tester.ensureVisible(find.byKey(k('filter_overdue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(k('filter_overdue')));
      await pumpFrames(tester);
      expect(find.text('Anita Sharma'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsNothing);
    });

    testWidgets('profile: tiles, tabs, cards, receipts @$w', (
      WidgetTester tester,
    ) async {
      final launches = LaunchLog();
      await pumpBorrowers(
        tester,
        width: width,
        seed: listFixture(),
        launches: launches,
      );
      if (width >= 840) {
        expect(find.text('Select a borrower'), findsOneWidget);
      }
      await tester.tap(find.byKey(k('borrower_row_b1')));
      await tester.pumpAndSettle();
      await pumpFrames(tester);

      if (width >= 840) {
        // Split view: list stays, selected row highlighted.
        expect(find.byKey(k('borrowers_list')), findsOneWidget);
        final row = tester.widget<Material>(
          find
              .descendant(
                of: find.byKey(k('borrower_row_b1')),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(row.color, AppColors.pressed);
        expect(
          (row.shape! as RoundedRectangleBorder).side.color,
          AppColors.primary,
        );
      } else {
        expect(find.byType(BorrowerProfileScreen), findsOneWidget);
      }

      expect(find.text('Anna Nagar'), findsOneWidget);
      expect(find.text('Active exposure'), findsOneWidget);
      expect(find.text('Lifetime lent'), findsOneWidget);
      expect(find.text('Collected'), findsOneWidget);
      expect(find.text('₹1,80,000'), findsOneWidget);
      expect(find.text('₹45,000'), findsWidgets);
      expect(find.text('Active (2)'), findsOneWidget);
      expect(find.text('Closed (1)'), findsOneWidget);
      expect(find.text('Loan #04'), findsOneWidget);
      expect(find.text('Due today'), findsOneWidget);
      expect(find.text('1/10 cycles'), findsOneWidget);
      expect(find.text('10% cleared'), findsNWidgets(2)); // c1 and c2
      expect(find.byKey(k('record_c1')), findsOneWidget);
      expect(find.text('Record ₹10,000'), findsOneWidget);
      expect(find.text('New loan'), findsOneWidget);

      await tester.tap(find.byKey(k('borrower_whatsapp')));
      await tester.pump();
      expect(launches.launched.single.host, 'wa.me');
      await tester.tap(find.byKey(k('borrower_call')));
      await tester.pump();
      expect(launches.launched.last.toString(), 'tel:+919845012890');

      await tester.ensureVisible(find.byKey(k('recent_receipts')));
      expect(find.text('Bal ₹43,000'), findsOneWidget);

      await tester.tap(find.text('Ledger'));
      await tester.pumpAndSettle();
      expect(find.byKey(k('ledger_t-c2-rev')), findsOneWidget);
      expect(find.text('UPI'), findsOneWidget);
      expect(find.byKey(k('recent_receipts')), findsNothing);

      await tester.tap(find.text('Closed (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Loan #02'), findsOneWidget);
      expect(find.text('Rolled over → #04'), findsOneWidget);
      await tester.tap(find.byKey(k('rolled_link_c3')));
      await tester.pumpAndSettle();
      expect(find.byKey(k('contract_detail_c1')), findsOneWidget);
    });
  }

  testWidgets('collector sees no add, edit or new-loan controls', (
    WidgetTester tester,
  ) async {
    await pumpBorrowers(
      tester,
      width: 1200,
      role: Role.collector,
      seed: listFixture(),
    );
    expect(find.byKey(k('borrowers_add')), findsNothing);
    await tester.tap(find.byKey(k('borrower_row_b1')));
    await pumpFrames(tester);
    expect(find.byKey(k('borrower_menu')), findsNothing);
    expect(find.byKey(k('borrower_new_loan')), findsNothing);
    expect(find.byKey(k('borrower_existing_loan')), findsNothing);
    // Collectors still call, message and record payments.
    expect(find.byKey(k('borrower_call')), findsOneWidget);
    expect(find.byKey(k('record_c1')), findsOneWidget);
  });

  testWidgets('owner: Record and New loan route to their placeholders', (
    WidgetTester tester,
  ) async {
    await pumpBorrowers(tester, width: 400, seed: listFixture());
    await tester.tap(find.byKey(k('borrower_row_b1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(k('record_c1')));
    await tester.pumpAndSettle();
    expect(find.byKey(k('contract_pay_c1')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(k('borrower_existing_loan')), findsOneWidget);
    await tester.tap(find.byKey(k('borrower_new_loan')));
    await tester.pumpAndSettle();
    expect(find.byKey(k('contract_new_b1')), findsOneWidget);
  });

  group('borrower form', () {
    for (final width in <double>[400, 1200]) {
      testWidgets('validation and save @${width.toInt()}', (
        WidgetTester tester,
      ) async {
        final db = await pumpBorrowers(
          tester,
          width: width,
          seed: listFixture(),
        );
        await tester.tap(find.byKey(k('borrowers_add')));
        await tester.pumpAndSettle();
        expect(
          width < 600 ? find.byType(BottomSheet) : find.byType(Dialog),
          findsOneWidget,
        );

        // Empty name + bad phone.
        await tester.enterText(find.byKey(k('borrower_phone')), '12345');
        await tester.tap(find.byKey(k('borrower_save')));
        await tester.pump();
        expect(find.text("Enter the borrower's name."), findsOneWidget);
        expect(
          find.text('Enter a 10-digit Indian mobile number (starts with 6–9).'),
          findsOneWidget,
        );

        // 1-char name.
        await tester.enterText(find.byKey(k('borrower_name')), 'A');
        await tester.tap(find.byKey(k('borrower_save')));
        await tester.pump();
        expect(
          find.text('Name must be at least 2 characters.'),
          findsOneWidget,
        );

        // Duplicate phone warns and blocks saving.
        await tester.enterText(find.byKey(k('borrower_name')), 'Kavya Nair');
        await tester.enterText(find.byKey(k('borrower_phone')), '98450 12890');
        await tester.pump();
        expect(find.byKey(k('borrower_phone_duplicate')), findsOneWidget);
        expect(
          find.text('This mobile is already saved for Anita Sharma.'),
          findsOneWidget,
        );
        final save = tester.widget<FilledButton>(
          find.byKey(k('borrower_save')),
        );
        expect(save.onPressed, isNull);

        // A fresh number saves.
        await tester.enterText(find.byKey(k('borrower_phone')), '9123456780');
        await tester.pump();
        expect(find.byKey(k('borrower_phone_duplicate')), findsNothing);
        await tester.tap(find.byKey(k('borrower_save')));
        await tester.pumpAndSettle();
        await pumpFrames(tester);
        expect(find.byKey(k('borrower_form')), findsNothing);
        expect(find.text(BorrowerCopy.added), findsOneWidget);
        final docs = await tester.runAsync(
          () => db
              .collection('companies/$kCid/borrowers')
              .where('phoneE164', isEqualTo: '+919123456780')
              .get(),
        );
        expect(docs!.docs.single.data()['name'], 'Kavya Nair');
        expect(find.text('Kavya Nair'), findsWidgets);
      });
    }

    testWidgets('edit pre-fills and keeps its own number', (
      WidgetTester tester,
    ) async {
      await pumpBorrowers(tester, width: 1200, seed: listFixture());
      await tester.tap(find.byKey(k('borrower_row_b1')));
      await pumpFrames(tester);
      await tester.tap(find.byKey(k('borrower_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(k('borrower_edit')));
      await tester.pumpAndSettle();
      expect(find.text('Edit borrower'), findsOneWidget);
      final phone = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(k('borrower_phone')),
          matching: find.byType(TextField),
        ),
      );
      expect(phone.controller!.text, '98450 12890');
      expect(find.byKey(k('borrower_phone_duplicate')), findsNothing);
      await tester.enterText(find.byKey(k('borrower_locality')), 'Adyar');
      await tester.tap(find.byKey(k('borrower_save')));
      await tester.pumpAndSettle();
      await pumpFrames(tester);
      expect(find.text(BorrowerCopy.updated), findsOneWidget);
      expect(find.text('Adyar'), findsOneWidget);
    });

    test('queued writes say "Saved · will sync"', () {
      expect(
        BorrowerCopy.saved(WriteOutcome.queued, BorrowerCopy.added),
        'Saved · will sync',
      );
      expect(
        BorrowerCopy.saved(WriteOutcome.synced, BorrowerCopy.added),
        'Borrower added',
      );
    });
  });

  for (final width in <double>[360, 1200]) {
    testWidgets('list and profile survive text scale 1.3× @${width.toInt()}', (
      WidgetTester tester,
    ) async {
      await pumpBorrowers(
        tester,
        width: width,
        seed: listFixture(),
        textScale: 1.3,
      );
      await tester.tap(find.byKey(k('borrower_row_b1')));
      await tester.pumpAndSettle();
      await pumpFrames(tester);
      expect(find.text('Active exposure'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
