import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/features/auth/application/session_controller.dart';
import 'package:nordic_ledger/features/auth/presentation/screens/mpin_unlock_screen.dart';

import '../auth_fakes.dart';

Future<ProviderContainer> pumpLocked(WidgetTester tester, AuthHarness h) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 900);
  addTearDown(tester.view.reset);
  await tester.runAsync(() => h.mpin.setMpin(kAsha.uid, '2468'));
  final c = h.container();
  c.listen(sessionControllerProvider, (_, _) {});
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: AppTheme.light, home: const MpinUnlockScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
  return c;
}

Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.byKey(ValueKey<String>('pin_key_$d')));
    await tester.pump();
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  test('wrongMpinMessage pluralises remaining tries', () {
    expect(wrongMpinMessage(4), 'Wrong MPIN · 4 tries left');
    expect(wrongMpinMessage(2), 'Wrong MPIN · 2 tries left');
    expect(wrongMpinMessage(1), 'Wrong MPIN · 1 try left');
  });

  testWidgets('each wrong PIN shows the decreasing remaining tries', (
    WidgetTester tester,
  ) async {
    final c = await pumpLocked(tester, AuthHarness(signedIn: kAsha));
    expect(c.read(sessionControllerProvider).stage, AuthStage.locked);
    for (final left in <int>[4, 3, 2]) {
      await enterPin(tester, '9999');
      expect(find.text(wrongMpinMessage(left)), findsOneWidget);
    }
  });

  testWidgets('right PIN after wrong attempts unlocks and clears error', (
    WidgetTester tester,
  ) async {
    final c = await pumpLocked(tester, AuthHarness(signedIn: kAsha));
    await enterPin(tester, '9999');
    expect(find.text(wrongMpinMessage(4)), findsOneWidget);
    await enterPin(tester, '2468');
    expect(c.read(sessionControllerProvider).stage, AuthStage.unlocked);
  });

  test('6th attempt via controller after lockout does not unlock', () async {
    final h = AuthHarness(signedIn: kAsha);
    await h.mpin.setMpin(kAsha.uid, '2468');
    final c = h.container();
    c.listen(sessionControllerProvider, (_, _) {});
    await pumpEventQueue();
    final s = c.read(sessionControllerProvider.notifier);
    for (var i = 0; i < 5; i++) {
      await s.unlockWithPin('0000');
    }
    await pumpEventQueue();
    expect(c.read(sessionControllerProvider).stage, AuthStage.signedOut);
    expect(h.repo.signOutCalls, 1);

    final sixth = await s.unlockWithPin('2468');
    expect(sixth.ok, isFalse);
    expect(c.read(sessionControllerProvider).stage, AuthStage.signedOut);
    expect(await h.mpin.hasMpin(kAsha.uid), isFalse);
  });
}
