import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_ledger/core/routing/app_router.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/auth/application/auth_providers.dart';
import 'package:nordic_ledger/features/auth/data/secure_key_value_store.dart';
import 'package:nordic_ledger/features/borrowers/presentation/screens/borrowers_screen.dart';
import 'package:nordic_ledger/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:nordic_ledger/features/contracts/presentation/screens/contract_detail_screen.dart';
import 'package:nordic_ledger/features/contracts/presentation/screens/create_contract_screen.dart';
import 'package:nordic_ledger/features/company/presentation/members_screen.dart';
import 'package:nordic_ledger/features/payments/presentation/screens/record_payment_sheet.dart';
import 'package:nordic_ledger/features/rollover/presentation/screens/rollover_screen.dart';
import 'package:nordic_ledger/features/contracts/presentation/screens/onboard_contract_screen.dart';
import 'package:nordic_ledger/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:nordic_ledger/features/dashboard/presentation/screens/home_screen.dart';
import 'package:nordic_ledger/features/notifications/application/notification_providers.dart';
import 'package:nordic_ledger/features/notifications/data/local_notification_gateway.dart';
import 'package:nordic_ledger/features/overdue/presentation/screens/overdue_screen.dart';
import 'package:nordic_ledger/features/settings/application/settings_providers.dart';
import 'package:nordic_ledger/features/settings/data/sync_signals.dart';
import 'package:nordic_ledger/features/settings/presentation/screens/delete_account_screen.dart';
import 'package:nordic_ledger/features/settings/presentation/screens/legal_screen.dart';
import 'package:nordic_ledger/features/settings/presentation/screens/settings_screen.dart';

import '../features/auth/auth_fakes.dart';
import '../features/contracts/contract_test_support.dart';

/// Task 16, responsive pass: every shell destination and the pushed ledger
/// screens through the real [HomeScreen] / router at compact (400),
/// expanded (1024) and 360 wide at 1.3× text, over the aggregates fixture
/// (an overdue loan, a due-today row, a rolled-over loan). Any RenderFlex
/// overflow or layout exception fails the test.
const List<(double, double)> sizes = <(double, double)>[
  (400, 1),
  (1024, 1),
  (360, 1.3),
];

Future<void> pumpShell(
  WidgetTester tester, {
  required String initial,
  required double width,
  double textScale = 1,
  double height = 2400,
  Role role = Role.owner,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  final db = FakeFirebaseFirestore();
  await tester.runAsync(() async {
    await seedCompany(db);
    await aggregatesFixture().writeTo(db);
  });
  final router = GoRouter(
    initialLocation: initial,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.home,
        builder: (BuildContext c, GoRouterState s) =>
            HomeScreen(initialTab: s.uri.queryParameters[AppRoutes.tabParam]),
      ),
      GoRoute(
        path: AppRoutes.overdue,
        builder: (BuildContext c, GoRouterState s) => const OverdueScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardContractPath,
        builder: (BuildContext c, GoRouterState s) =>
            const OnboardContractScreen(),
      ),
      GoRoute(
        path: AppRoutes.newContractPath,
        builder: (BuildContext c, GoRouterState s) =>
            const CreateContractScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.contracts}/:id',
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
      GoRoute(
        path: AppRoutes.members,
        builder: (BuildContext c, GoRouterState s) => const MembersScreen(),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (BuildContext c, GoRouterState s) =>
            const LegalScreen(document: LegalDocument.terms),
      ),
      GoRoute(
        path: AppRoutes.deleteAccount,
        builder: (BuildContext c, GoRouterState s) =>
            const DeleteAccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (BuildContext c, GoRouterState s) =>
            const LegalScreen(document: LegalDocument.privacy),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ...contractOverrides(db, role: role),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(signedIn: kAsha),
        ),
        secureKeyValueStoreProvider.overrideWithValue(
          InMemorySecureKeyValueStore(),
        ),
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
        localNotificationGatewayProvider.overrideWithValue(
          InMemoryNotificationGateway(),
        ),
        notificationDebounceProvider.overrideWithValue(Duration.zero),
        syncSignalsProvider.overrideWithValue(FakeSyncSignals()),
        appVersionProvider.overrideWith((Ref ref) async => '1.0.0 (build 1)'),
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
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Scrolls every vertical scrollable on screen to the end, so content below
/// the fold is laid out and painted too.
Future<void> scrollAll(WidgetTester tester) async {
  final scrollables = find.byWidgetPredicate(
    (Widget w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );
  for (var i = 0; i < scrollables.evaluate().length; i++) {
    final state = tester.state<ScrollableState>(scrollables.at(i));
    final pos = state.position;
    if (!pos.hasContentDimensions || pos.maxScrollExtent <= 0) continue;
    pos.jumpTo(pos.maxScrollExtent);
    await tester.pump();
  }
}

void expectNavFor(WidgetTester tester, double width) {
  if (width < 600) {
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  } else {
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.labelType, NavigationRailLabelType.all);
  }
}

void main() {
  final tabs = <String, Type>{
    'dashboard': DashboardScreen,
    'calendar': CalendarScreen,
    'borrowers': BorrowersScreen,
    'settings': SettingsScreen,
  };

  for (final (double width, double scale) in sizes) {
    final label = '@${width.toInt()} ×$scale';

    for (final MapEntry<String, Type>(:key, :value) in tabs.entries) {
      testWidgets('shell: $key $label', (WidgetTester tester) async {
        await pumpShell(
          tester,
          initial: AppRoutes.homeTab(key),
          width: width,
          textScale: scale,
        );
        expect(find.byType(value), findsOneWidget);
        expectNavFor(tester, width);
        await scrollAll(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('shell: Due Today deep link scrolls the dashboard $label', (
      WidgetTester tester,
    ) async {
      await pumpShell(
        tester,
        initial: AppRoutes.dueToday,
        width: width,
        textScale: scale,
        height: 800,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text('Due today'), findsWidgets);
      final dash = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('dashboard')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(dash.position.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('collector shell: settings $label', (
      WidgetTester tester,
    ) async {
      await pumpShell(
        tester,
        initial: AppRoutes.settings,
        width: width,
        textScale: scale,
        role: Role.collector,
      );
      expect(find.text('Members'), findsOneWidget);
      await scrollAll(tester);
      expect(tester.takeException(), isNull);
    });

    for (final (String name, String route, Type type)
        in <(String, String, Type)>[
          ('overdue tracker', AppRoutes.overdue, OverdueScreen),
          (
            'contract detail (overdue loan)',
            AppRoutes.contract('c2'),
            ContractDetailScreen,
          ),
          (
            'contract detail (rolled over)',
            AppRoutes.contract('c3'),
            ContractDetailScreen,
          ),
          (
            'onboard an existing loan',
            AppRoutes.onboardContractPath,
            OnboardContractScreen,
          ),
          ('privacy policy', AppRoutes.privacy, LegalScreen),
          // F6 (attempt 2).
          ('terms of service', AppRoutes.terms, LegalScreen),
          (
            'record payment sheet',
            AppRoutes.recordPayment('c2'),
            RecordPaymentSheet,
          ),
          ('rollover', AppRoutes.rollover('c1'), RolloverScreen),
          ('create contract', AppRoutes.newContractPath, CreateContractScreen),
          ('members & invites', AppRoutes.members, MembersScreen),
        ]) {
      testWidgets('$name $label', (WidgetTester tester) async {
        await pumpShell(tester, initial: route, width: width, textScale: scale);
        expect(find.byType(type), findsOneWidget);
        await scrollAll(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
