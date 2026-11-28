// Tester — Sprint 8: notification scheduler + deep links.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/app.dart';
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/core/firebase/firebase_providers.dart';
import 'package:nordic_ledger/core/routing/app_router.dart';
import 'package:nordic_ledger/core/time/clock_provider.dart';
import 'package:nordic_ledger/core/time/ist_clock.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/auth/application/auth_providers.dart';
import 'package:nordic_ledger/features/auth/application/session_controller.dart';
import 'package:nordic_ledger/features/auth/data/secure_key_value_store.dart';
import 'package:nordic_ledger/features/auth/presentation/screens/mpin_unlock_screen.dart';
import 'package:nordic_ledger/features/company/application/company_providers.dart';
import 'package:nordic_ledger/features/dashboard/presentation/screens/home_screen.dart';
import 'package:nordic_ledger/features/notifications/application/notification_providers.dart';
import 'package:nordic_ledger/features/notifications/data/local_notification_gateway.dart';
import 'package:nordic_ledger/features/overdue/presentation/screens/overdue_screen.dart';

import '../../../domain/ledger/ledger_fixtures.dart';
import '../../auth/auth_fakes.dart';
import '../../borrowers/borrower_test_support.dart';
import '../../onboarding/onboarding_test_support.dart';

const String kCidB = 'co-2';

/// Mutable active company / uid so the test can switch or sign out.
class Holder extends Notifier<String?> {
  Holder(this.initial);
  final String? initial;
  @override
  String? build() => initial;
  void set(String? v) => state = v;
}

final NotifierProvider<Holder, String?> cidHolder =
    NotifierProvider<Holder, String?>(() => Holder(kCid));
final NotifierProvider<Holder, String?> uidHolder =
    NotifierProvider<Holder, String?>(() => Holder(kOwnerUid));

Future<void> pumpAsync() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class Rig {
  Rig(this.db, this.gw, this.c);
  final FakeFirebaseFirestore db;
  final InMemoryNotificationGateway gw;
  final ProviderContainer c;

  List<PlannedNotification> kind(NotificationKind k) => <PlannedNotification>[
    for (final s in gw.scheduled)
      if (s.plan.kind == k) s.plan,
  ];
}

/// Company A = aggregates fixture (C1 ₹10,000 due today, C2 ₹5,000
/// overdue); company B = one ₹2,000 loan due today. 07:00 IST, 7 Nov 2023.
Future<Rig> rig({bool perInstallment = false}) async {
  final db = FakeFirebaseFirestore();
  await aggregatesFixture().writeTo(db);
  final b = LedgerSeed();
  b.borrowers.add(borrowerDoc('bb', 'Ravi Kumar', '+919900112233'));
  b.contracts.add(
    contractFor(
      'bb',
      'cb',
      loanNo: 1,
      sanctionedRs: 20000,
      installmentRs: 2000,
      firstDue: d(2023, 11, 7),
    ),
  );
  await b.writeTo(db, cid: kCidB);
  if (perInstallment) {
    await db.doc('user_settings/$kOwnerUid').set(<String, Object?>{
      'activeCompanyId': kCid,
      'notifications': <String, Object?>{
        'digestEnabled': true,
        'digestTime': '08:00',
        'perInstallmentEnabled': true,
        'overdueNudgeEnabled': true,
      },
    });
  }
  final gw = InMemoryNotificationGateway();
  final c = ProviderContainer(
    overrides: <Override>[
      firestoreProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(FixedClock.ist(2023, 11, 7, 7)),
      activeCompanyIdProvider.overrideWith(
        (Ref ref) => AsyncData<String?>(ref.watch(cidHolder)),
      ),
      currentUidProvider.overrideWith((Ref ref) => ref.watch(uidHolder)),
      currentRoleProvider.overrideWithValue(Role.owner),
      activeCompanyNameProvider.overrideWith(
        (Ref ref) => ref.watch(cidHolder) == kCidB ? 'B Co' : 'A Co',
      ),
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(signedIn: kAsha),
      ),
      secureKeyValueStoreProvider.overrideWithValue(
        InMemorySecureKeyValueStore(),
      ),
      biometricServiceProvider.overrideWithValue(FakeBiometricService()),
      localNotificationGatewayProvider.overrideWithValue(gw),
      notificationDebounceProvider.overrideWithValue(Duration.zero),
    ],
  );
  addTearDown(c.dispose);
  c.listen(collectionNotificationSchedulerProvider, (_, _) {});
  await pumpAsync();
  return Rig(db, gw, c);
}

