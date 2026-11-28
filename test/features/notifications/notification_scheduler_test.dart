import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/core/routing/app_router.dart';
import 'package:nordic_ledger/core/time/ist_clock.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/auth/application/auth_providers.dart';
import 'package:nordic_ledger/features/auth/data/secure_key_value_store.dart';
import 'package:nordic_ledger/features/company/application/company_providers.dart';
import 'package:nordic_ledger/features/notifications/application/notification_providers.dart';
import 'package:nordic_ledger/features/notifications/data/local_notification_gateway.dart';
import 'package:nordic_ledger/features/onboarding/data/user_settings_repository.dart';

import '../auth/auth_fakes.dart';
import '../borrowers/borrower_test_support.dart';

/// 07:00 IST on Tue 7 Nov 2023: before the 08:00 digest.
FixedClock earlyClock() => FixedClock.ist(2023, 11, 7, 7);

final class Rig {
  Rig(this.db, this.gateway, this.container);

  final FakeFirebaseFirestore db;
  final InMemoryNotificationGateway gateway;
  final ProviderContainer container;

  List<ScheduledNotification> of(NotificationKind k) => <ScheduledNotification>[
    for (final s in gateway.scheduled)
      if (s.plan.kind == k) s,
  ];
}

Future<void> pumpAsync() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// The aggregates fixture (C1 due today ₹10,000; C2's 31 Oct row ₹5,000
/// overdue 7 days) with the scheduler running.
Future<Rig> rig({
  FixedClock? clock,
  List<Override> extra = const <Override>[],
}) async {
  final db = FakeFirebaseFirestore();
  await aggregatesFixture().writeTo(db);
  final gateway = InMemoryNotificationGateway();
  final c = ProviderContainer(
    overrides: <Override>[
      ...borrowerOverrides(db, clock: clock ?? earlyClock()),
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(signedIn: kAsha),
      ),
      secureKeyValueStoreProvider.overrideWithValue(
        InMemorySecureKeyValueStore(),
      ),
      biometricServiceProvider.overrideWithValue(FakeBiometricService()),
      localNotificationGatewayProvider.overrideWithValue(gateway),
      notificationDebounceProvider.overrideWithValue(Duration.zero),
      ...extra,
    ],
  );
  addTearDown(c.dispose);
  c.listen(collectionNotificationSchedulerProvider, (_, _) {});
  await pumpAsync();
  return Rig(db, gateway, c);
}

