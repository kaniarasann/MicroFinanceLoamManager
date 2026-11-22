import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/core/firebase/firestore_paths.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import '../../helpers/model_fixtures.dart';

void main() {
  late FakeFirebaseFirestore db;
  late TypedRefs refs;

  setUp(() {
    db = FakeFirebaseFirestore();
    refs = TypedRefs(db);
  });

  Future<Map<String, dynamic>> raw(String path) async =>
      (await db.doc(path).get()).data()!;

  /// Writes [value] through the typed ref, reads it back, and checks the raw
  /// document: no `id` key and every timestamp field stored as `Timestamp`.
  Future<T> roundTrip<T>(
    DocumentReference<T> ref,
    T value,
    Set<String> timestampKeys,
  ) async {
    await ref.set(value);
    final body = await raw(ref.path);
    expect(body.containsKey('id'), isFalse, reason: 'id must not be stored');
    for (final key in timestampKeys) {
      expect(body[key], isA<Timestamp>(), reason: '$key should be Timestamp');
    }
    final read = (await ref.get()).data();
    expect(read, isNotNull);
    return read as T;
  }

  test('AppUser', () async {
    final v = Fixtures.appUser;
    final read = await roundTrip(refs.user(v.id), v, <String>{'createdAt'});
    expect(read, v);
    final body = await raw(FirestorePaths.user(v.id));
    expect((body['createdAt'] as Timestamp).toDate().toUtc(), Fixtures.t0);
  });

  test('Membership', () async {
    final v = Fixtures.membership;
    final read = await roundTrip(
      refs.membership('uid-owner', v.id),
      v,
      <String>{'joinedAt'},
    );
    expect(read, v);
    final list = await refs.memberships('uid-owner').get();
    expect(list.docs.single.data(), v);
  });

  test('UserSettings: updatedAt is server-stamped, prefs nested', () async {
    final v = Fixtures.userSettings;
    final read = await roundTrip(refs.userSettings(v.id), v, <String>{
      'updatedAt',
    });
    expect(read.updatedAt, isNotNull);
    expect(read.updatedAt!.isUtc, isTrue);
    expect(read, v.copyWith(updatedAt: read.updatedAt));
    final body = await raw(FirestorePaths.userSettings(v.id));
    expect(body['notifications'], isA<Map<String, dynamic>>());
    expect(
      (body['notifications'] as Map<String, dynamic>)['digestTime'],
      '07:30',
    );
  });

  test('UserSettings.defaults() with null updatedAt writes', () async {
    final v = UserSettings.defaults('uid-new');
    final read = await roundTrip(refs.userSettings(v.id), v, <String>{
      'updatedAt',
    });
    expect(read.copyWith(updatedAt: null), v);
  });

  test('Company', () async {
    final v = Fixtures.company;
    final read = await roundTrip(refs.company(v.id), v, <String>{'createdAt'});
    expect(read, v);
    final body = await raw(FirestorePaths.company(v.id));
    expect(body['ownerUids'], <String>['uid-owner']);
  });

  test('Member', () async {
    final v = Fixtures.member;
    final read = await roundTrip(refs.member('cmp-1', v.id), v, <String>{
      'joinedAt',
    });
    expect(read, v);
    final body = await raw(FirestorePaths.member('cmp-1', v.id));
    expect(body['role'], 'collector');
  });

  test('Invite: every timestamp incl. optional acceptedAt', () async {
    final v = Fixtures.invite;
    final read = await roundTrip(refs.invite(v.id), v, <String>{
      'createdAt',
      'expiresAt',
      'acceptedAt',
    });
    expect(read, v);
    expect(read.isExpired(Fixtures.t1), isFalse);
  });

  test('Invite: null acceptedAt stays null', () async {
    final v = Fixtures.invite.copyWith(
      status: InviteStatus.pending,
      acceptedBy: null,
      acceptedAt: null,
    );
    await refs.invite(v.id).set(v);
    final body = await raw(FirestorePaths.invite(v.id));
    expect(body['acceptedAt'], isNull);
    expect((await refs.invite(v.id).get()).data(), v);
  });

  test('Borrower', () async {
    final v = Fixtures.borrower;
    final read = await roundTrip(refs.borrower('cmp-1', v.id), v, <String>{
      'createdAt',
      'updatedAt',
    });
    expect(read, v);
  });

  test('Contract: money as int paise, civil dates as strings', () async {
    final v = Fixtures.contract;
    final read = await roundTrip(refs.contract('cmp-1', v.id), v, <String>{
      'createdAt',
      'updatedAt',
      'closedAt',
    });
    expect(read, v);
    final body = await raw(FirestorePaths.contract('cmp-1', v.id));
    expect(body['sanctionedPaise'], 10000000);
    expect(body['firstDueDate'], '2026-11-24');
    expect(body['status'], 'rolledOver');
  });

  test('Contract: FieldValue.increment on totalPaidPaise reads back', () async {
    final v = Fixtures.contract;
    final ref = refs.contract('cmp-1', v.id);
    await ref.set(v);
    await db.doc(ref.path).update(<String, Object?>{
      'totalPaidPaise': FieldValue.increment(1000000),
    });
    final read = (await ref.get()).data()!;
    expect(read.totalPaid.paise, 4000000);
  });

  test('Installment, and querying via typed collection', () async {
    final v = Fixtures.installment;
    final read = await roundTrip(refs.installment('cmp-1', v.id), v, <String>{
      'createdAt',
    });
    expect(read, v);
    final q = await refs
        .installments('cmp-1')
        .where('dueDate', isEqualTo: '2027-02-02')
        .get();
    expect(q.docs.single.data(), v);
  });

  test('LedgerTransaction: recordedAt is always the server time', () async {
    final v = Fixtures.transaction;
    final read = await roundTrip(refs.transaction('cmp-1', v.id), v, <String>{
      'recordedAt',
      'clientRecordedAt',
    });
    expect(read.recordedAt, isNotNull);
    expect(read.recordedAt, isNot(Fixtures.t1));
    expect(read.clientRecordedAt, Fixtures.t0);
    expect(read, v.copyWith(recordedAt: read.recordedAt));
    final body = await raw(FirestorePaths.transaction('cmp-1', v.id));
    expect(body['amountPaise'], 2500050);
    expect(body['type'], 'rolloverSettlement');
  });

  test('LedgerTransaction: pending (null) recordedAt falls back', () async {
    // Simulates a cached read of an offline write whose server timestamp
    // has not resolved yet.
    final v = Fixtures.transaction;
    final body = ModelCodecs.transaction.toFirestore(v, null)
      ..['recordedAt'] = null;
    await db.doc(FirestorePaths.transaction('cmp-1', v.id)).set(body);
    final read = (await refs.transaction('cmp-1', v.id).get()).data()!;
    expect(read.recordedAt, isNull);
    expect(read.effectiveRecordedAt, Fixtures.t0);
  });

  test('toFirestore emits serverTimestamp and Timestamp values', () {
    final body = ModelCodecs.transaction.toFirestore(
      Fixtures.transaction,
      null,
    );
    expect(body.containsKey('id'), isFalse);
    expect(body['recordedAt'], FieldValue.serverTimestamp());
    expect(body['clientRecordedAt'], Timestamp.fromDate(Fixtures.t0));
  });

  test('typed refs use FirestorePaths', () {
    expect(refs.company('c').path, FirestorePaths.company('c'));
    expect(refs.companies().path, FirestorePaths.companiesCollection);
    expect(refs.members('c').path, FirestorePaths.members('c'));
    expect(refs.borrowers('c').path, FirestorePaths.borrowers('c'));
    expect(refs.contracts('c').path, FirestorePaths.contracts('c'));
    expect(refs.transactions('c').path, FirestorePaths.transactions('c'));
    expect(refs.invites().path, FirestorePaths.invitesCollection);
    expect(refs.user('u').path, FirestorePaths.user('u'));
  });

  test('reading a missing document yields null data', () async {
    final snap = await refs.borrower('cmp-1', 'nope').get();
    expect(snap.exists, isFalse);
    expect(snap.data(), isNull);
  });
}
