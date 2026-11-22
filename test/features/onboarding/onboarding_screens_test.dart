import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_ledger/core/phone/indian_phone.dart';
import 'package:nordic_ledger/core/routing/app_router.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/features/auth/application/session_controller.dart';
import 'package:nordic_ledger/features/onboarding/presentation/screens/join_company_screen.dart';
import 'package:nordic_ledger/features/onboarding/presentation/screens/register_company_screen.dart';

import '../auth/auth_fakes.dart';
import 'onboarding_test_support.dart';

const Key _submit = ValueKey<String>('register_submit');
const Key _codeField = ValueKey<String>('invite_code_field');

/// Pumps [initial] inside a minimal router (register, join, home stub).
Future<AuthHarness> pumpOnboarding(
  WidgetTester tester, {
  required String initial,
  required double width,
  Future<void> Function(AuthHarness h)? seed,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  final h = AuthHarness(signedIn: kAsha);
  if (seed != null) await tester.runAsync(() => seed(h));
  final router = GoRouter(
    initialLocation: initial,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.onboardingRegister,
        builder: (_, _) => const RegisterCompanyScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingJoin,
        builder: (_, GoRouterState s) =>
            JoinCompanyScreen(initialCode: s.uri.queryParameters['code']),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = h.container()..listen(sessionControllerProvider, (_, _) {});
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
  return h;
}

Future<void> tapSubmit(WidgetTester tester) async {
  await tester.tap(find.byKey(_submit));
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final width in <double>[400, 1200]) {
    group('Register company @${width.toInt()}', () {
      testWidgets('renders the cards, owner rights and prefilled name', (
        WidgetTester tester,
      ) async {
        await pumpOnboarding(
          tester,
          initial: AppRoutes.onboardingRegister,
          width: width,
        );
        expect(find.text('Register your company'), findsOneWidget);
        expect(find.text('Company details'), findsOneWidget);
        expect(find.text('Your profile'), findsOneWidget);
        expect(
          find.text('Create loans, rollovers and manage the ledger'),
          findsOneWidget,
        );
        expect(find.textContaining('interest accruals'), findsNothing);
        expect(find.text('Create company & continue'), findsOneWidget);
        expect(find.text('Asha Rao'), findsWidgets); // display name prefill
        expect(find.byKey(const ValueKey<String>('account_chip')), findsOne);
        expect(tester.takeException(), isNull);
      });

      testWidgets('empty name, 1-char name and bad phone are rejected', (
        WidgetTester tester,
      ) async {
        final h = await pumpOnboarding(
          tester,
          initial: AppRoutes.onboardingRegister,
          width: width,
        );
        await tapSubmit(tester);
        expect(find.text('Enter your company name.'), findsOneWidget);
        expect(find.text('Enter a mobile number.'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey<String>('register_name')),
          'A',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('register_mobile')),
          '12345',
        );
        await tapSubmit(tester);
        expect(
          find.text('Company name must be at least 2 characters.'),
          findsOneWidget,
        );
        expect(find.text(IndianPhone.invalidMessage), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey<String>('register_phone')),
          '5555555555',
        );
        await tapSubmit(tester);
        expect(find.text(IndianPhone.invalidMessage), findsNWidgets(2));

        final companies = await tester.runAsync(
          () => h.db.collection('companies').get(),
        );
        expect(companies!.docs, isEmpty);
      });

      testWidgets('valid form creates the company and goes home', (
        WidgetTester tester,
      ) async {
        final h = await pumpOnboarding(
          tester,
          initial: AppRoutes.onboardingRegister,
          width: width,
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('register_name')),
          'Sri Lakshmi Finance',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('register_mobile')),
          '9845012890',
        );
        final mobile = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('register_mobile')),
            matching: find.byType(EditableText),
          ),
        );
        expect(mobile.controller.text, '98450 12890');
        await tapSubmit(tester);
        await tester.pumpAndSettle();
        expect(find.text('HOME'), findsOneWidget);
        final companies = await tester.runAsync(
          () => h.db.collection('companies').get(),
        );
        expect(companies!.docs.single.data()['name'], 'Sri Lakshmi Finance');
      });
    });

    group('Join with code @${width.toInt()}', () {
      final expires = DateTime.utc(2026, 11, 27, 4, 30);

      Future<AuthHarness> pumpJoin(
        WidgetTester tester, {
        String role = 'collector',
        String status = 'pending',
        DateTime? expiresAt,
      }) => pumpOnboarding(
        tester,
        initial: AppRoutes.onboardingJoin,
        width: width,
        seed: (AuthHarness h) async {
          await OnboardingFixtures.company(h.db);
          await OnboardingFixtures.invite(
            h.db,
            role: role,
            status: status,
            expiresAt: expiresAt ?? expires,
          );
        },
      );

      Future<void> typeCode(WidgetTester tester, String code) async {
        await tester.enterText(find.byKey(_codeField), code);
        await tester.pump();
        await tester.pump();
        await tester.pump();
      }

      testWidgets('typing uppercases into 6 boxes and shows the preview', (
        WidgetTester tester,
      ) async {
        await pumpJoin(tester);
        await typeCode(tester, 'k7q-2md');
        for (final (i, ch) in 'K7Q2MD'.split('').indexed) {
          expect(
            find.descendant(
              of: find.byKey(ValueKey<String>('invite_code_box_$i')),
              matching: find.text(ch),
            ),
            findsOneWidget,
          );
        }
        expect(find.byKey(const ValueKey<String>('invite_preview')), findsOne);
        expect(find.text('Sri Lakshmi Finance'), findsOneWidget);
        expect(find.text('SL'), findsOneWidget);
        expect(find.text('Chennai'), findsOneWidget);
        expect(find.text('Invited by Ravi Kumar (Owner)'), findsOneWidget);
        expect(find.text('Collector'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
        expect(find.textContaining('Expires 27 Nov, 10:00 am'), findsOne);
        expect(find.text('Join Sri Lakshmi Finance'), findsOneWidget);
        expect(
          find.text('An internet connection is needed to join.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('owner invite says Full access', (WidgetTester tester) async {
        await pumpJoin(tester, role: 'owner');
        await typeCode(tester, 'K7Q2MD');
        expect(find.text('Full access'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsNothing);
      });

      testWidgets('invalid characters are explained', (
        WidgetTester tester,
      ) async {
        await pumpJoin(tester);
        await typeCode(tester, 'K7Q2M0');
        expect(find.text(JoinCopy.invalidChars), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('invite_preview')),
          findsNothing,
        );
      });

      testWidgets('unknown code shows not found', (WidgetTester tester) async {
        await pumpJoin(tester);
        await typeCode(tester, 'ZZZZZZ');
        expect(find.text(JoinCopy.notFound), findsOneWidget);
      });

      testWidgets('expired code', (WidgetTester tester) async {
        await pumpJoin(tester, expiresAt: DateTime.utc(2026, 11, 1));
        await typeCode(tester, 'K7Q2MD');
        expect(find.text(JoinCopy.expired), findsOneWidget);
      });

      testWidgets('used code', (WidgetTester tester) async {
        await pumpJoin(tester, status: 'accepted');
        await typeCode(tester, 'K7Q2MD');
        expect(find.text(JoinCopy.unavailable), findsOneWidget);
      });

      testWidgets('paste from clipboard extracts the code from a message', (
        WidgetTester tester,
      ) async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'Clipboard.getData') {
              return <String, Object?>{
                'text':
                    'Join *Sri Lakshmi Finance* on Nordic Ledger as Collector.'
                    ' Invite code: k7q2md',
              };
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await pumpJoin(tester);
        await tester.tap(find.byKey(const ValueKey<String>('join_paste')));
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(find.text('K'), findsOneWidget);
        expect(find.text('Join Sri Lakshmi Finance'), findsOneWidget);
      });

      testWidgets('join accepts the invite and goes home', (
        WidgetTester tester,
      ) async {
        final h = await pumpJoin(tester);
        await typeCode(tester, 'K7Q2MD');
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('join_submit')),
        );
        await tester.tap(find.byKey(const ValueKey<String>('join_submit')));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('HOME'), findsOneWidget);
        final invite = await tester.runAsync(
          () => h.db.doc('invites/K7Q2MD').get(),
        );
        expect(invite!.data()!['status'], 'accepted');
      });

      testWidgets('route code pre-fills the boxes', (
        WidgetTester tester,
      ) async {
        await pumpOnboarding(
          tester,
          initial: '${AppRoutes.onboardingJoin}?code=K7Q2MD',
          width: width,
          seed: (AuthHarness h) =>
              OnboardingFixtures.invite(h.db, expiresAt: expires),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('Join Sri Lakshmi Finance'), findsOneWidget);
      });
    });
  }
}
