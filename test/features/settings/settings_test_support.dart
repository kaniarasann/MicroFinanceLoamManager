import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/app.dart';

import '../auth/auth_fakes.dart';
import '../onboarding/onboarding_test_support.dart';

export '../auth/auth_fakes.dart';

/// Signs Asha in (MPIN 2468) as [role] of "A Co" (`a`), optionally with a
/// co-owner and a collector, pumps the real app at [width] and unlocks.
/// [openSettings] then switches to the Settings tab.
Future<AuthHarness> pumpSettingsApp(
  WidgetTester tester, {
  double width = 400,
  double height = 1400,
  double textScale = 1,
  String role = 'owner',
  List<String> owners = const <String>[kAshaUid],
  List<String> otherMembers = const <String>[],
  bool biometricAvailable = false,
  bool openSettings = true,
  List<Override> extraOverrides = const <Override>[],
  bool withCompany = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final h = AuthHarness(
    signedIn: kAsha,
    biometricAvailable: biometricAvailable,
  );
  await tester.runAsync(() async {
    await h.mpin.setMpin(kAsha.uid, '2468');
    if (!withCompany) {
      await h.db.doc('users/${kAsha.uid}').set(<String, Object?>{
        'displayName': 'Asha Rao',
      });
      await h.db.doc('user_settings/${kAsha.uid}').set(<String, Object?>{
        'activeCompanyId': null,
      });
      return;
    }
    await OnboardingFixtures.company(
      h.db,
      cid: 'a',
      name: 'A Co',
      owners: owners,
    );
    await OnboardingFixtures.membership(
      h.db,
      uid: kAsha.uid,
      cid: 'a',
      name: 'A Co',
      role: role,
    );
    for (final uid in otherMembers) {
      await OnboardingFixtures.membership(
        h.db,
        uid: uid,
        cid: 'a',
        name: 'A Co',
        role: owners.contains(uid) ? 'owner' : 'collector',
      );
    }
    await h.db.doc('users/${kAsha.uid}').set(<String, Object?>{
      'displayName': 'Asha Rao',
      'email': 'asha@example.com',
    });
    await h.db.doc('user_settings/${kAsha.uid}').set(<String, Object?>{
      'activeCompanyId': 'a',
      'schemaVersion': 1,
    });
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[...h.overrides, ...extraOverrides],
      child: const App(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  for (final d in '2468'.split('')) {
    await tester.tap(find.byKey(ValueKey<String>('pin_key_$d')));
    await tester.pump();
  }
  await settle(tester);
  if (openSettings) {
    await tester.tap(find.text('Settings').last);
    await settle(tester);
  }
  return h;
}

const String kAshaUid = 'uid-asha';

Future<void> settle(WidgetTester tester, [int frames = 4]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Scrolls the Settings page until [key] is visible, then taps it.
Future<void> tapSetting(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settle(tester);
}
