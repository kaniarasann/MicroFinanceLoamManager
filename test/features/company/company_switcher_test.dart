import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/app.dart';
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/features/auth/presentation/screens/mpin_unlock_screen.dart';
import 'package:nordic_ledger/features/company/presentation/members_screen.dart';
import 'package:nordic_ledger/features/dashboard/presentation/screens/home_screen.dart';
import 'package:nordic_ledger/features/onboarding/presentation/screens/join_company_screen.dart';
import 'package:nordic_ledger/features/onboarding/presentation/screens/register_company_screen.dart';

import '../auth/auth_fakes.dart';
import '../onboarding/onboarding_test_support.dart';

Future<AuthHarness> pumpLocked(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  final h = AuthHarness(signedIn: kAsha);
  await tester.runAsync(() async {
    await h.mpin.setMpin(kAsha.uid, '2468');
    await OnboardingFixtures.company(h.db, cid: 'a', name: 'A Co');
    await OnboardingFixtures.company(h.db, cid: 'b', name: 'B Co');
    await OnboardingFixtures.membership(
      h.db,
      uid: kAsha.uid,
      cid: 'a',
      name: 'A Co',
      joinedAt: DateTime.utc(2026, 11, 1),
    );
    await OnboardingFixtures.membership(
      h.db,
      uid: kAsha.uid,
      cid: 'b',
      name: 'B Co',
      role: 'collector',
      joinedAt: DateTime.utc(2026, 11, 2),
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
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('MPIN unlock shows "{Company} · {Role}" under the greeting', (
    WidgetTester tester,
  ) async {
    await pumpLocked(tester, 400);
    expect(find.byType(MpinUnlockScreen), findsOneWidget);
    expect(find.text('A Co · Owner'), findsOneWidget);
  });

  for (final width in <double>[400, 1200]) {
    testWidgets('switcher lists companies and switches @${width.toInt()}', (
      WidgetTester tester,
    ) async {
      await pumpLocked(tester, width);
      await unlock(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('· Owner'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('company_header')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('company_switcher')), findsOne);
      expect(
        width < 600 ? find.byType(BottomSheet) : find.byType(Dialog),
        findsOneWidget,
      );
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Collector'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Join another company'), findsOneWidget);
      expect(find.text('Register a new company'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('switcher_company_b')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('company_switcher')),
        findsNothing,
      );
      expect(find.text('B Co'), findsOneWidget);
      expect(find.text('· Collector'), findsOneWidget);
    });
  }

  testWidgets('switcher → Join another company / Register a new company', (
    WidgetTester tester,
  ) async {
    await pumpLocked(tester, 400);
    await unlock(tester);
    await tester.tap(find.byKey(const ValueKey<String>('company_header')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('switcher_join')));
    await tester.pumpAndSettle();
    expect(find.byType(JoinCompanyScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('company_header')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('switcher_register')));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterCompanyScreen), findsOneWidget);
  });

  testWidgets('removed from the active company: message + switch out', (
    WidgetTester tester,
  ) async {
    final h = await pumpLocked(tester, 400);
    await unlock(tester);
    expect(find.text('A Co'), findsOneWidget);

    await tester.runAsync(
      () => TypedRefs(h.db).member('a', kAsha.uid).delete(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('You no longer have access to A Co'), findsOneWidget);
    expect(find.text('B Co'), findsOneWidget);
    expect(find.text('· Collector'), findsOneWidget);
    // Let the snackbar time out.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('Settings → Members & invites', (WidgetTester tester) async {
    await pumpLocked(tester, 400);
    await unlock(tester);
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Members & invites'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('settings_members')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('settings_members')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MembersScreen), findsOneWidget);
  });
}