void main() {
  group('scheduler', () {
    test('S8-S1 a payment re-plans; with per-installment on, the paid row '
        "reminder is cancelled", () async {
      final r = await rig(perInstallment: true);
      final today = r
          .kind(NotificationKind.installment)
          .where((PlannedNotification n) => n.date == kToday);
      expect(
        today.map((PlannedNotification n) => n.contractId).toSet(),
        <String>{'c1', 'c2'},
      );
      final calls = r.gw.replaceCalls;
      final c1 = (await TypedRefs(r.db).contract(kCid, 'c1').get()).data()!;
      await TypedRefs(
        r.db,
      ).transaction(kCid, 't-x').set(txFor(c1, 't-x', 10000, kToday));
      await pumpAsync();
      expect(r.gw.replaceCalls, calls + 1);
      final after = r
          .kind(NotificationKind.installment)
          .where((PlannedNotification n) => n.date == kToday)
          .map((PlannedNotification n) => n.contractId);
      expect(after, <String>['c2']);
      // C1's next week (14 Nov) is still reminded.
      expect(
        r
            .kind(NotificationKind.installment)
            .any(
              (PlannedNotification n) =>
                  n.contractId == 'c1' && n.date == d(2023, 11, 14),
            ),
        isTrue,
      );
    });

    test('S8-S2 a cancelled contract drops out of the next plan', () async {
      final r = await rig(perInstallment: true);
      await r.db.doc('companies/$kCid/contracts/c2').update(<String, Object?>{
        'status': ContractStatus.cancelled.name,
      });
      final inst = await r.db
          .collection('companies/$kCid/installments')
          .where('contractId', isEqualTo: 'c2')
          .get();
      for (final doc in inst.docs) {
        await doc.reference.update(<String, Object?>{'contractActive': false});
      }
      await pumpAsync();
      expect(
        r.gw.scheduled.any(
          (ScheduledNotification s) => s.plan.contractId == 'c2',
        ),
        isFalse,
      );
      // C2 was the only overdue loan: no nudge on day 0 any more.
      expect(
        r
            .kind(NotificationKind.overdue)
            .where((PlannedNotification n) => n.date == kToday),
        isEmpty,
      );
      expect(
        r.kind(NotificationKind.digest).first.body,
        '1 collection due today · ₹10,000',
      );
    });

    test('S8-S3 a company switch replaces the whole plan with the new '
        "company's", () async {
      final r = await rig();
      expect(r.gw.scheduled.first.plan.title, 'A Co');
      r.c.read(cidHolder.notifier).set(kCidB);
      await pumpAsync();
      await pumpAsync();
      expect(r.gw.scheduled, isNotEmpty);
      expect(
        r.gw.scheduled.every(
          (ScheduledNotification s) => s.plan.title == 'B Co',
        ),
        isTrue,
      );
      expect(
        r.kind(NotificationKind.digest).first.body,
        '1 collection due today · ₹2,000',
      );
    });

    test('S8-S4 sign-out (uid → null) cancels everything once', () async {
      final r = await rig();
      expect(r.gw.scheduled, isNotEmpty);
      r.c.read(uidHolder.notifier).set(null);
      await pumpAsync();
      expect(r.gw.scheduled, isEmpty);
      expect(r.gw.cancelCalls, 1);
      expect(r.c.read(collectionNotificationSchedulerProvider), isEmpty);
      // A further poke while signed out does not cancel again.
      r.c.read(cidHolder.notifier).set(kCidB);
      await pumpAsync();
      expect(r.gw.cancelCalls, 1);
    });

    test('S8-S5 no active company cancels everything', () async {
      final r = await rig();
      r.c.read(cidHolder.notifier).set(null);
      await pumpAsync();
      expect(r.gw.scheduled, isEmpty);
      expect(r.gw.cancelCalls, 1);
    });

    test('S8-S6 an unchanged plan is not re-sent (unrelated write)', () async {
      final r = await rig();
      final calls = r.gw.replaceCalls;
      await r.db.doc('companies/$kCid/borrowers/b1').update(<String, Object?>{
        'locality': 'T Nagar',
      });
      await pumpAsync();
      // Prefs re-saved with the same values.
      await r.db.doc('user_settings/$kOwnerUid').set(<String, Object?>{
        'notifications': const NotificationPrefs().toJson(),
      });
      await pumpAsync();
      expect(r.gw.replaceCalls, calls);
    });

    test('S8-S7 prefs all off → the OS gets an empty plan', () async {
      final r = await rig();
      await r.db.doc('user_settings/$kOwnerUid').set(<String, Object?>{
        'notifications': const NotificationPrefs(
          digestEnabled: false,
          overdueNudgeEnabled: false,
        ).toJson(),
      });
      await pumpAsync();
      expect(r.gw.scheduled, isEmpty);
    });
  });

  group('deep-link allow-list', () {
    test('S8-D1 only the 3 notification routes are accepted', () {
      for (final ok in <String>[
        AppRoutes.dueToday,
        AppRoutes.overdue,
        AppRoutes.recordPayment('c1'),
      ]) {
        expect(AppRoutes.isNotificationTarget(ok), isTrue, reason: ok);
      }
      for (final bad in <String>[
        '/settings/delete-account',
        '/settings/members',
        '/settings',
        '/home',
        '/home?tab=calendar',
        '/home?tab=today&x=1',
        '/overdue?x=1',
        'overdue',
        '//evil.example/overdue',
        'https://evil.example/overdue',
        '/contracts/c1',
        '/contracts/new/pay',
        '/contracts/onboard/pay',
        '/contracts//pay',
        '/contracts/c1/pay/',
        '/contracts/c1/pay?amount=1',
        '/contracts/c1/rollover',
        '',
      ]) {
        expect(AppRoutes.isNotificationTarget(bad), isFalse, reason: bad);
      }
    });

    test('S8-D2 an invalid offer never clears a valid pending link', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(pendingDeepLinkProvider.notifier)
        ..offer(AppRoutes.overdue)
        ..offer('/settings/delete-account')
        ..offer(null);
      expect(c.read(pendingDeepLinkProvider), AppRoutes.overdue);
      expect(n.consume(), AppRoutes.overdue);
      expect(n.consume(), isNull, reason: 'opened once');
    });

    test('S8-D3 every planned payload passes the allow-list', () async {
      final r = await rig(perInstallment: true);
      expect(r.gw.scheduled, isNotEmpty);
      for (final s in r.gw.scheduled) {
        expect(
          AppRoutes.isNotificationTarget(s.payload),
          isTrue,
          reason: s.payload,
        );
      }
    });
  });

  group('deep links in the app', () {
    Future<AuthHarness> pumpLocked(
      WidgetTester tester, {
      String? launchPayload,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(tester.view.reset);
      final h = AuthHarness(signedIn: kAsha);
      h.notifications.pendingLaunchPayload = launchPayload;
      await tester.runAsync(() async {
        await h.mpin.setMpin(kAsha.uid, '2468');
        await OnboardingFixtures.company(
          h.db,
          cid: 'a',
          name: 'A Co',
          owners: <String>[kAsha.uid],
        );
        await OnboardingFixtures.membership(
          h.db,
          uid: kAsha.uid,
          cid: 'a',
          name: 'A Co',
        );
      });
      await tester.pumpWidget(
        ProviderScope(overrides: h.overrides, child: const App()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return h;
    }

    Future<void> frames(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    Future<void> unlock(WidgetTester tester) async {
      for (final k in '2468'.split('')) {
        await tester.tap(find.byKey(ValueKey<String>('pin_key_$k')));
        await tester.pump();
      }
      await frames(tester);
    }

    testWidgets('S8-D4 cold start with an invalid payload: nothing held, '
        'unlock lands on Home', (WidgetTester tester) async {
      await pumpLocked(tester, launchPayload: '/settings/delete-account');
      await unlock(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      final c = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      expect(c.read(pendingDeepLinkProvider), isNull);
    });

    testWidgets('S8-D5 a tap after auto-lock is held, then opens after the '
        'MPIN', (WidgetTester tester) async {
      final h = await pumpLocked(tester);
      await unlock(tester);
      final c = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      c.read(sessionControllerProvider.notifier).lock();
      await frames(tester);
      expect(find.byType(MpinUnlockScreen), findsOneWidget);
      h.notifications.tap(AppRoutes.overdue);
      await frames(tester);
      expect(find.byType(OverdueScreen), findsNothing);
      expect(c.read(pendingDeepLinkProvider), AppRoutes.overdue);
      expect(c.read(readyDeepLinkProvider), isNull);
      await unlock(tester);
      expect(find.byType(OverdueScreen), findsOneWidget);
      expect(c.read(pendingDeepLinkProvider), isNull);
    });

    testWidgets('S8-D6 a later tap while locked wins over an earlier one', (
      WidgetTester tester,
    ) async {
      final h = await pumpLocked(tester, launchPayload: AppRoutes.dueToday);
      h.notifications.tap(AppRoutes.overdue);
      await frames(tester);
      await unlock(tester);
      expect(find.byType(OverdueScreen), findsOneWidget);
    });
  });
}
