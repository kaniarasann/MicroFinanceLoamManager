import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/routing/app_router.dart';
import 'package:nordic_ledger/features/auth/application/lock_controller.dart';
import 'package:nordic_ledger/features/auth/application/session_controller.dart';

import '../auth_fakes.dart';

AuthStage stageOf(ProviderContainer c) =>
    c.read(sessionControllerProvider).stage;

Future<(AuthHarness, ProviderContainer)> unlocked({int? minutes}) async {
  final h = AuthHarness(signedIn: kAsha);
  await h.mpin.setMpin(kAsha.uid, '2468');
  if (minutes != null) await h.mpin.setAutoLockMinutes(kAsha.uid, minutes);
  final c = h.container();
  c.listen(sessionControllerProvider, (_, _) {});
  await pumpEventQueue();
  c.listen(lockControllerProvider, (_, _) {});
  await c.read(sessionControllerProvider.notifier).unlockWithPin('2468');
  expect(stageOf(c), AuthStage.unlocked);
  return (h, c);
}

Future<AuthStage> awayFor(Duration d, {int? minutes}) async {
  final (h, c) = await unlocked(minutes: minutes);
  final lock = c.read(lockControllerProvider.notifier);
  lock.onBackgrounded();
  h.clock.now = h.clock.now.add(d);
  await lock.onResumed();
  return stageOf(c);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('auto-lock threshold (default 1 min)', () {
    test('59.999 s away stays unlocked', () async {
      expect(
        await awayFor(const Duration(seconds: 59, milliseconds: 999)),
        AuthStage.unlocked,
      );
    });
    test('exactly 60 s away locks', () async {
      expect(await awayFor(const Duration(minutes: 1)), AuthStage.locked);
    });
    test('61 s away locks', () async {
      expect(await awayFor(const Duration(seconds: 61)), AuthStage.locked);
    });
    test('5 min setting: 4:59 unlocked, 5:01 locked', () async {
      expect(
        await awayFor(const Duration(minutes: 4, seconds: 59), minutes: 5),
        AuthStage.unlocked,
      );
      expect(
        await awayFor(const Duration(minutes: 5, seconds: 1), minutes: 5),
        AuthStage.locked,
      );
    });
    test('repeated background events keep the first timestamp', () async {
      final (h, c) = await unlocked();
      final lock = c.read(lockControllerProvider.notifier);
      lock.onBackgrounded(); // hidden
      h.clock.now = h.clock.now.add(const Duration(seconds: 40));
      lock.onBackgrounded(); // paused
      h.clock.now = h.clock.now.add(const Duration(seconds: 30));
      await lock.onResumed();
      expect(stageOf(c), AuthStage.locked);
    });
    test('resume without background is a no-op', () async {
      final (_, c) = await unlocked();
      await c.read(lockControllerProvider.notifier).onResumed();
      expect(stageOf(c), AuthStage.unlocked);
    });
  });

  group('router redirects', () {
    test('unlocked user cannot open /sign-in, /mpin, /mpin/setup, /splash', () {
      for (final loc in <String>[
        '/sign-in',
        '/mpin',
        '/mpin/setup',
        '/splash',
      ]) {
        expect(authRedirect(AuthStage.unlocked, loc), '/home', reason: loc);
      }
    });
    test('unlocked user on /home is not redirected', () {
      expect(authRedirect(AuthStage.unlocked, '/home'), isNull);
    });
    test('unlocked user on an unknown path goes to /home', () {
      expect(authRedirect(AuthStage.unlocked, '/nope/../admin'), '/home');
    });
    test('signed-out user cannot open /home or /mpin', () {
      expect(authRedirect(AuthStage.signedOut, '/home'), '/sign-in');
      expect(authRedirect(AuthStage.signedOut, '/mpin'), '/sign-in');
      expect(authRedirect(AuthStage.signedOut, '/sign-in'), isNull);
    });
    test('locked user cannot open /home; setup user cannot skip setup', () {
      expect(authRedirect(AuthStage.locked, '/home'), '/mpin');
      expect(authRedirect(AuthStage.needsMpinSetup, '/home'), '/mpin/setup');
      expect(authRedirect(AuthStage.loading, '/home'), '/splash');
    });
  });
}
