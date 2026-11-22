import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/time/ist_clock.dart';
import 'package:nordic_ledger/core/validation/onboarding_validators.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/company/data/members_repository.dart';
import 'package:nordic_ledger/features/onboarding/data/invite_repository.dart';

import '../onboarding/onboarding_test_support.dart';

/// Deterministic [Random]: `nextInt` returns the queued values in order
/// (modulo max), then 0.
final class SeqRandom implements Random {
  SeqRandom(this.values);

  final List<int> values;
  int _i = 0;

  @override
  int nextInt(int max) => _i < values.length ? values[_i++] % max : 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

/// Indexes into [InviteCode.alphabet] that spell [code].
List<int> spell(String code) => <int>[
  for (final ch in code.split('')) InviteCode.alphabet.indexOf(ch),
];

void main() {
  late FakeFirebaseFirestore db;
  final clock = FixedClock.ist(2026, 11, 21, 10);
  final now = clock.nowIst().toUtc();

  setUp(() async {
    db = FakeFirebaseFirestore();
    await OnboardingFixtures.company(
      db,
      cid: 'cid-a',
      owners: <String>['ravi'],
    );
    await OnboardingFixtures.membership(
      db,
      uid: 'ravi',
      cid: 'cid-a',
      name: 'Sri Lakshmi Finance',
    );
    await db.doc('companies/cid-a/members/ravi').update(<String, Object?>{
      'displayName': 'Ravi Kumar',
    });
  });

  InviteRepository invites({Random? random}) =>
      InviteRepository(firestore: db, clock: clock, random: random);

  group('InviteRepository.createInvite', () {
    test('writes invites/{code} with every field, pending, +7 days', () async {
      final invite = await invites(random: SeqRandom(spell('K7Q2MD')))
          .createInvite(
            cid: 'cid-a',
            uid: 'ravi',
            inviteeName: ' Meena ',
            inviteePhoneE164: '98450 12891',
            role: Role.collector,
          );
      expect(invite.id, 'K7Q2MD');
      final data = (await db.doc('invites/K7Q2MD').get()).data()!;
      expect(data['companyId'], 'cid-a');
      expect(data['companyName'], 'Sri Lakshmi Finance');
      expect(data['companyCity'], 'Chennai');
      expect(data['role'], 'collector');
      expect(data['inviteeName'], 'Meena');
      expect(data['inviteePhoneE164'], '+919845012891');
      expect(data['createdBy'], 'ravi');
      expect(data['createdByName'], 'Ravi Kumar');
      expect(data['status'], 'pending');
      expect(data['acceptedBy'], isNull);
      expect(data['acceptedAt'], isNull);
      expect(data['schemaVersion'], 1);
      final created = (data['createdAt'] as Timestamp).toDate();
      final expires = (data['expiresAt'] as Timestamp).toDate();
      expect(created.isAtSameMomentAs(now), isTrue);
      expect(expires.difference(created), const Duration(days: 7));
    });

    test('codes use only the 6-char unambiguous alphabet', () {
      final repo = invites();
      for (var i = 0; i < 300; i++) {
        final code = repo.generateCode();
        expect(InviteCode.isValid(code), isTrue, reason: code);
        expect(code, isNot(matches(RegExp('[01ILO]'))));
      }
    });

    test('retries on a collision and uses the next free code', () async {
      await OnboardingFixtures.invite(
        db,
        code: 'AAAAAA',
        expiresAt: now.add(const Duration(days: 3)),
      );
      final invite =
          await invites(
            random: SeqRandom(<int>[...spell('AAAAAA'), ...spell('BBBBBB')]),
          ).createInvite(
            cid: 'cid-a',
            uid: 'ravi',
            inviteeName: 'Meena',
            inviteePhoneE164: '+919845012891',
            role: Role.owner,
          );
      expect(invite.id, 'BBBBBB');
      expect(invite.role, Role.owner);
      // The colliding invite is untouched.
      expect((await db.doc('invites/AAAAAA').get())['inviteeName'], 'Meena');
    });

    test('gives up after 5 colliding attempts', () async {
      for (final c in <String>[
        'AAAAAA',
        'BBBBBB',
        'CCCCCC',
        'DDDDDD',
        'EEEEEE',
      ]) {
        await OnboardingFixtures.invite(
          db,
          code: c,
          expiresAt: now.add(const Duration(days: 3)),
        );
      }
      final seq = <int>[
        for (final c in <String>[
          'AAAAAA',
          'BBBBBB',
          'CCCCCC',
          'DDDDDD',
          'EEEEEE',
        ])
          ...spell(c),
        ...spell('FFFFFF'),
      ];
      await expectLater(
        invites(random: SeqRandom(seq)).createInvite(
          cid: 'cid-a',
          uid: 'ravi',
          inviteeName: 'Meena',
          inviteePhoneE164: '+919845012891',
          role: Role.collector,
        ),
        throwsA(isA<UnknownFailure>()),
      );
      expect((await db.doc('invites/FFFFFF').get()).exists, isFalse);
    });

    test('rejects an empty name and a bad phone', () async {
      await expectLater(
        invites().createInvite(
          cid: 'cid-a',
          uid: 'ravi',
          inviteeName: '  ',
          inviteePhoneE164: '+919845012891',
          role: Role.collector,
        ),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        invites().createInvite(
          cid: 'cid-a',
          uid: 'ravi',
          inviteeName: 'Meena',
          inviteePhoneE164: '12345',
          role: Role.collector,
        ),
        throwsA(isA<ValidationFailure>()),
      );
      expect((await db.collection('invites').get()).docs, isEmpty);
    });
  });

  group('InviteRepository pending / revoke / resend', () {
    test(
      'watchPendingInvites: this company, pending only, newest first',
      () async {
        await OnboardingFixtures.invite(
          db,
          code: 'OLDER2',
          companyId: 'cid-a',
          expiresAt: now.add(const Duration(days: 2)),
        );
        await OnboardingFixtures.invite(
          db,
          code: 'NEWER2',
          companyId: 'cid-a',
          expiresAt: now.add(const Duration(days: 6)),
        );
        await OnboardingFixtures.invite(
          db,
          code: 'USED22',
          companyId: 'cid-a',
          status: 'accepted',
          expiresAt: now.add(const Duration(days: 6)),
        );
        await OnboardingFixtures.invite(
          db,
          code: 'OTHER2',
          companyId: 'cid-b',
          expiresAt: now.add(const Duration(days: 6)),
        );
        final list = await invites().watchPendingInvites('cid-a').first;
        expect(list.map((Invite i) => i.id), <String>['NEWER2', 'OLDER2']);
      },
    );

    test('revokeInvite sets status revoked only', () async {
      await OnboardingFixtures.invite(
        db,
        expiresAt: now.add(const Duration(days: 6)),
      );
      final before = (await db.doc('invites/K7Q2MD').get()).data()!;
      await invites().revokeInvite('K7Q2MD');
      final after = (await db.doc('invites/K7Q2MD').get()).data()!;
      expect(after['status'], 'revoked');
      expect(
        <String>{
          for (final k in after.keys)
            if (after[k] != before[k]) k,
        },
        <String>{'status'},
      );
    });

    test('resend of an unexpired invite returns the same invite', () async {
      await OnboardingFixtures.invite(
        db,
        companyId: 'cid-a',
        expiresAt: now.add(const Duration(days: 6)),
      );
      final repo = invites();
      final invite = (await repo.watchPendingInvites('cid-a').first).single;
      final again = await repo.resendInvite(invite, uid: 'ravi');
      expect(again.id, 'K7Q2MD');
      expect((await db.collection('invites').get()).docs, hasLength(1));
    });

    test(
      'resend of an expired invite creates a fresh code and revokes the old',
      () async {
        await OnboardingFixtures.invite(
          db,
          companyId: 'cid-a',
          role: 'owner',
          expiresAt: now.subtract(const Duration(hours: 1)),
        );
        final repo = invites(random: SeqRandom(spell('NEWC22')));
        final old = (await repo.watchPendingInvites('cid-a').first).single;
        final fresh = await repo.resendInvite(old, uid: 'ravi');
        expect(fresh.id, 'NEWC22');
        expect(fresh.role, Role.owner);
        expect(fresh.inviteeName, 'Meena');
        expect(fresh.inviteePhoneE164, '+919845012890');
        expect((await db.doc('invites/K7Q2MD').get())['status'], 'revoked');
        expect((await db.doc('invites/NEWC22').get())['status'], 'pending');
      },
    );
  });

  group('MembersRepository', () {
    late MembersRepository members;

    setUp(() async {
      members = MembersRepository(firestore: db);
      await OnboardingFixtures.membership(
        db,
        uid: 'meena',
        cid: 'cid-a',
        name: 'Sri Lakshmi Finance',
        role: 'collector',
      );
    });

    Future<List<dynamic>> owners() async =>
        (await db.doc('companies/cid-a').get())['ownerUids'] as List<dynamic>;

    test('watchMembers lists owners first', () async {
      final list = await members.watchMembers('cid-a').first;
      expect(list.map((Member m) => m.uid), <String>['ravi', 'meena']);
    });

    test('changeRole promote: member + ownerUids + membership role', () async {
      await members.changeRole('cid-a', 'meena', Role.owner);
      expect(
        (await db.doc('companies/cid-a/members/meena').get())['role'],
        'owner',
      );
      expect(await owners(), <String>['ravi', 'meena']);
      expect(
        (await db.doc('users/meena/memberships/cid-a').get())['role'],
        'owner',
      );
    });

    test('changeRole demote: arrayRemove from ownerUids', () async {
      await members.changeRole('cid-a', 'meena', Role.owner);
      await members.changeRole('cid-a', 'meena', Role.collector);
      expect(
        (await db.doc('companies/cid-a/members/meena').get())['role'],
        'collector',
      );
      expect(await owners(), <String>['ravi']);
      expect(
        (await db.doc('users/meena/memberships/cid-a').get())['role'],
        'collector',
      );
    });

    test('changeRole to the same role is a no-op', () async {
      await members.changeRole('cid-a', 'meena', Role.collector);
      expect(await owners(), <String>['ravi']);
    });

    test('removeMember collector: member + membership deleted', () async {
      await members.removeMember('cid-a', 'meena');
      expect(
        (await db.doc('companies/cid-a/members/meena').get()).exists,
        isFalse,
      );
      expect(
        (await db.doc('users/meena/memberships/cid-a').get()).exists,
        isFalse,
      );
      expect(await owners(), <String>['ravi']);
    });

    test('removeMember owner: also arrayRemove from ownerUids', () async {
      await members.changeRole('cid-a', 'meena', Role.owner);
      await members.removeMember('cid-a', 'meena');
      expect(await owners(), <String>['ravi']);
      expect(
        (await db.doc('companies/cid-a/members/meena').get()).exists,
        isFalse,
      );
    });

    test('last owner cannot be demoted or removed (client guard)', () async {
      await expectLater(
        members.changeRole('cid-a', 'ravi', Role.collector),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure f) => f.message,
            'message',
            LastOwnerGuard.message,
          ),
        ),
      );
      await expectLater(
        members.removeMember('cid-a', 'ravi'),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        (await db.doc('companies/cid-a/members/ravi').get())['role'],
        'owner',
      );
      expect(await owners(), <String>['ravi']);
    });

    test('a co-owner can be demoted once there are two owners', () async {
      await members.changeRole('cid-a', 'meena', Role.owner);
      await members.changeRole('cid-a', 'ravi', Role.collector);
      expect(await owners(), <String>['meena']);
    });

    test('LastOwnerGuard rules', () {
      expect(LastOwnerGuard.isLastOwner(<String>['a'], 'a'), isTrue);
      expect(LastOwnerGuard.isLastOwner(<String>['a', 'b'], 'a'), isFalse);
      expect(LastOwnerGuard.isLastOwner(<String>['a'], 'b'), isFalse);
      expect(
        LastOwnerGuard.canChangeRole(<String>['a'], 'a', Role.owner),
        isTrue,
      );
      expect(
        LastOwnerGuard.canChangeRole(<String>['a'], 'a', Role.collector),
        isFalse,
      );
      expect(LastOwnerGuard.canRemove(<String>['a'], 'a'), isFalse);
      expect(LastOwnerGuard.canRemove(<String>['a', 'b'], 'a'), isTrue);
    });
  });
}
