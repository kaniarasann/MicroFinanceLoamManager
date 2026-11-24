import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/contracts/presentation/screens/contract_placeholder_screen.dart';
import 'package:nordic_ledger/features/overdue/presentation/screens/overdue_screen.dart';

import '../../domain/ledger/ledger_fixtures.dart' show d;
import '../borrowers/borrower_test_support.dart';

export '../../domain/ledger/ledger_fixtures.dart' show d;
export '../borrowers/borrower_test_support.dart';

Key k(String v) => ValueKey<String>(v);

/// Pumps [screen] as the `/` route (inside a Scaffold unless it is the
/// overdue screen, which brings its own) with `/overdue`, `/contracts/new`,
/// `/contracts/{id}` and `/contracts/{id}/pay` routes, over a fake
/// Firestore seeded with [seed]. Today is Tue 7 Nov 2023 (IST).
Future<FakeFirebaseFirestore> pumpLedgerScreen(
  WidgetTester tester,
  Widget screen, {
  required double width,
  double height = 2400,
  Role role = Role.owner,
  LedgerSeed? seed,
  LaunchLog? launches,
  double textScale = 1,
  bool wrapInScaffold = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  final db = FakeFirebaseFirestore();
  if (seed != null) await tester.runAsync(() => seed.writeTo(db));
  final router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext c, GoRouterState s) =>
            wrapInScaffold ? Scaffold(body: screen) : screen,
      ),
      GoRoute(
        path: '/overdue',
        builder: (BuildContext c, GoRouterState s) => const OverdueScreen(),
      ),
      GoRoute(
        path: '/contracts/new',
        builder: (BuildContext c, GoRouterState s) =>
            ContractPlaceholderScreen.newLoan(),
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
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Adds a closed contract whose collections exceed its sanctioned amount
/// (₹10,000 sanctioned, ₹10,800 paid → ₹800 excess).
LedgerSeed withClosedExcess(LedgerSeed seed) {
  final c = contractFor(
    'b1',
    'c9',
    loanNo: 9,
    sanctionedRs: 10000,
    installmentRs: 10000,
    firstDue: d(2023, 9, 12),
    status: ContractStatus.closed,
    totalPaidRs: 10800,
  );
  seed.contracts.add(c);
  seed.transactions.addAll(<LedgerTransaction>[
    txFor(c, 't-c9-p1', 10000, d(2023, 9, 12)),
    txFor(c, 't-c9-p2', 800, d(2023, 11, 6)),
  ]);
  return seed;
}
