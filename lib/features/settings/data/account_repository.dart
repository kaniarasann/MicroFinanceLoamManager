import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../application/account_exit.dart';

/// Server reads and the single WriteBatch behind "Delete account".
///
/// Account deletion is an online-only flow: every read is
/// `Source.server` (so a stale cache can never decide who is the last
/// owner) and the batch is awaited until the server acknowledges it.
/// Financial records are never touched: transactions, contracts,
/// installments and borrowers keep `recordedBy` / `recordedByName`.
class AccountRepository {
  AccountRepository({
    required FirebaseFirestore firestore,
    this.ackTimeout = const Duration(seconds: 20),
  }) : _db = firestore;

  final FirebaseFirestore _db;

  /// How long to wait for the server to acknowledge the deletion batch.
  final Duration ackTimeout;

  static const GetOptions _server = GetOptions(source: Source.server);

  /// One [CompanyExitFacts] per `users/{uid}/memberships` doc.
  Future<List<CompanyExitFacts>> loadExitFacts(String uid) async {
    try {
      final memberships = await _db
          .collection(FirestorePaths.memberships(uid))
          .get(_server);
      final out = <CompanyExitFacts>[];
      for (final m in memberships.docs) {
        out.add(await _facts(uid, m.id, m.data()));
      }
      return out;
    } on Object catch (e, st) {
      throw mapFirebaseException(e, st);
    }
  }

  Future<CompanyExitFacts> _facts(
    String uid,
    String cid,
    Map<String, dynamic> membership,
  ) async {
    final name = membership['companyName'] as String? ?? 'Company';
    final DocumentSnapshot<Map<String, dynamic>> company;
    try {
      company = await _db.doc(FirestorePaths.company(cid)).get(_server);
    } on FirebaseException catch (e) {
      // No longer a member (removed earlier): only the index doc is left.
      if (e.code == 'permission-denied') {
        return CompanyExitFacts(companyId: cid, companyName: name);
      }
      rethrow;
    }
    final data = company.data();
    if (data == null) {
      return CompanyExitFacts(companyId: cid, companyName: name);
    }
    final owners = <String>[
      for (final o in (data['ownerUids'] as List<dynamic>? ?? <dynamic>[]))
        '$o',
    ];
    var otherMembers = 0;
    var invites = const <String>[];
    if (owners.length == 1 && owners.first == uid) {
      final members = await _db
          .collection(FirestorePaths.members(cid))
          .get(_server);
      otherMembers = members.docs.where((d) => d.id != uid).length;
      final pending = await _db
          .collection(FirestorePaths.invitesCollection)
          .where('companyId', isEqualTo: cid)
          .where('status', isEqualTo: 'pending')
          .get(_server);
      invites = <String>[for (final d in pending.docs) d.id];
    }
    return CompanyExitFacts(
      companyId: cid,
      companyName: data['name'] as String? ?? name,
      readable: true,
      ownerUids: owners,
      otherMembers: otherMembers,
      pendingInviteCodes: invites,
    );
  }

  /// Commits [plan] in ONE batch and waits for the server ack:
  /// - leave: delete `members/{uid}` and the membership index doc;
  /// - leave as one of several owners: also `arrayRemove` from `ownerUids`;
  /// - close (sole owner, no other member): `ownerUids: []`, `closedAt`,
  ///   `closedBy`, revoke pending invites, delete the member and index docs;
  /// - stale index doc: delete it;
  /// - then `user_settings/{uid}` and `users/{uid}`.
  ///
  /// Throws [AckPendingFailure] (an [OfflineRequiredFailure]) when the ack
  /// does not arrive in time: the batch is queued and still lands later.
  Future<void> commitExit(String uid, AccountExitPlan plan) async {
    if (plan.isBlocked) {
      throw const ValidationFailure(
        'account',
        'Hand over ownership before deleting your account.',
      );
    }
    final batch = _db.batch();
    for (final e in plan.exits) {
      final cid = e.facts.companyId;
      final member = _db.doc(FirestorePaths.member(cid, uid));
      final membership = _db.doc(FirestorePaths.membership(uid, cid));
      switch (e.action) {
        case ExitAction.stale:
          batch.delete(membership);
        case ExitAction.leave:
          batch
            ..delete(member)
            ..delete(membership);
        case ExitAction.leaveOwner:
          batch
            ..update(_db.doc(FirestorePaths.company(cid)), <String, Object?>{
              'ownerUids': FieldValue.arrayRemove(<String>[uid]),
            })
            ..delete(member)
            ..delete(membership);
        case ExitAction.close:
          batch.update(_db.doc(FirestorePaths.company(cid)), <String, Object?>{
            'ownerUids': <String>[],
            'closedAt': FieldValue.serverTimestamp(),
            'closedBy': uid,
          });
          for (final code in e.facts.pendingInviteCodes) {
            batch.update(
              _db.doc(FirestorePaths.invite(code)),
              <String, Object?>{'status': 'revoked'},
            );
          }
          batch
            ..delete(member)
            ..delete(membership);
        case ExitAction.blocked:
          break; // unreachable: isBlocked checked above
      }
    }
    batch
      ..delete(_db.doc(FirestorePaths.userSettings(uid)))
      ..delete(_db.doc(FirestorePaths.user(uid)));
    final commit = batch.commit();
    try {
      await commit.timeout(ackTimeout);
    } on TimeoutException {
      // Queued, not failed: the batch lands when the device is back online.
      // The caller keeps [AckPendingFailure.ack] to finish the deletion then.
      throw AckPendingFailure(
        commit.catchError((Object e, StackTrace st) {
          throw mapFirebaseException(e, st);
        }),
      );
    } on Object catch (e, st) {
      throw mapFirebaseException(e, st);
    }
  }
}
