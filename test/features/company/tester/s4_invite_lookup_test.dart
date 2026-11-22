import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/time/ist_clock.dart';
import 'package:nordic_ledger/features/onboarding/data/invite_repository.dart';

import '../../onboarding/onboarding_test_support.dart';

void main() {
  late FakeFirebaseFirestore db;
  final clock = FixedClock.ist(2026, 11, 21, 10);
  final now = clock.nowIst().toUtc();
  InviteRepository repo() => InviteRepository(firestore: db, clock: clock);

  setUp(() async {
    db = FakeFirebaseFirestore();
    await OnboardingFixtures.company(db);
  });

  test('expired invite (1 minute past) -> ExpiredFailure on lookup', () async {
    await OnboardingFixtures.invite(
      db,
      expiresAt: now.subtract(const Duration(minutes: 1)),
    );
    await expectLater(repo().lookup('K7Q2MD'), throwsA(isA<ExpiredFailure>()));
  });

  test('expired invite -> ExpiredFailure on accept, nothing written', () async {
    await OnboardingFixtures.invite(
      db,
      expiresAt: now.subtract(const Duration(days: 1)),
    );
    await expectLater(
      repo().accept('K7Q2MD', uid: 'u-col'),
      throwsA(isA<ExpiredFailure>()),
    );
    expect((await db.doc('companies/cid-a/members/u-col').get()).exists, isFalse);
    expect((await db.doc('users/u-col/memberships/cid-a').get()).exists, isFalse);
  });

  test('already-accepted code -> InviteUnavailable (lookup + accept)', () async {
    await OnboardingFixtures.invite(
      db,
      status: 'accepted',
      expiresAt: now.add(const Duration(days: 3)),
    );
    await expectLater(
      repo().lookup('K7Q2MD'),
      throwsA(isA<InviteUnavailableFailure>()),
    );
    await expectLater(
      repo().accept('K7Q2MD', uid: 'u-other'),
      throwsA(isA<InviteUnavailableFailure>()),
    );
  });

  test('accept twice: second accept -> InviteUnavailable (single use)', () async {
    await OnboardingFixtures.invite(
      db,
      expiresAt: now.add(const Duration(days: 3)),
    );
    await repo().accept('K7Q2MD', uid: 'u-col');
    final inv = (await db.doc('invites/K7Q2MD').get()).data()!;
    expect(inv['status'], 'accepted');
    expect(inv['acceptedBy'], 'u-col');
    await expectLater(
      repo().accept('K7Q2MD', uid: 'u-2'),
      throwsA(isA<InviteUnavailableFailure>()),
    );
  });

  test('revoked code -> InviteUnavailable', () async {
    await OnboardingFixtures.invite(
      db,
      status: 'revoked',
      expiresAt: now.add(const Duration(days: 3)),
    );
    await expectLater(
      repo().lookup('K7Q2MD'),
      throwsA(isA<InviteUnavailableFailure>()),
    );
  });

  test('lowercase / padded code is normalised; unknown code -> NotFound', () async {
    await OnboardingFixtures.invite(
      db,
      expiresAt: now.add(const Duration(days: 3)),
    );
    final p = await repo().lookup('  k7q2md ');
    expect(p, isNotNull);
    await expectLater(repo().lookup('ZZZZZZ'), throwsA(isA<NotFoundFailure>()));
  });

  test('malformed code (contains O / too short) -> ValidationFailure', () async {
    await expectLater(repo().lookup('K7Q2MO'), throwsA(isA<ValidationFailure>()));
    await expectLater(repo().lookup('K7Q'), throwsA(isA<ValidationFailure>()));
  });

  test('owner invite accept adds uid to ownerUids, member role owner', () async {
    await OnboardingFixtures.invite(
      db,
      role: 'owner',
      expiresAt: now.add(const Duration(days: 3)),
    );
    await repo().accept('K7Q2MD', uid: 'u-co');
    final c = (await db.doc('companies/cid-a').get()).data()!;
    expect(c['ownerUids'], containsAll(<String>['uid-owner', 'u-co']));
    final m = (await db.doc('companies/cid-a/members/u-co').get()).data()!;
    expect(m['role'], 'owner');
    expect(m['displayName'], 'Meena');
  });
}
