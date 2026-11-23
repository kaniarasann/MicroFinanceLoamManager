// Tester — Sprint 5: a collector cannot open /contracts/new.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/app.dart';
import 'package:nordic_ledger/core/routing/app_router.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/contracts/presentation/screens/create_contract_screen.dart';
import 'package:nordic_ledger/features/dashboard/presentation/screens/home_screen.dart';

import '../../auth/auth_fakes.dart';
import '../../onboarding/onboarding_test_support.dart';
import '../contract_test_support.dart' show anita, LedgerSeed;
import '../contract_widget_harness.dart';

void main() {
  Future<ProviderContainer> unlockAs(WidgetTester tester, String role) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    final h = AuthHarness(signedIn: kAsha);
    await tester.runAsync(() async {
      await h.mpin.setMpin(kAsha.uid, '2468');
      await OnboardingFixtures.company(h.db, cid: 'a', name: 'A Co');
      await OnboardingFixtures.membership(
        h.db,
        uid: kAsha.uid,
        cid: 'a',
        name: 'A Co',
        role: role,
      );
    });
    final c = ProviderContainer(overrides: h.overrides);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const App()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    for (final dgt in '2468'.split('')) {
      await tester.tap(find.byKey(ValueKey<String>('pin_key_$dgt')));
      await tester.pump();
    }
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    return c;
  }

  testWidgets('real router: collector deep link to /contracts/new → home', (
    WidgetTester tester,
  ) async {
    final c = await unlockAs(tester, 'collector');
    expect(find.byType(HomeScreen), findsOneWidget);
    c.read(appRouterProvider).go(AppRoutes.newContract(borrowerId: 'b1'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(CreateContractScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('real router: owner deep link opens the create screen', (
    WidgetTester tester,
  ) async {
    final c = await unlockAs(tester, 'owner');
    c.read(appRouterProvider).go(AppRoutes.newContract(borrowerId: 'b1'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(CreateContractScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('in-screen guard: collector is bounced with a message', (
    WidgetTester tester,
  ) async {
    await pumpContracts(
      tester,
      initial: '/contracts/new?borrowerId=b1',
      role: Role.collector,
      seed: LedgerSeed()..borrowers.add(anita()),
    );
    await pumpFrames(tester);
    expect(find.byType(CreateContractScreen), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Only owners can create loans.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