void main() {
  test('app start schedules the digest and the overdue nudge with '
      'deep-link payloads', () async {
    final r = await rig();
    final digests = r.of(NotificationKind.digest);
    expect(digests.first.plan.date, kToday);
    expect(digests.first.plan.title, 'Sri Lakshmi Finance');
    // C1 ₹10,000 + C2 ₹5,000 (both weekly on Tuesdays).
    expect(digests.first.plan.body, '2 collections due today · ₹15,000');
    expect(
      digests.first.payload,
      AppRoutes.withCompany(AppRoutes.dueToday, kCid),
    );

    final nudges = r.of(NotificationKind.overdue);
    expect(nudges, hasLength(notificationWindowDays));
    expect(nudges.first.plan.body, '1 overdue · ₹5,000 · highest 7 days');
    expect(
      nudges.first.payload,
      AppRoutes.withCompany(AppRoutes.overdue, kCid),
    );

    // Per-installment reminders are off by default.
    expect(r.of(NotificationKind.installment), isEmpty);
    // 14-day window.
    expect(
      r.gateway.scheduled.every(
        (ScheduledNotification s) =>
            kToday.daysBetween(s.plan.date) < notificationWindowDays,
      ),
      isTrue,
    );
  });

  test(
    'a recorded payment re-plans: a fully paid row never notifies',
    () async {
      final r = await rig();
      final calls = r.gateway.replaceCalls;
      final c1 = (await TypedRefs(r.db).contract(kCid, 'c1').get()).data()!;
      await TypedRefs(
        r.db,
      ).transaction(kCid, 't-new').set(txFor(c1, 't-new', 10000, kToday));
      await pumpAsync();
      expect(r.gateway.replaceCalls, greaterThan(calls));
      // C1's row is paid; only C2's ₹5,000 is left today.
      expect(
        r.of(NotificationKind.digest).first.plan.body,
        '1 collection due today · ₹5,000',
      );
    },
  );

  test('a reversal brings the reminder back', () async {
    final r = await rig();
    final refs = TypedRefs(r.db);
    final c1 = (await refs.contract(kCid, 'c1').get()).data()!;
    await refs
        .transaction(kCid, 't-new')
        .set(txFor(c1, 't-new', 10000, kToday));
    await pumpAsync();
    await refs
        .transaction(kCid, 't-rev')
        .set(
          txFor(
            c1,
            't-rev',
            10000,
            kToday,
            type: TxType.reversal,
            reversesTxId: 't-new',
          ),
        );
    await pumpAsync();
    expect(
      r.of(NotificationKind.digest).first.plan.body,
      '2 collections due today · ₹15,000',
    );
  });

  test(
    'preferences from user_settings: per-installment on, digest off',
    () async {
      final r = await rig();
      await UserSettingsRepository(firestore: r.db).setNotificationPrefs(
        kOwnerUid,
        const NotificationPrefs(
          digestEnabled: false,
          perInstallmentEnabled: true,
        ),
      );
      await pumpAsync();
      expect(r.of(NotificationKind.digest), isEmpty);
      final first = r.of(NotificationKind.installment).first;
      expect(first.plan.body, 'Anita Sharma · Loan #04 · ₹10,000 due today');
      expect(
        first.payload,
        AppRoutes.withCompany(AppRoutes.recordPayment('c1'), kCid),
      );
    },
  );

  test("past the digest time, today's slot is not scheduled", () async {
    final r = await rig(clock: FixedClock.ist(2023, 11, 7, 9));
    expect(
      r.gateway.scheduled.where(
        (ScheduledNotification s) => s.plan.date == kToday,
      ),
      isEmpty,
    );
    expect(r.of(NotificationKind.overdue).first.plan.date, kToday.addDays(1));
  });

  test('an unchanged plan is not re-sent to the OS', () async {
    final r = await rig();
    final calls = r.gateway.replaceCalls;
    // A write that changes nothing the plan depends on.
    await TypedRefs(r.db)
        .borrower(kCid, 'b1')
        .set(borrowerDoc('b1', 'Anita Sharma', '+919845012890'));
    await pumpAsync();
    expect(r.gateway.replaceCalls, calls);
  });

  test('account deletion in progress cancels everything', () async {
    final r = await rig();
    expect(r.gateway.scheduled, isNotEmpty);
    r.container.read(accountDeletionInProgressProvider.notifier).start();
    await pumpAsync();
    expect(r.gateway.scheduled, isEmpty);
    expect(r.gateway.cancelCalls, 1);
    expect(r.container.read(collectionNotificationSchedulerProvider), isEmpty);
  });

  test('cancelAll (sign-out) clears pending and shown notifications', () async {
    final r = await rig();
    await r.container
        .read(collectionNotificationSchedulerProvider.notifier)
        .cancelAll();
    expect(r.gateway.scheduled, isEmpty);
    expect(r.gateway.cancelCalls, 1);
  });

  group('notificationPayload', () {
    test('maps each kind to its route', () {
      PlannedNotification p(NotificationKind k, [String? cid]) =>
          PlannedNotification(
            id: 1,
            kind: k,
            date: kToday,
            time: DigestTime.fallback,
            title: 't',
            body: 'b',
            contractId: cid,
          );
      expect(
        notificationPayload(p(NotificationKind.digest)),
        '/home?tab=today',
      );
      expect(notificationPayload(p(NotificationKind.overdue)), '/overdue');
      expect(
        notificationPayload(p(NotificationKind.installment, 'c 1')),
        '/contracts/c%201/pay',
      );
    });
  });
}
