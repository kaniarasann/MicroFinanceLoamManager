import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/app.dart';
import 'package:nordic_ledger/core/routing/app_router.dart';
import 'package:nordic_ledger/features/auth/application/lock_controller.dart';
import 'package:nordic_ledger/features/auth/presentation/screens/mpin_unlock_screen.dart';
import 'package:nordic_ledger/features/dashboard/presentation/screens/home_screen.dart';
import 'package:nordic_ledger/features/notifications/application/notification_providers.dart';
import 'package:nordic_ledger/features/overdue/presentation/screens/overdue_screen.dart';

import '../auth/auth_fakes.dart';
import '../onboarding/onboarding_test_support.dart';

Future<AuthHarness> pumpLocked(
  WidgetTester tester, {
  String? launchPayload,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 900);
  addTearDown(tester.view.reset);
  final h = AuthHarness(signedIn: kAsha);
  h.notifications.pendingLaunchPayload = launchPayload;
  await tester.runAsync(() async {
    await h.mpin.setMpin(kAsha.uid, '2468');
    await OnboardingFixtures.company(
      h.db,
      cid: 'a',
      name: 'A Co',
      owners: <String>[kAsha.uid],
    );
    await OnboardingFixtures.membership(
      h.db,
      uid: kAsha.uid,
      cid: 'a',
      name: 'A Co',
    );
  });
  await tester.pumpWidget(
    ProviderScope(overrides: h.overrides, child: const App()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return h;
}

Future<void> unlock(WidgetTester tester) async {
  for (final d in '2468'.split('')) {
    await tester.tap(find.byKey(ValueKey<String>('pin_key_$d')));
    await tester.pump();
  }
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  group('AppRoutes.isNotificationTarget', () {
    test('accepts the three payload routes', () {
      expect(AppRoutes.isNotificationTarget(AppRoutes.dueToday), isTrue);
      expect(AppRoutes.isNotificationTarget(AppRoutes.overdue), isTrue);
      expect(
        AppRoutes.isNotificationTarget(AppRoutes.recordPayment('c-1')),
        isTrue,
      );
    });

    test('rejects everything else', () {
      for (final bad in <String>[
        '',
        '/home',
        '/settings/delete-account',
        '/contracts/c-1',
        '/contracts/c-1/rollover',
        '/contracts/new/pay',
        '/contracts/onboard/pay',
        '/contracts//pay',
        '/contracts/c-1/pay?x=1',
        'https://evil.example/overdue',
        'nordicledger://app/overdue',
        '/join?code=K7Q2MD',
      ]) {
        expect(AppRoutes.isNotificationTarget(bad), isFalse, reason: bad);
      }
    });
  });

  testWidgets('a notification that cold-starts the app opens after the MPIN '
      'unlock, on top of the shell', (WidgetTester tester) async {
    await pumpLocked(tester, launchPayload: AppRoutes.overdue);
    // Held while locked.
    expect(find.byType(MpinUnlockScreen), findsOneWidget);
    expect(find.byType(OverdueScreen), findsNothing);

    await unlock(tester);
    expect(find.byType(OverdueScreen), findsOneWidget);

    // Back returns to the dashboard.
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a tap while locked waits for the unlock', (
    WidgetTester tester,
  ) async {
    final h = await pumpLocked(tester);
    h.notifications.tap(AppRoutes.overdue);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MpinUnlockScreen), findsOneWidget);
    await unlock(tester);
    expect(find.byType(OverdueScreen), findsOneWidget);
  });

  testWidgets('a tap while unlocked opens at once; the digest opens the '
      'dashboard', (WidgetTester tester) async {
    final h = await pumpLocked(tester);
    await unlock(tester);
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 300));

    h.notifications.tap(AppRoutes.dueToday);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, HomeScreen.dashboardIndex);

    h.notifications.tap(AppRoutes.overdue);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(OverdueScreen), findsOneWidget);
  });

  testWidgets('an unknown payload is ignored', (WidgetTester tester) async {
    final h = await pumpLocked(tester);
    await unlock(tester);
    h.notifications.tap('/settings/delete-account');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HomeScreen), findsOneWidget);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    expect(c.read(pendingDeepLinkProvider), isNull);
  });

  testWidgets('first unlock with a company asks for the notification '
      'permission once per install', (WidgetTester tester) async {
    final h = await pumpLocked(tester);
    await unlock(tester);
    expect(h.notifications.permissionRequests, 1);
    expect(h.storage.values[notificationPermissionAskedKey], '1');
  });

  testWidgets('a link waits while the auto-lock resume check is in flight '
      '(F1)', (WidgetTester tester) async {
    final h = await pumpLocked(tester);
    await unlock(tester);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    final inFlight = c.read(lockCheckInFlightProvider.notifier)..begin();
    h.notifications.tap(AppRoutes.overdue);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(OverdueScreen), findsNothing);
    expect(c.read(pendingDeepLinkProvider), AppRoutes.overdue);

    inFlight.end();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(OverdueScreen), findsOneWidget);
  });

  testWidgets('a link tagged for another company is dropped with a notice '
      '(F4)', (WidgetTester tester) async {
    final h = await pumpLocked(tester);
    await unlock(tester);
    h.notifications.tap(AppRoutes.withCompany(AppRoutes.overdue, 'other'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(OverdueScreen), findsNothing);
    expect(find.text(otherCompanyLinkMessage), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a link tagged for the active company opens without the tag', (
    WidgetTester tester,
  ) async {
    final h = await pumpLocked(tester);
    await unlock(tester);
    h.notifications.tap(AppRoutes.withCompany(AppRoutes.overdue, 'a'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(OverdueScreen), findsOneWidget);
  });
}
