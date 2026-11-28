import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/features/auth/application/session_controller.dart';
import 'package:nordic_ledger/features/auth/presentation/screens/mpin_setup_screen.dart';
import 'package:nordic_ledger/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:nordic_ledger/features/settings/presentation/screens/change_mpin_screen.dart';
import 'package:nordic_ledger/features/settings/presentation/screens/settings_screen.dart';

import 'settings_test_support.dart';

Future<void> enter(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.byKey(ValueKey<String>('pin_key_$d')));
    await tester.pump();
  }
  await settle(tester, 2);
}

Future<AuthHarness> openChangeMpin(
  WidgetTester tester, {
  double width = 400,
  double textScale = 1,
}) async {
  final h = await pumpSettingsApp(tester, width: width, textScale: textScale);
  await tapSetting(tester, 'settings_change_mpin');
  expect(find.byType(ChangeMpinScreen), findsOneWidget);
  return h;
}

void main() {
  testWidgets('current → new → confirm changes the MPIN', (
    WidgetTester tester,
  ) async {
    final h = await openChangeMpin(tester);
    expect(find.text('Enter your current MPIN'), findsOneWidget);
    await enter(tester, '2468');
    expect(find.text('Choose a new MPIN'), findsOneWidget);
    await enter(tester, '1357');
    expect(find.text('Confirm new MPIN'), findsOneWidget);
    await enter(tester, '1357');
    expect(find.text(ChangeMpinScreen.changedMessage), findsOneWidget);
    expect(find.byType(SettingsScreen), findsOneWidget);

    final ok = await tester.runAsync(() => h.mpin.verify(kAsha.uid, '1357'));
    expect(ok!.ok, isTrue);
    final old = await tester.runAsync(() => h.mpin.verify(kAsha.uid, '2468'));
    expect(old!.ok, isFalse);
  });

  testWidgets('a wrong current MPIN counts a try', (WidgetTester tester) async {
    final h = await openChangeMpin(tester);
    await enter(tester, '0000');
    expect(find.text(ChangeMpinScreen.wrongMessage(4)), findsOneWidget);
    expect(find.text('Enter your current MPIN'), findsOneWidget);
    final n = await tester.runAsync(() => h.mpin.failedAttempts(kAsha.uid));
    expect(n, 1);
  });

  testWidgets('the 5th wrong try signs out with the lockout notice', (
    WidgetTester tester,
  ) async {
    final h = await openChangeMpin(tester);
    for (var i = 0; i < 5; i++) {
      await enter(tester, '0000');
    }
    await settle(tester);
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text(kLockoutMessage), findsOneWidget);
    expect(await tester.runAsync(() => h.mpin.hasMpin(kAsha.uid)), isFalse);
  });

  testWidgets('same-as-old and mismatch are refused', (
    WidgetTester tester,
  ) async {
    await openChangeMpin(tester);
    await enter(tester, '2468');
    await enter(tester, '2468');
    expect(find.text(ChangeMpinScreen.sameAsOldMessage), findsOneWidget);
    await enter(tester, '1357');
    await enter(tester, '9999');
    expect(find.text(MpinSetupScreen.mismatchMessage), findsOneWidget);
    expect(find.text('Choose a new MPIN'), findsOneWidget);
  });

  for (final (double width, double scale) in <(double, double)>[
    (1024, 1),
    (360, 1.3),
  ]) {
    testWidgets('lays out @${width.toInt()} ×$scale', (
      WidgetTester tester,
    ) async {
      await openChangeMpin(tester, width: width, textScale: scale);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey<String>('pin_key_0')), findsOneWidget);
    });
  }
}
