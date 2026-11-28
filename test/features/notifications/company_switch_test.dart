import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/firebase/firebase_providers.dart';
import 'package:nordic_ledger/core/routing/app_router.dart';
import 'package:nordic_ledger/core/time/clock_provider.dart';
import 'package:nordic_ledger/core/time/ist_clock.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/auth/application/auth_providers.dart';
import 'package:nordic_ledger/features/auth/data/secure_key_value_store.dart';
import 'package:nordic_ledger/features/company/application/company_providers.dart';
import 'package:nordic_ledger/features/notifications/application/notification_providers.dart';
import 'package:nordic_ledger/features/notifications/data/local_notification_gateway.dart';

import '../auth/auth_fakes.dart';
import '../borrowers/borrower_test_support.dart';

/// F4 / S8-B1 (attempt 2): a company switch cancels the old company's
/// pending AND delivered notifications at once, and payloads name their
/// company.
List<Override> overridesFor(
  FakeFirebaseFirestore db,
  InMemoryNotificationGateway gateway,
  String? cid,
) => <Override>[
  firestoreProvider.overrideWithValue(db),
  clockProvider.overrideWithValue(FixedClock.ist(2023, 11, 7, 7)),
  activeCompanyIdProvider.overrideWithValue(AsyncData<String?>(cid)),
  currentUidProvider.overrideWithValue(kOwnerUid),
  currentRoleProvider.overrideWithValue(Role.owner),
  activeCompanyNameProvider.overrideWithValue(cid == null ? null : 'Co $cid'),
  authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedIn: kAsha)),
  secureKeyValueStoreProvider.overrideWithValue(InMemorySecureKeyValueStore()),
  biometricServiceProvider.overrideWithValue(FakeBiometricService()),
  localNotificationGatewayProvider.overrideWithValue(gateway),
  notificationDebounceProvider.overrideWithValue(Duration.zero),
];

Future<void> pumpAsync() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('switching company cancels everything first, then plans the new '
      'company with tagged payloads', () async {
    final db = FakeFirebaseFirestore();
    await aggregatesFixture().writeTo(db);
    await aggregatesFixture().writeTo(db, cid: 'co-2');
    final gateway = InMemoryNotificationGateway();
    final c = ProviderContainer(overrides: overridesFor(db, gateway, kCid));
    addTearDown(c.dispose);
    c.listen(collectionNotificationSchedulerProvider, (_, _) {});
    await pumpAsync();
    expect(gateway.scheduled, isNotEmpty);
    expect(
      gateway.scheduled.every(
        (ScheduledNotification s) => AppRoutes.companyOf(s.payload) == kCid,
      ),
      isTrue,
    );
    expect(gateway.cancelCalls, 0);

    c.updateOverrides(overridesFor(db, gateway, 'co-2'));
    // The cancel is not debounced and does not wait for co-2's figures.
    await Future<void>.delayed(Duration.zero);
    expect(gateway.cancelCalls, 1);
    await pumpAsync();
    expect(gateway.scheduled, isNotEmpty);
    expect(
      gateway.scheduled.every(
        (ScheduledNotification s) =>
            AppRoutes.companyOf(s.payload) == 'co-2' &&
            s.plan.title == 'Co co-2',
      ),
      isTrue,
    );
  });

  test('losing the company cancels at once', () async {
    final db = FakeFirebaseFirestore();
    await aggregatesFixture().writeTo(db);
    final gateway = InMemoryNotificationGateway();
    final c = ProviderContainer(overrides: overridesFor(db, gateway, kCid));
    addTearDown(c.dispose);
    c.listen(collectionNotificationSchedulerProvider, (_, _) {});
    await pumpAsync();
    c.updateOverrides(overridesFor(db, gateway, null));
    await pumpAsync();
    expect(gateway.scheduled, isEmpty);
    expect(gateway.cancelCalls, greaterThanOrEqualTo(1));
  });

  group('company-tagged links', () {
    test('withCompany / companyOf / withoutCompany', () {
      final t = AppRoutes.withCompany(AppRoutes.dueToday, 'a b');
      expect(t, '/home?tab=today&c=a+b');
      expect(AppRoutes.companyOf(t), 'a b');
      expect(AppRoutes.withoutCompany(t), AppRoutes.dueToday);
      final o = AppRoutes.withCompany(AppRoutes.overdue, 'x');
      expect(o, '/overdue?c=x');
      expect(AppRoutes.withoutCompany(o), AppRoutes.overdue);
      expect(AppRoutes.withoutCompany('/overdue'), '/overdue');
      expect(AppRoutes.companyOf('/overdue'), isNull);
    });

    test('the allow-list takes c= and nothing else extra', () {
      expect(
        AppRoutes.isNotificationTarget(
          AppRoutes.withCompany(AppRoutes.recordPayment('c1'), 'x'),
        ),
        isTrue,
      );
      expect(AppRoutes.isNotificationTarget('/overdue?c='), isFalse);
      expect(AppRoutes.isNotificationTarget('/overdue?c=x&y=1'), isFalse);
      expect(AppRoutes.isNotificationTarget('/home?tab=calendar&c=x'), isFalse);
    });
  });
}
