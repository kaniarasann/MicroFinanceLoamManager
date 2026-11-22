import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/core/time/ist_clock.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/onboarding/data/company_repository.dart';
import 'package:nordic_ledger/features/onboarding/data/invite_repository.dart';
import 'package:nordic_ledger/features/onboarding/data/user_settings_repository.dart';

import 'onboarding_test_support.dart';

final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  late FakeFirebaseFirestore db;
  final clock = FixedClock.ist(2026, 11, 21, 10);
  final now = clock.nowIst().toUtc();

  setUp(() => db = FakeFirebaseFirestore());

  group('CompanyRepository.registerCompany', () {
    CompanyRepository repo() => CompanyRepository(firestore: db, clock: clock);

    test('writes company + owner member + membership + settings', () async {
      final id = await repo().registerCompany(
        uid: 'u1',
        name: '  Sri Lakshmi Finance  ',
        city: ' Chennai ',
        phoneE164: '+91 90000 11111',
        ownerDisplayName: ' Asha Rao ',
        ownerPhoneE164: '98450 12890',
      );
      expect(id, matches(_uuidV4));

      final company = (await db.doc('companies/$id').get()).data()!;
      expect(company['name'], 'Sri Lakshmi Finance');
      expect(company['nameLower'], 'sri lakshmi finance');
      expect(company['city'], 'Chennai');
      expect(company['phoneE164'], '+919000011111');
      expect(company['ownerUids'], <String>['u1']);
      expect(company['nextLoanNo'], 0);
      expect(company['createdBy'], 'u1');
      expect(company['createdAt'], isA<Timestamp>());
      expect(company['schemaVersion'], 1);

      final member = (await db.doc('companies/$id/members/u1').get()).data()!;
      expect(member.keys.toSet(), <String>{
        'uid',
        'role',
        'displayName',
        'phoneE164',
        'status',
        'inviteCode',
        'invitedBy',
        'joinedAt',
        'schemaVersion',
      }, reason: 'rules: members accept only the model fields');
      expect(member['uid'], 'u1');
      expect(member['role'], 'owner');
      expect(member['displayName'], 'Asha Rao');
      expect(member['phoneE164'], '+919845012890');
      expect(member['status'], 'active');

      final membership = (await db.doc('users/u1/memberships/$id').get())
          .data()!;
      expect(membership.keys.toSet(), <String>{
        'companyId',
        'companyName',
        'role',
        'joinedAt',
        'schemaVersion',
      });
      expect(membership['companyId'], id);
      expect(membership['companyName'], 'Sri Lakshmi Finance');
      expect(membership['role'], 'owner');

      final settings = (await db.doc('user_settings/u1').get()).data()!;
      expect(settings['activeCompanyId'], id);
    });

    test('keeps existing settings when registering a second company', () async {
      await db.doc('user_settings/u1').set(<String, Object?>{
        'activeCompanyId': 'old',
        'autoLockMinutes': 5,
      });
      final id = await repo().registerCompany(
        uid: 'u1',
        name: 'Second Co',
        ownerDisplayName: 'Asha',
      );
      final settings = (await db.doc('user_settings/u1').get()).data()!;
      expect(settings['activeCompanyId'], id);
      expect(settings['autoLockMinutes'], 5);
      final company = (await db.doc('companies/$id').get()).data()!;
      expect(company['city'], isNull);
      expect(company['phoneE164'], isNull);
    });

    test('validates name and phones before writing', () async {
      Future<void> expectInvalid(Future<String> f, String field) => expectLater(
        f,
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure v) => v.field,
            'field',
            field,
          ),
        ),
      );
      await expectInvalid(
        repo().registerCompany(uid: 'u1', name: ' ', ownerDisplayName: 'A'),
        'name',
      );
      await expectInvalid(
        repo().registerCompany(uid: 'u1', name: 'A', ownerDisplayName: 'A'),
        'name',
      );
      await expectInvalid(
        repo().registerCompany(
          uid: 'u1',
          name: 'A' * 81,
          ownerDisplayName: 'A',
        ),
        'name',
      );
      await expectInvalid(
        repo().registerCompany(uid: 'u1', name: 'Good', ownerDisplayName: ''),
        'ownerDisplayName',
      );
      await expectInvalid(
        repo().registerCompany(
          uid: 'u1',
          name: 'Good',
          ownerDisplayName: 'Asha',
          ownerPhoneE164: '12345',
        ),
        'ownerPhone',
      );
      await expectInvalid(
        repo().registerCompany(
          uid: 'u1',
          name: 'Good',
          ownerDisplayName: 'Asha',
          phoneE164: '044 2345 6789', // landline
        ),
        'phone',
      );
      expect((await db.collection('companies').get()).docs, isEmpty);
    });

    test('watchMemberships lists oldest first', () async {
      await OnboardingFixtures.membership(
        db,
        uid: 'u1',
        cid: 'b',
        name: 'B Co',
        joinedAt: DateTime.utc(2026, 11, 5),
      );
      await OnboardingFixtures.membership(
        db,
        uid: 'u1',
        cid: 'a',
        name: 'A Co',
        joinedAt: DateTime.utc(2026, 11, 1),
      );
      final list = await repo().watchMemberships('u1').first;
      expect(list.map((Membership m) => m.id), <String>['a', 'b']);
    });

    test('watchMember emits null once the member doc is deleted', () async {
      await OnboardingFixtures.membership(db, uid: 'u1', cid: 'a', name: 'A');
      final events = <Member?>[];
      final sub = repo().watchMember('a', 'u1').listen(events.add);
      await pumpEventQueue();
      // The fake only notifies listeners of the same converted type.
      await TypedRefs(db).member('a', 'u1').delete();
      await pumpEventQueue();
      await sub.cancel();
      expect(events.first?.role, Role.owner);
      expect(events.last, isNull);
    });
  });

  group('InviteRepository', () {
    InviteRepository repo() => InviteRepository(firestore: db, clock: clock);
    final future = now.add(const Duration(days: 6));

    test('lookup returns the preview', () async {
      await OnboardingFixtures.invite(db, expiresAt: future);
      final p = await repo().lookup(' k7q2md ');
      expect(p.code, 'K7Q2MD');
      expect(p.companyId, 'cid-a');
      expect(p.companyName, 'Sri Lakshmi Finance');
      expect(p.companyCity, 'Chennai');
      expect(p.role, Role.collector);
      expect(p.invitedByName, 'Ravi Kumar');
    });

    test(
      'lookup: missing / expired / accepted / revoked / bad format',
      () async {
        await expectLater(
          repo().lookup('K7Q2MD'),
          throwsA(isA<NotFoundFailure>()),
        );
        await OnboardingFixtures.invite(
          db,
          expiresAt: now.subtract(const Duration(minutes: 1)),
        );
        await expectLater(
          repo().lookup('K7Q2MD'),
          throwsA(isA<ExpiredFailure>()),
        );
        await OnboardingFixtures.invite(
          db,
          code: 'ACCEP2',
          status: 'accepted',
          expiresAt: future,
        );
        await expectLater(
          repo().lookup('ACCEP2'),
          throwsA(isA<InviteUnavailableFailure>()),
        );
        await OnboardingFixtures.invite(
          db,
          code: 'REVK22',
          status: 'revoked',
          expiresAt: future,
        );
        await expectLater(
          repo().lookup('REVK22'),
          throwsA(isA<InviteUnavailableFailure>()),
        );
        await expectLater(
          repo().lookup('K7Q2M0'),
          throwsA(isA<ValidationFailure>()),
        );
      },
    );

    test('accept (collector): member + membership + invite accepted', () async {
      await OnboardingFixtures.company(db);
      await OnboardingFixtures.invite(db, expiresAt: future);
      final p = await repo().accept('K7Q2MD', uid: 'u2');
      expect(p.companyId, 'cid-a');

      final member = (await db.doc('companies/cid-a/members/u2').get()).data()!;
      expect(member['uid'], 'u2');
      expect(member['role'], 'collector');
      expect(member['inviteCode'], 'K7Q2MD');
      expect(member['invitedBy'], 'uid-owner');
      expect(member['displayName'], 'Meena');
      expect(member['phoneE164'], '+919845012890');
      expect(member['status'], 'active');

      final membership = (await db.doc('users/u2/memberships/cid-a').get())
          .data()!;
      expect(membership['role'], 'collector');
      expect(membership['companyName'], 'Sri Lakshmi Finance');
      expect(membership['companyId'], 'cid-a');

      final invite = (await db.doc('invites/K7Q2MD').get()).data()!;
      expect(invite['status'], 'accepted');
      expect(invite['acceptedBy'], 'u2');
      expect(invite['acceptedAt'], isA<Timestamp>());

      final company = (await db.doc('companies/cid-a').get()).data()!;
      expect(company['ownerUids'], <String>['uid-owner']);
    });

    test('accept (owner invite) also arrayUnions ownerUids', () async {
      await OnboardingFixtures.company(db);
      await OnboardingFixtures.invite(db, role: 'owner', expiresAt: future);
      await repo().accept('K7Q2MD', uid: 'u2');
      final company = (await db.doc('companies/cid-a').get()).data()!;
      expect(company['ownerUids'], <String>['uid-owner', 'u2']);
      final member = (await db.doc('companies/cid-a/members/u2').get()).data()!;
      expect(member['role'], 'owner');
    });

    test(
      'accept throws for expired / accepted / missing and writes nothing',
      () async {
        await OnboardingFixtures.company(db);
        await expectLater(
          repo().accept('K7Q2MD', uid: 'u2'),
          throwsA(isA<NotFoundFailure>()),
        );
        await OnboardingFixtures.invite(
          db,
          expiresAt: now.subtract(const Duration(seconds: 1)),
        );
        await expectLater(
          repo().accept('K7Q2MD', uid: 'u2'),
          throwsA(isA<ExpiredFailure>()),
        );
        await OnboardingFixtures.invite(
          db,
          status: 'accepted',
          expiresAt: future,
        );
        await expectLater(
          repo().accept('K7Q2MD', uid: 'u2'),
          throwsA(isA<InviteUnavailableFailure>()),
        );
        expect(
          (await db.doc('companies/cid-a/members/u2').get()).exists,
          isFalse,
        );
        expect(
          (await db.doc('users/u2/memberships/cid-a').get()).exists,
          isFalse,
        );
      },
    );
  });

  group('UserSettingsRepository', () {
    test('get / watch / set activeCompanyId', () async {
      final repo = UserSettingsRepository(firestore: db);
      expect(await repo.get('u1'), isNull);
      await repo.setActiveCompanyId('u1', 'cid-a');
      await pumpEventQueue();
      expect((await repo.get('u1'))?.activeCompanyId, 'cid-a');
      expect((await repo.watch('u1').first)?.activeCompanyId, 'cid-a');
      await repo.setActiveCompanyId('u1', null);
      await pumpEventQueue();
      expect((await repo.get('u1'))?.activeCompanyId, isNull);
    });
  });
}
