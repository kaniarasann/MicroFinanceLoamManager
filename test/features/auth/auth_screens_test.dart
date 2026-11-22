import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/core/widgets/brand_mark.dart';
import 'package:nordic_ledger/core/widgets/pin_pad.dart';
import 'package:nordic_ledger/features/auth/application/session_controller.dart';
import 'package:nordic_ledger/features/auth/presentation/screens/mpin_setup_screen.dart';
import 'package:nordic_ledger/features/auth/presentation/screens/mpin_unlock_screen.dart';
import 'package:nordic_ledger/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:nordic_ledger/features/auth/presentation/widgets/google_g_mark.dart';
import 'package:nordic_ledger/features/splash/presentation/splash_screen.dart';

import 'auth_fakes.dart';

/// Pumps [screen] with a live session container and lets the auth stream
/// settle. Returns the container.
Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  AuthHarness h,
  Widget screen, {
  double width = 400,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  final container = h.container();
  container.listen(sessionControllerProvider, (_, _) {});
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light, home: screen),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.byKey(ValueKey<String>('pin_key_$d')));
    await tester.pump();
  }
  // Let the async verify + shake run.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('Splash', () {
    testWidgets('brand tile, wordmark, tagline and sync bar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const SplashScreen()),
      );
      expect(find.text('Nordic Ledger'), findsOneWidget);
      expect(find.text('Calm, accurate lending books'), findsOneWidget);
      expect(find.text('Syncing your ledger…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final mark = tester.getSize(find.byType(BrandMark));
      expect(mark, const Size(AppSizes.brandTileLg, AppSizes.brandTileLg));
    });
  });

  group('Sign-in', () {
    for (final width in <double>[360, 1024]) {
      testWidgets('renders at width $width, content capped at 420', (
        WidgetTester tester,
      ) async {
        final h = AuthHarness();
        await pumpScreen(tester, h, const SignInScreen(), width: width);

        expect(find.text('Nordic Ledger'), findsOneWidget);
        expect(find.text('Lending ledger for your business'), findsOneWidget);
        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.byType(GoogleGMark), findsOneWidget);
        expect(find.text('Your MPIN stays on this device'), findsOneWidget);
        expect(find.text('Privacy'), findsOneWidget);
        expect(find.text('Terms'), findsOneWidget);

        final button = tester.getRect(
          find.byKey(const ValueKey<String>('google_sign_in')),
        );
        expect(button.width, lessThanOrEqualTo(AppSizes.authContentMaxWidth));
        // Centred.
        expect(button.center.dx, closeTo(width / 2, 1));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tapping Continue signs in', (WidgetTester tester) async {
      final h = AuthHarness();
      final c = await pumpScreen(tester, h, const SignInScreen());
      await tester.tap(find.byKey(const ValueKey<String>('google_sign_in')));
      await tester.pump();
      await tester.pump();
      expect(h.repo.signInCalls, 1);
      expect(c.read(sessionControllerProvider).stage, AuthStage.needsMpinSetup);
    });

    testWidgets('shows an inline error on failure', (
      WidgetTester tester,
    ) async {
      final h = AuthHarness()
        ..repo.signInFailure = const AppFailure.offlineRequired();
      await pumpScreen(tester, h, const SignInScreen());
      await tester.tap(find.byKey(const ValueKey<String>('google_sign_in')));
      await tester.pump();
      await tester.pump();
      expect(
        find.text(const OfflineRequiredFailure().userMessage),
        findsOneWidget,
      );
    });

    testWidgets('shows the lockout notice', (WidgetTester tester) async {
      final h = AuthHarness(signedIn: kAsha);
      await tester.runAsync(() => h.mpin.setMpin(kAsha.uid, '2468'));
      final c = await pumpScreen(tester, h, const SignInScreen());
      final session = c.read(sessionControllerProvider.notifier);
      for (var i = 0; i < 5; i++) {
        await session.unlockWithPin('0000');
      }
      await tester.pump();
      expect(find.text(kLockoutMessage), findsOneWidget);
    });
  });

  group('MPIN setup', () {
    testWidgets('mismatch shows an error and restarts', (
      WidgetTester tester,
    ) async {
      final h = AuthHarness(signedIn: kAsha);
      final c = await pumpScreen(tester, h, const MpinSetupScreen());
      expect(find.text('Create your 4-digit MPIN'), findsOneWidget);

      await enterPin(tester, '1234');
      expect(find.text('Confirm MPIN'), findsOneWidget);

      await enterPin(tester, '9876');
      expect(find.text(MpinSetupScreen.mismatchMessage), findsOneWidget);
      expect(find.text('Create your 4-digit MPIN'), findsOneWidget);
      expect(c.read(sessionControllerProvider).stage, AuthStage.needsMpinSetup);

      await enterPin(tester, '1234');
      await enterPin(tester, '1234');
      expect(c.read(sessionControllerProvider).stage, AuthStage.unlocked);
      expect(
        await tester.runAsync(() => h.mpin.biometricEnabled(kAsha.uid)),
        isFalse,
      );
    });

    testWidgets('no fingerprint question when biometrics are unavailable', (
      WidgetTester tester,
    ) async {
      final h = AuthHarness(signedIn: kAsha);
      final c = await pumpScreen(tester, h, const MpinSetupScreen());
      await enterPin(tester, '4321');
      await enterPin(tester, '4321');
      expect(find.text('Use fingerprint to unlock?'), findsNothing);
      expect(c.read(sessionControllerProvider).stage, AuthStage.unlocked);
    });

    testWidgets('asks about fingerprint when available and stores it', (
      WidgetTester tester,
    ) async {
      final h = AuthHarness(signedIn: kAsha, biometricAvailable: true);
      final c = await pumpScreen(tester, h, const MpinSetupScreen());
      await enterPin(tester, '4321');
      await enterPin(tester, '4321');
      expect(find.text('Use fingerprint to unlock?'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('biometric_enable')));
      await tester.pump();
      await tester.pump();
      expect(h.biometric.authCalls, 1);
      final s = c.read(sessionControllerProvider);
      expect(s.stage, AuthStage.unlocked);
      expect(s.biometricEnabled, isTrue);
    });

    testWidgets('"Not now" stores biometric off', (WidgetTester tester) async {
      final h = AuthHarness(signedIn: kAsha, biometricAvailable: true);
      final c = await pumpScreen(tester, h, const MpinSetupScreen());
      await enterPin(tester, '4321');
      await enterPin(tester, '4321');
      await tester.tap(find.byKey(const ValueKey<String>('biometric_skip')));
      await tester.pump();
      await tester.pump();
      final s = c.read(sessionControllerProvider);
      expect(s.stage, AuthStage.unlocked);
      expect(s.biometricEnabled, isFalse);
      expect(h.biometric.authCalls, 0);
    });
  });

  group('MPIN unlock', () {
    Future<ProviderContainer> locked(
      WidgetTester tester, {
      bool biometric = false,
      double width = 400,
    }) async {
      final h = AuthHarness(signedIn: kAsha, biometricAvailable: biometric);
      await tester.runAsync(() async {
        await h.mpin.setMpin(kAsha.uid, '2468');
        await h.mpin.setBiometricEnabled(kAsha.uid, enabled: biometric);
      });
      _lastHarness = h;
      final c = await pumpScreen(
        tester,
        h,
        const MpinUnlockScreen(),
        width: width,
      );
      if (!biometric) {
        expect(c.read(sessionControllerProvider).stage, AuthStage.locked);
      }
      return c;
    }

    testWidgets('greets by first name with the device-only note', (
      WidgetTester tester,
    ) async {
      await locked(tester);
      expect(find.text('Welcome back, Asha'), findsOneWidget);
      expect(find.text('Lending ledger for your business'), findsOneWidget);
      expect(
        find.text('Forgot MPIN? Sign in with Google again'),
        findsOneWidget,
      );
      expect(find.text('Your MPIN stays on this device'), findsOneWidget);
      // No biometric key unless enabled.
      expect(find.byKey(const ValueKey<String>('pin_biometric')), findsNothing);
    });

    testWidgets('wrong PIN shows tries left in terracotta', (
      WidgetTester tester,
    ) async {
      await locked(tester);
      await enterPin(tester, '1111');
      final finder = find.text('Wrong MPIN · 4 tries left');
      expect(finder, findsOneWidget);
      expect(tester.widget<Text>(finder).style?.color, AppColors.overdue);

      await enterPin(tester, '1111');
      await enterPin(tester, '1111');
      await enterPin(tester, '1111');
      expect(find.text('Wrong MPIN · 1 try left'), findsOneWidget);
    });

    testWidgets('right PIN unlocks', (WidgetTester tester) async {
      final c = await locked(tester);
      await enterPin(tester, '2468');
      expect(c.read(sessionControllerProvider).stage, AuthStage.unlocked);
    });

    testWidgets('5th wrong PIN signs out', (WidgetTester tester) async {
      final c = await locked(tester);
      for (var i = 0; i < 5; i++) {
        await enterPin(tester, '1111');
      }
      final s = c.read(sessionControllerProvider);
      expect(s.stage, AuthStage.signedOut);
      expect(s.message, kLockoutMessage);
    });

    testWidgets('auto-prompts biometric on open and shows the key', (
      WidgetTester tester,
    ) async {
      final c = await locked(tester, biometric: true);
      await tester.pump();
      await tester.pump();
      expect(_lastHarness.biometric.authCalls, 1);
      expect(c.read(sessionControllerProvider).stage, AuthStage.unlocked);
    });

    testWidgets('biometric key retries after a failed prompt', (
      WidgetTester tester,
    ) async {
      final h = AuthHarness(signedIn: kAsha, biometricAvailable: true);
      h.biometric.result = false;
      await tester.runAsync(() async {
        await h.mpin.setMpin(kAsha.uid, '2468');
        await h.mpin.setBiometricEnabled(kAsha.uid, enabled: true);
      });
      final c = await pumpScreen(tester, h, const MpinUnlockScreen());
      await tester.pump();
      expect(h.biometric.authCalls, 1);
      expect(c.read(sessionControllerProvider).stage, AuthStage.locked);

      h.biometric.result = true;
      await tester.tap(find.byKey(const ValueKey<String>('pin_biometric')));
      await tester.pump();
      await tester.pump();
      expect(h.biometric.authCalls, 2);
      expect(c.read(sessionControllerProvider).stage, AuthStage.unlocked);
    });

    testWidgets('Forgot MPIN re-auths and goes to setup', (
      WidgetTester tester,
    ) async {
      final c = await locked(tester);
      await tester.tap(find.byKey(const ValueKey<String>('forgot_mpin')));
      await tester.pump();
      await tester.pump();
      expect(_lastHarness.repo.reauthCalls, 1);
      expect(c.read(sessionControllerProvider).stage, AuthStage.needsMpinSetup);
    });

    testWidgets('expanded width keeps the pad centred and capped', (
      WidgetTester tester,
    ) async {
      await locked(tester, width: 1024);
      final content = tester.getRect(
        find.byKey(const ValueKey<String>('auth_content')),
      );
      expect(content.width, lessThanOrEqualTo(AppSizes.authContentMaxWidth));
      expect(tester.getCenter(find.byType(PinPad)).dx, closeTo(1024 / 2, 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives 1.3x text scale on a small phone', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await locked(tester, width: 320);
      expect(tester.takeException(), isNull);
    });
  });
}

late AuthHarness _lastHarness;
