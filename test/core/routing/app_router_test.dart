import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/app.dart';
import 'package:nordic_ledger/core/routing/app_router.dart';
import 'package:nordic_ledger/features/auth/application/session_controller.dart';
import 'package:nordic_ledger/features/auth/presentation/screens/mpin_setup_screen.dart';
import 'package:nordic_ledger/features/auth/presentation/screens/mpin_unlock_screen.dart';
import 'package:nordic_ledger/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:nordic_ledger/features/splash/presentation/splash_screen.dart';
import 'package:nordic_ledger/features/onboarding/presentation/screens/register_company_screen.dart';

import '../../features/auth/auth_fakes.dart';

void main() {
  group('authRedirect', () {
    const everywhere = <String>[
      AppRoutes.splash,
      AppRoutes.signIn,
      AppRoutes.mpinSetup,
      AppRoutes.mpin,
      AppRoutes.home,
      '/',
      '/unknown',
    ];

    final expected = <AuthStage, String>{
      AuthStage.loading: AppRoutes.splash,
      AuthStage.signedOut: AppRoutes.signIn,
      AuthStage.needsMpinSetup: AppRoutes.mpinSetup,
      AuthStage.locked: AppRoutes.mpin,
    };

    expected.forEach((AuthStage stage, String target) {
      test('$stage pins every location to $target', () {
        for (final location in everywhere) {
          expect(
            authRedirect(stage, location),
            location == target ? isNull : target,
            reason: 'from $location',
          );
        }
      });
    });

    test('unlocked leaves the gate screens for /home', () {
      for (final gate in AppRoutes.gate) {
        expect(authRedirect(AuthStage.unlocked, gate), AppRoutes.home);
      }
      expect(authRedirect(AuthStage.unlocked, '/'), AppRoutes.home);
      expect(authRedirect(AuthStage.unlocked, '/nope'), AppRoutes.home);
      expect(authRedirect(AuthStage.unlocked, AppRoutes.home), isNull);
    });
  });

  group('App routing end to end', () {
    Future<void> pumpApp(WidgetTester tester, AuthHarness h) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(overrides: h.overrides, child: const App()),
      );
    }

    testWidgets('loading shows the splash, then sign-in when signed out', (
      WidgetTester tester,
    ) async {
      final h = AuthHarness();
      await pumpApp(tester, h);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Syncing your ledger…'), findsOneWidget);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('sign-in → MPIN setup → register company', (
      WidgetTester tester,
    ) async {
      final h = AuthHarness();
      await pumpApp(tester, h);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const ValueKey<String>('google_sign_in')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MpinSetupScreen), findsOneWidget);

      Future<void> enter(String pin) async {
        for (final d in pin.split('')) {
          await tester.tap(find.byKey(ValueKey<String>('pin_key_$d')));
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 500));
      }

      await enter('1357');
      await enter('1357');
      await tester.pump(const Duration(milliseconds: 500));
      // No membership yet: the company guard sends them to register.
      expect(find.byType(RegisterCompanyScreen), findsOneWidget);
    });

    testWidgets('cold start with an MPIN shows the lock screen', (
      WidgetTester tester,
    ) async {
      final h = AuthHarness(signedIn: kAsha);
      await tester.runAsync(() => h.mpin.setMpin(kAsha.uid, '2468'));
      await pumpApp(tester, h);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MpinUnlockScreen), findsOneWidget);
      expect(find.text('Welcome back, Asha'), findsOneWidget);
    });
  });
}
