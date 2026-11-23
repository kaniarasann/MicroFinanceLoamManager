import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_ledger/app.dart';
import 'package:nordic_ledger/core/routing/app_router.dart';
import 'package:nordic_ledger/features/auth/application/session_controller.dart';
import 'package:nordic_ledger/features/company/application/company_providers.dart';
import 'package:nordic_ledger/features/dashboard/presentation/screens/home_screen.dart';
import 'package:nordic_ledger/features/onboarding/application/onboarding_providers.dart';

import 'package:nordic_ledger/features/onboarding/presentation/screens/join_company_screen.dart';
import 'package:nordic_ledger/features/onboarding/presentation/screens/register_company_screen.dart';

import '../../features/auth/auth_fakes.dart';
import '../../features/onboarding/onboarding_test_support.dart';

String? go(
  String location, {
  AuthStage stage = AuthStage.unlocked,
  CompanyGate company = CompanyGate.ready,
  String? pending,
  bool dev = false,
}) => appRedirect(
  stage: stage,
  company: company,
  uri: Uri.parse(location),
  pendingInviteCode: pending,
  devRoutes: dev,
);

void main() {
  group('appRedirect company guard', () {
    test('no memberships → register; onboarding screens allowed', () {
      const none = CompanyGate.none;
      expect(go(AppRoutes.home, company: none), AppRoutes.onboardingRegister);
      expect(go(AppRoutes.mpin, company: none), AppRoutes.onboardingRegister);
      expect(go('/x', company: none), AppRoutes.onboardingRegister);
      expect(go(AppRoutes.onboardingRegister, company: none), isNull);
      expect(go(AppRoutes.onboardingJoin, company: none), isNull);
    });

    test('company loading → splash (onboarding stays put)', () {
      const loading = CompanyGate.loading;
      expect(go(AppRoutes.home, company: loading), AppRoutes.splash);
      expect(go(AppRoutes.mpin, company: loading), AppRoutes.splash);
      expect(go(AppRoutes.splash, company: loading), isNull);
      expect(go(AppRoutes.onboardingJoin, company: loading), isNull);
    });

    test('ready → home; onboarding reachable for join/register another', () {
      expect(go(AppRoutes.splash), AppRoutes.home);
      expect(go(AppRoutes.home), isNull);
      expect(go(AppRoutes.onboardingJoin), isNull);
      expect(go(AppRoutes.onboardingRegister), isNull);
    });

    test('/dev/gallery only with dev routes', () {
      expect(go(AppRoutes.devGallery), AppRoutes.home);
      expect(go(AppRoutes.devGallery, dev: true), isNull);
    });

    test('auth stages still win over the company guard', () {
      expect(
        go(AppRoutes.onboardingRegister, stage: AuthStage.locked),
        AppRoutes.mpin,
      );
      expect(
        go('/join?code=K7Q2MD', stage: AuthStage.signedOut),
        AppRoutes.signIn,
      );
    });

    test('join deep link pre-fills the code', () {
      for (final gate in CompanyGate.values) {
        expect(
          go('/join?code=k7q2md', company: gate),
          '/onboarding/join?code=K7Q2MD',
          reason: '$gate',
        );
      }
      expect(go('/join?code=BAD'), AppRoutes.onboardingJoin);
      expect(go('/join'), AppRoutes.onboardingJoin);
    });

    test('a pending code (locked deep link / referrer) opens join', () {
      expect(
        go(AppRoutes.mpin, company: CompanyGate.none, pending: 'K7Q2MD'),
        '/onboarding/join?code=K7Q2MD',
      );
      expect(
        go(AppRoutes.onboardingJoin, company: CompanyGate.none, pending: 'X'),
        isNull,
      );
    });
  });

  group('end to end', () {
    Future<(AuthHarness, ProviderContainer)> pumpUnlocked(
      WidgetTester tester, {
      Future<void> Function(AuthHarness h)? seed,
      String? referrer,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(tester.view.reset);
      final h = AuthHarness(signedIn: kAsha)..installReferrer = referrer;
      await tester.runAsync(() async {
        await h.mpin.setMpin(kAsha.uid, '2468');
        await seed?.call(h);
      });
      final container = ProviderContainer(overrides: h.overrides);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const App()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      for (final d in '2468'.split('')) {
        await tester.tap(find.byKey(ValueKey<String>('pin_key_$d')));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      return (h, container);
    }

    testWidgets('no memberships → register screen with a join link', (
      WidgetTester tester,
    ) async {
      await pumpUnlocked(tester);
      expect(find.byType(RegisterCompanyScreen), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('register_join_link')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('register_join_link')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(JoinCompanyScreen), findsOneWidget);
    });

    testWidgets('with a membership → home shows "{Company} ▾ · {Role}"', (
      WidgetTester tester,
    ) async {
      await pumpUnlocked(
        tester,
        seed: (AuthHarness h) async {
          await OnboardingFixtures.company(h.db, cid: 'a', name: 'A Co');
          await OnboardingFixtures.membership(
            h.db,
            uid: kAsha.uid,
            cid: 'a',
            name: 'A Co',
          );
        },
      );
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('A Co'), findsOneWidget);
      expect(find.text('· Owner'), findsOneWidget);
      expect(find.text('Dashboard coming in Sprint 7'), findsOneWidget);

      // Sprint 5: the Borrowers destination shows the borrower list.
      await tester.tap(find.text('Borrowers').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Add your first borrower'), findsOneWidget);
    });

    test('Sprint 5 borrower and contract routes stay in the shell', () {
      expect(go(AppRoutes.borrower('b-1')), isNull);
      expect(go(AppRoutes.newContract(borrowerId: 'b-1')), isNull);
      expect(go(AppRoutes.contract('c-1')), isNull);
      expect(go(AppRoutes.recordPayment('c-1')), isNull);
      expect(go('/borrowers'), AppRoutes.home);
      expect(
        go(AppRoutes.borrower('b-1'), company: CompanyGate.none),
        AppRoutes.onboardingRegister,
      );
      expect(
        AppRoutes.newContract(borrowerId: 'b 1'),
        '/contracts/new?borrowerId=b+1',
      );
      expect(AppRoutes.recordPayment('c1'), '/contracts/c1/pay');
    });

    testWidgets('join deep link pre-fills the code boxes', (
      WidgetTester tester,
    ) async {
      final (_, c) = await pumpUnlocked(tester);
      c.read(appRouterProvider).go('/join?code=k7q2md');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(JoinCompanyScreen), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('invite_code_field')),
      );
      expect(field.controller!.text, 'K7Q2MD');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Play install referrer code=… opens join pre-filled', (
      WidgetTester tester,
    ) async {
      final (_, c) = await pumpUnlocked(
        tester,
        referrer: 'utm_source=invite&code=K7Q2MD',
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(JoinCompanyScreen), findsOneWidget);
      expect(
        GoRouter.of(
          tester.element(find.byType(JoinCompanyScreen)),
        ).state.uri.queryParameters['code'],
        'K7Q2MD',
      );
      expect(c.read(pendingInviteCodeProvider), isNull, reason: 'consumed');
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
