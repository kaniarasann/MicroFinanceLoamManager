import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/auth/application/session_controller.dart';
import 'package:nordic_ledger/features/company/application/company_providers.dart';
import 'package:nordic_ledger/features/onboarding/data/cache_reset_flag.dart';

import '../auth/auth_fakes.dart';
import '../onboarding/onboarding_test_support.dart';

const String uid = 'uid-asha';

Future<ProviderContainer> start(AuthHarness h) async {
  final c = h.container();
  c
    ..listen(sessionControllerProvider, (_, _) {})
    ..listen(companyAccessGuardProvider, (_, _) {})
    ..listen(companyGateProvider, (_, _) {})
    ..listen(currentRoleProvider, (_, _) {})
    ..listen(activeCompanyNameProvider, (_, _) {});
  await pumpEventQueue();
  return c;
}

Future<void> seedTwo(AuthHarness h, {String roleB = 'collector'}) async {
  await OnboardingFixtures.company(h.db, cid: 'a', name: 'A Co');
  await OnboardingFixtures.company(h.db, cid: 'b', name: 'B Co');
  await OnboardingFixtures.membership(
    h.db,
    uid: uid,
    cid: 'a',
    name: 'A Co',
    joinedAt: DateTime.utc(2026, 11, 1),
  );
  await OnboardingFixtures.membership(
    h.db,
    uid: uid,
    cid: 'b',
    name: 'B Co',
    role: roleB,
    joinedAt: DateTime.utc(2026, 11, 2),
  );
}

