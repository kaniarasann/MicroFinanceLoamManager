import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/company/application/members_providers.dart';
import 'package:nordic_ledger/features/company/data/invite_share_service.dart';
import 'package:nordic_ledger/features/contracts/presentation/screens/contract_detail_screen.dart';
import 'package:nordic_ledger/features/payments/presentation/screens/record_payment_sheet.dart';
import 'package:nordic_ledger/features/rollover/presentation/screens/rollover_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../contracts/contract_test_support.dart';
import '../contracts/contract_widget_harness.dart' show k, pumpFrames;

export '../contracts/contract_widget_harness.dart' show k, pumpFrames, typeInto;

/// The launched receipt URIs.
final List<Uri> launchedUris = <Uri>[];

/// Pumps `/contracts/:id` with the real `pay` (sheet / dialog page) and
/// `rollover` routes at [initial] on fake Firestore seeded with [seed]
/// (default: the Stitch contract viewed on 3 Dec 2023).
Future<FakeFirebaseFirestore> pumpPayments(
  WidgetTester tester, {
  String initial = '/contracts/c1/pay',
  double width = 400,
  double height = 2400,
  Role role = Role.owner,
  LedgerSeed? seed,
  CivilDate? today,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  launchedUris.clear();
  final db = FakeFirebaseFirestore();
  await tester.runAsync(() async {
    await seedCompany(db);
    await (seed ?? stitchSeed()).writeTo(db);
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
        path: '/contracts/:id',
        builder: (BuildContext c, GoRouterState s) =>
            ContractDetailScreen(contractId: s.pathParameters['id']!),
        routes: <RouteBase>[
          GoRoute(
            path: 'pay',
            pageBuilder: (BuildContext c, GoRouterState s) =>
                recordPaymentPage(s),
          ),
          GoRoute(
            path: 'rollover',
            builder: (BuildContext c, GoRouterState s) =>
                RolloverScreen(contractId: s.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ...contractOverrides(db, role: role, today: today ?? kStitchToday),
        inviteShareServiceProvider.overrideWithValue(
          InviteShareService(
            launch: (Uri uri, LaunchMode mode) async {
              launchedUris.add(uri);
              return true;
            },
          ),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await pumpFrames(tester);
  return db;
}

/// Lets a write and its snapshots settle (real async for fake Firestore).
Future<void> settleWrites(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await pumpFrames(tester);
}

/// Taps [key] after scrolling it into view.
Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(k(key));
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}
