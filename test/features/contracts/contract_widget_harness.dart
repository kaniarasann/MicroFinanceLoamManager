import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/contracts/presentation/screens/contract_detail_screen.dart';
import 'package:nordic_ledger/features/contracts/presentation/screens/contract_placeholder_screen.dart';
import 'package:nordic_ledger/features/contracts/presentation/screens/create_contract_screen.dart';
import 'package:nordic_ledger/features/contracts/presentation/screens/onboard_contract_screen.dart';

import 'contract_test_support.dart';

Key k(String v) => ValueKey<String>(v);

/// Pumps the contract routes (`/home`, `/contracts/new`, `/contracts/:id`,
/// `/contracts/:id/pay`) at [initial] with fake Firestore.
Future<FakeFirebaseFirestore> pumpContracts(
  WidgetTester tester, {
  required String initial,
  double width = 400,
  double height = 4000,
  Role role = Role.owner,
  LedgerSeed? seed,
  CivilDate? today,
  double textScale = 1,
  List<Override> extraOverrides = const <Override>[],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  final db = FakeFirebaseFirestore();
  await tester.runAsync(() async {
    await seedCompany(db);
    await seed?.writeTo(db);
  });
  final router = GoRouter(
    initialLocation: initial,
    routes: <RouteBase>[
      GoRoute(
        path: '/home',
        builder: (BuildContext c, GoRouterState s) =>
            const Scaffold(body: Text('Home')),
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
      overrides: <Override>[
        ...contractOverrides(db, role: role, today: today),
        ...extraOverrides,
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
  return db;
}

Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Types into the TextField inside the widget keyed [key].
Future<void> typeInto(WidgetTester tester, String key, String text) async {
  final byKey = find.byKey(k(key));
  final field = find.descendant(of: byKey, matching: find.byType(TextField));
  await tester.enterText(field.evaluate().isEmpty ? byKey : field, text);
  await tester.pump();
}