void main() {
  test('resolveActiveCompanyId: stored if a member, else first', () {
    final ms = <Membership>[
      Membership(
        id: 'a',
        companyId: 'a',
        companyName: 'A',
        role: Role.owner,
        joinedAt: DateTime.utc(2026),
      ),
      Membership(
        id: 'b',
        companyId: 'b',
        companyName: 'B',
        role: Role.collector,
        joinedAt: DateTime.utc(2026),
      ),
    ];
    expect(resolveActiveCompanyId(ms, 'b'), 'b');
    expect(resolveActiveCompanyId(ms, 'gone'), 'a');
    expect(resolveActiveCompanyId(ms, null), 'a');
    expect(resolveActiveCompanyId(const <Membership>[], 'b'), isNull);
  });

  test('no memberships: gate none, no active company, no role', () async {
    final c = await start(AuthHarness(signedIn: kAsha));
    expect(c.read(companyGateProvider), CompanyGate.none);
    expect(c.read(activeCompanyIdProvider).value, isNull);
    expect(c.read(currentRoleProvider), isNull);
  });

  test('signed out: gate loading', () async {
    final c = await start(AuthHarness());
    expect(c.read(companyGateProvider), CompanyGate.loading);
  });

  test('active company falls back to the first membership', () async {
    final h = AuthHarness(signedIn: kAsha);
    await seedTwo(h);
    final c = await start(h);
    expect(c.read(companyGateProvider), CompanyGate.ready);
    expect(c.read(activeCompanyIdProvider).value, 'a');
    expect(c.read(currentRoleProvider), Role.owner);
    expect(c.read(activeCompanyNameProvider), 'A Co');
    expect(c.read(membershipsProvider).value, hasLength(2));
  });

  test('user_settings.activeCompanyId wins when still a member', () async {
    final h = AuthHarness(signedIn: kAsha);
    await seedTwo(h);
    await h.db.doc('user_settings/$uid').set(<String, Object?>{
      'activeCompanyId': 'b',
    });
    final c = await start(h);
    expect(c.read(activeCompanyIdProvider).value, 'b');
    expect(c.read(currentRoleProvider), Role.collector);
  });

  test('switching writes user_settings and changes the role', () async {
    final h = AuthHarness(signedIn: kAsha);
    await seedTwo(h);
    final c = await start(h);
    expect(c.read(currentRoleProvider), Role.owner);

    await c.read(companyActionsProvider).switchTo('b');
    await pumpEventQueue();

    expect(c.read(activeCompanyIdProvider).value, 'b');
    expect(c.read(currentRoleProvider), Role.collector);
    expect(c.read(activeCompanyNameProvider), 'B Co');
    final settings = (await h.db.doc('user_settings/$uid').get()).data()!;
    expect(settings['activeCompanyId'], 'b');
  });

  test('role comes from the member doc (source of truth)', () async {
    final h = AuthHarness(signedIn: kAsha);
    await OnboardingFixtures.company(h.db, cid: 'a', name: 'A Co');
    // Stale index says owner; the member doc says collector.
    await OnboardingFixtures.membership(
      h.db,
      uid: uid,
      cid: 'a',
      name: 'A Co',
      withMemberDoc: false,
    );
    await h.db.doc('companies/a/members/$uid').set(<String, Object?>{
      'uid': uid,
      'role': 'collector',
      'displayName': 'Asha',
      'status': 'active',
      'joinedAt': DateTime.utc(2026, 11).toIso8601String(),
      'schemaVersion': 1,
    });
    final c = await start(h);
    expect(c.read(currentMemberProvider)?.role, Role.collector);
    expect(c.read(currentRoleProvider), Role.collector);
  });

  group('removed member', () {
    test('member doc deleted: switch to the next company, notify once, '
        'schedule cache clear, clean up the membership', () async {
      final h = AuthHarness(signedIn: kAsha);
      await seedTwo(h);
      final c = await start(h);
      final notices = <String?>[];
      c.listen(companyNoticeProvider, (_, String? n) => notices.add(n));
      expect(c.read(activeCompanyIdProvider).value, 'a');

      // The owner removed Asha from A (fake: delete via the typed ref so the
      // typed listener fires, as the real SDK would).
      await TypedRefs(h.db).member('a', uid).delete();
      await pumpEventQueue();

      expect(c.read(activeCompanyIdProvider).value, 'b');
      expect(c.read(currentRoleProvider), Role.collector);
      expect(notices.whereType<String>(), <String>[
        'You no longer have access to A Co',
      ]);
      expect(await CacheResetFlag(h.storage).isPending(), isTrue);
      final settings = (await h.db.doc('user_settings/$uid').get()).data()!;
      expect(settings['activeCompanyId'], 'b');
      expect(
        (await h.db.doc('users/$uid/memberships/a').get()).exists,
        isFalse,
      );
      expect(
        c.read(membershipsProvider).value!.map((Membership m) => m.id),
        <String>['b'],
      );
    });

    test('last company removed: gate none (→ onboarding)', () async {
      final h = AuthHarness(signedIn: kAsha);
      await OnboardingFixtures.company(h.db, cid: 'a', name: 'A Co');
      await OnboardingFixtures.membership(
        h.db,
        uid: uid,
        cid: 'a',
        name: 'A Co',
      );
      final c = await start(h);
      final notices = <String?>[];
      c.listen(companyNoticeProvider, (_, String? n) => notices.add(n));
      expect(c.read(companyGateProvider), CompanyGate.ready);

      await TypedRefs(h.db).member('a', uid).delete();
      await pumpEventQueue();

      expect(c.read(companyGateProvider), CompanyGate.none);
      expect(notices.whereType<String>(), hasLength(1));
      expect(await CacheResetFlag(h.storage).isPending(), isTrue);
    });

    test('membership doc deleted by the owner also switches out', () async {
      final h = AuthHarness(signedIn: kAsha);
      await seedTwo(h);
      final c = await start(h);
      final notices = <String?>[];
      c.listen(companyNoticeProvider, (_, String? n) => notices.add(n));

      await TypedRefs(h.db).membership(uid, 'a').delete();
      await pumpEventQueue();

      expect(c.read(activeCompanyIdProvider).value, 'b');
      expect(notices.whereType<String>(), <String>[
        'You no longer have access to A Co',
      ]);
    });

    test('a normal switch is not a removal', () async {
      final h = AuthHarness(signedIn: kAsha);
      await seedTwo(h);
      final c = await start(h);
      final notices = <String?>[];
      c.listen(companyNoticeProvider, (_, String? n) => notices.add(n));
      await c.read(companyActionsProvider).switchTo('b');
      await pumpEventQueue();
      expect(notices, isEmpty);
      expect(await CacheResetFlag(h.storage).isPending(), isFalse);
    });

    test('signing out is not a removal', () async {
      final h = AuthHarness(signedIn: kAsha);
      await seedTwo(h);
      final c = await start(h);
      final notices = <String?>[];
      c.listen(companyNoticeProvider, (_, String? n) => notices.add(n));
      await c.read(sessionControllerProvider.notifier).signOut();
      await pumpEventQueue();
      expect(notices, isEmpty);
      expect(c.read(companyGateProvider), CompanyGate.loading);
    });
  });

  test('registerCompany makes the new company active', () async {
    final h = AuthHarness(signedIn: kAsha);
    final c = await start(h);
    expect(c.read(companyGateProvider), CompanyGate.none);
    final cid = await c
        .read(companyActionsProvider)
        .registerCompany(name: 'Asha Finance', ownerDisplayName: 'Asha');
    await pumpEventQueue();
    expect(c.read(activeCompanyIdProvider).value, cid);
    expect(c.read(companyGateProvider), CompanyGate.ready);
    expect(c.read(currentRoleProvider), Role.owner);
  });

  test('acceptInvite makes the joined company active', () async {
    final h = AuthHarness(signedIn: kAsha);
    await seedTwo(h);
    await OnboardingFixtures.company(h.db, cid: 'c', name: 'C Co');
    await OnboardingFixtures.invite(
      h.db,
      companyId: 'c',
      companyName: 'C Co',
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
    );
    final c = await start(h);
    await c.read(companyActionsProvider).acceptInvite('K7Q2MD');
    await pumpEventQueue();
    expect(c.read(activeCompanyIdProvider).value, 'c');
    expect(c.read(currentRoleProvider), Role.collector);
  });
}
