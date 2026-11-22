import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/features/auth/application/lock_controller.dart';
import 'package:nordic_ledger/features/auth/application/session_controller.dart';

import 'auth_fakes.dart';

/// Subscribes to the session (so the auth stream runs) and lets the stream
/// and secure-storage futures settle.
Future<SessionController> start(ProviderContainer c) async {
  c.listen(sessionControllerProvider, (_, _) {});
  await pumpEventQueue();
  return c.read(sessionControllerProvider.notifier);
}

AuthStage stageOf(ProviderContainer c) =>
    c.read(sessionControllerProvider).stage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts in loading before the auth stream reports', () {
    final c = AuthHarness().container();
    expect(stageOf(c), AuthStage.loading);
  });

  test('signedOut → needsMpinSetup → unlocked', () async {
    final h = AuthHarness();
    final c = h.container();
    final session = await start(c);
    expect(stageOf(c), AuthStage.signedOut);

    await session.signInWithGoogle();
    await pumpEventQueue();
    expect(stageOf(c), AuthStage.needsMpinSetup);
    expect(c.read(sessionControllerProvider).user?.uid, kAsha.uid);

    await session.completeMpinSetup('1234', biometricEnabled: true);
    final s = c.read(sessionControllerProvider);
    expect(s.stage, AuthStage.unlocked);
    expect(s.biometricEnabled, isTrue);
    expect(await h.mpin.hasMpin(kAsha.uid), isTrue);
    expect(await h.mpin.biometricEnabled(kAsha.uid), isTrue);
  });

  test('cancelled sign-in is a quiet no-op', () async {
    final h = AuthHarness()..repo.nextSignIn = null;
    final c = h.container();
    final session = await start(c);
    await session.signInWithGoogle();
    await pumpEventQueue();
    expect(stageOf(c), AuthStage.signedOut);
    expect(c.read(sessionControllerProvider).message, isNull);
  });

  test('failed sign-in sets a user message', () async {
    final h = AuthHarness()
      ..repo.signInFailure = const AppFailure.offlineRequired();
    final c = h.container();
    final session = await start(c);
    await session.signInWithGoogle();
    final s = c.read(sessionControllerProvider);
    expect(s.stage, AuthStage.signedOut);
    expect(s.message, const OfflineRequiredFailure().userMessage);
  });

  test('cold start with an MPIN → locked; right PIN → unlocked', () async {
    final h = AuthHarness(signedIn: kAsha);
    await h.mpin.setMpin(kAsha.uid, '2468');
    final c = h.container();
    final session = await start(c);
    expect(stageOf(c), AuthStage.locked);

    final wrong = await session.unlockWithPin('1111');
    expect(wrong.ok, isFalse);
    expect(wrong.remaining, 4);
    expect(stageOf(c), AuthStage.locked);

    final right = await session.unlockWithPin('2468');
    expect(right.ok, isTrue);
    expect(stageOf(c), AuthStage.unlocked);
  });

  test('cold start without an MPIN on this device → needsMpinSetup', () async {
    final c = AuthHarness(signedIn: kAsha).container();
    await start(c);
    expect(stageOf(c), AuthStage.needsMpinSetup);
  });

  test(
    'lockout after 5 wrong PINs → signedOut with message, MPIN wiped',
    () async {
      final h = AuthHarness(signedIn: kAsha);
      await h.mpin.setMpin(kAsha.uid, '2468');
      final c = h.container();
      final session = await start(c);

      for (var i = 0; i < 4; i++) {
        final r = await session.unlockWithPin('0000');
        expect(r.lockedOut, isFalse);
      }
      final last = await session.unlockWithPin('0000');
      await pumpEventQueue();

      expect(last.lockedOut, isTrue);
      final s = c.read(sessionControllerProvider);
      expect(s.stage, AuthStage.signedOut);
      expect(s.message, kLockoutMessage);
      expect(h.repo.signOutCalls, 1);
      expect(h.repo.currentUser, isNull);
      expect(await h.mpin.hasMpin(kAsha.uid), isFalse);

      // Signing in again forces a new MPIN.
      await session.signInWithGoogle();
      await pumpEventQueue();
      expect(stageOf(c), AuthStage.needsMpinSetup);
      expect(c.read(sessionControllerProvider).message, isNull);
    },
  );

  test(
    'forgot MPIN → Google re-auth → MPIN cleared → needsMpinSetup',
    () async {
      final h = AuthHarness(signedIn: kAsha);
      await h.mpin.setMpin(kAsha.uid, '2468');
      final c = h.container();
      final session = await start(c);

      await session.forgotMpin();
      expect(h.repo.reauthCalls, 1);
      expect(stageOf(c), AuthStage.needsMpinSetup);
      expect(await h.mpin.hasMpin(kAsha.uid), isFalse);
      expect(h.repo.signOutCalls, 0);
    },
  );

  test('forgot MPIN cancelled keeps the lock and the MPIN', () async {
    final h = AuthHarness(signedIn: kAsha)..repo.reauthResult = false;
    await h.mpin.setMpin(kAsha.uid, '2468');
    final c = h.container();
    final session = await start(c);

    await session.forgotMpin();
    expect(stageOf(c), AuthStage.locked);
    expect(await h.mpin.hasMpin(kAsha.uid), isTrue);
  });

  test('forgot MPIN with the wrong Google account shows a message', () async {
    final h = AuthHarness(signedIn: kAsha)
      ..repo.reauthFailure = const AppFailure.validation('account', 'Same');
    await h.mpin.setMpin(kAsha.uid, '2468');
    final c = h.container();
    final session = await start(c);

    await session.forgotMpin();
    expect(stageOf(c), AuthStage.locked);
    expect(c.read(sessionControllerProvider).message, 'Same');
    expect(await h.mpin.hasMpin(kAsha.uid), isTrue);
  });

  test('biometric unlock when enabled; resets the failure counter', () async {
    final h = AuthHarness(signedIn: kAsha, biometricAvailable: true);
    await h.mpin.setMpin(kAsha.uid, '2468');
    await h.mpin.setBiometricEnabled(kAsha.uid, enabled: true);
    final c = h.container();
    final session = await start(c);
    expect(c.read(sessionControllerProvider).biometricEnabled, isTrue);

    await session.unlockWithPin('0000');
    expect(await session.unlockWithBiometric(), isTrue);
    expect(stageOf(c), AuthStage.unlocked);
    expect(await h.mpin.failedAttempts(kAsha.uid), 0);
  });

  test('biometric is ignored when not enabled or when it fails', () async {
    final h = AuthHarness(signedIn: kAsha, biometricAvailable: true);
    await h.mpin.setMpin(kAsha.uid, '2468');
    final c = h.container();
    final session = await start(c);
    expect(await session.unlockWithBiometric(), isFalse);
    expect(h.biometric.authCalls, 0);

    await h.mpin.setBiometricEnabled(kAsha.uid, enabled: true);
    h.biometric.result = false;
    final c2 = h.container();
    final session2 = await start(c2);
    expect(await session2.unlockWithBiometric(), isFalse);
    expect(stageOf(c2), AuthStage.locked);
  });

  test('signOut → signedOut', () async {
    final h = AuthHarness(signedIn: kAsha);
    final c = h.container();
    final session = await start(c);
    await session.signOut();
    await pumpEventQueue();
    expect(stageOf(c), AuthStage.signedOut);
    expect(h.repo.signOutCalls, 1);
  });

  group('auto-lock', () {
    Future<(AuthHarness, ProviderContainer)> unlocked({int? minutes}) async {
      final h = AuthHarness(signedIn: kAsha);
      await h.mpin.setMpin(kAsha.uid, '2468');
      if (minutes != null) await h.mpin.setAutoLockMinutes(kAsha.uid, minutes);
      final c = h.container();
      final session = await start(c);
      c.listen(lockControllerProvider, (_, _) {});
      await session.unlockWithPin('2468');
      expect(stageOf(c), AuthStage.unlocked);
      return (h, c);
    }

    test('background longer than autoLockMinutes (1) → locked', () async {
      final (h, c) = await unlocked();
      final lock = c.read(lockControllerProvider.notifier);
      lock.onBackgrounded();
      h.clock.now = h.clock.now.add(const Duration(minutes: 2));
      await lock.onResumed();
      expect(stageOf(c), AuthStage.locked);
    });

    test('short background stays unlocked', () async {
      final (h, c) = await unlocked();
      final lock = c.read(lockControllerProvider.notifier);
      lock.onBackgrounded();
      h.clock.now = h.clock.now.add(const Duration(seconds: 30));
      await lock.onResumed();
      expect(stageOf(c), AuthStage.unlocked);
    });

    test('respects a longer autoLockMinutes', () async {
      final (h, c) = await unlocked(minutes: 5);
      final lock = c.read(lockControllerProvider.notifier);
      lock.onBackgrounded();
      h.clock.now = h.clock.now.add(const Duration(minutes: 3));
      await lock.onResumed();
      expect(stageOf(c), AuthStage.unlocked);

      lock.onBackgrounded();
      h.clock.now = h.clock.now.add(const Duration(minutes: 6));
      await lock.onResumed();
      expect(stageOf(c), AuthStage.locked);
    });

    test('first background event wins (hidden then paused)', () async {
      final (h, c) = await unlocked();
      final lock = c.read(lockControllerProvider.notifier);
      lock.onBackgrounded();
      final first = c.read(lockControllerProvider);
      h.clock.now = h.clock.now.add(const Duration(seconds: 5));
      lock.onBackgrounded();
      expect(c.read(lockControllerProvider), first);
    });

    test('driven by real app lifecycle events', () async {
      final (h, c) = await unlocked();
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(c.read(lockControllerProvider), isNotNull);
      h.clock.now = h.clock.now.add(const Duration(minutes: 2));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(stageOf(c), AuthStage.locked);
    });

    test('lock() is a no-op unless unlocked', () async {
      final h = AuthHarness();
      final c = h.container();
      final session = await start(c);
      session.lock();
      expect(stageOf(c), AuthStage.signedOut);
    });
  });
}
