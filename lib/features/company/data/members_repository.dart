import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/firebase/converters.dart';
import '../../../domain/models/models.dart';

/// Client mirror of the rules' last-owner guard (`soleOwner` in
/// `firebase/firestore.rules`). The rules are the real enforcement.
abstract final class LastOwnerGuard {
  /// Shown next to the disabled demote / remove actions.
  static const String message = "Last owner can't be removed";

  /// [uid] is the only entry of [ownerUids].
  static bool isLastOwner(List<String> ownerUids, String uid) =>
      ownerUids.length == 1 && ownerUids.first == uid;

  /// Whether [uid] may be changed to [newRole].
  static bool canChangeRole(List<String> ownerUids, String uid, Role newRole) =>
      newRole == Role.owner || !isLastOwner(ownerUids, uid);

  /// Whether [uid] may be removed from the company.
  static bool canRemove(List<String> ownerUids, String uid) =>
      !isLastOwner(ownerUids, uid);
}

/// The company's member list, role changes and removals (owner).
///
/// Role change and removal are single WriteBatches, so they queue offline
/// like ledger writes.
class MembersRepository {
  MembersRepository({
    required FirebaseFirestore firestore,
    this.commitGrace = const Duration(seconds: 8),
  }) : _db = firestore,
       _refs = TypedRefs(firestore);

  final FirebaseFirestore _db;
  final TypedRefs _refs;

  /// How long to wait for the server ack before treating a batch as queued.
  final Duration commitGrace;

  /// `companies/{cid}/members`: owners first, then by name.
  Stream<List<Member>> watchMembers(String cid) =>
      _refs.members(cid).snapshots().map((QuerySnapshot<Member> s) {
        final list = <Member>[for (final d in s.docs) d.data()]
          ..sort((Member a, Member b) {
            if (a.role != b.role) return a.role == Role.owner ? -1 : 1;
            return a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );
          });
        return list;
      });

  /// Changes [uid]'s role in [cid] in ONE batch:
  /// - `companies/{cid}/members/{uid}.role`;
  /// - `companies/{cid}.ownerUids` arrayUnion (promote) / arrayRemove (demote);
  /// - `users/{uid}/memberships/{cid}.role`.
  ///
  /// Throws [ValidationFailure] for the last owner (client guard).
  Future<void> changeRole(String cid, String uid, Role newRole) async {
    try {
      final company = await _company(cid);
      final member = (await _refs.member(cid, uid).get()).data();
      if (member == null) throw const NotFoundFailure();
      if (member.role == newRole) return;
      if (!LastOwnerGuard.canChangeRole(company.ownerUids, uid, newRole)) {
        throw const ValidationFailure('role', LastOwnerGuard.message);
      }
      final batch = _db.batch()
        ..update(_refs.member(cid, uid), <String, Object?>{
          'role': newRole.name,
        })
        ..update(_refs.company(cid), <String, Object?>{
          'ownerUids': newRole == Role.owner
              ? FieldValue.arrayUnion(<String>[uid])
              : FieldValue.arrayRemove(<String>[uid]),
        })
        ..update(_refs.membership(uid, cid), <String, Object?>{
          'role': newRole.name,
        });
      await _commit(batch, 'role change');
    } on Object catch (e, st) {
      throw mapFirebaseException(e, st);
    }
  }

  /// Removes [uid] from [cid] in ONE batch:
  /// - delete `companies/{cid}/members/{uid}`;
  /// - arrayRemove from `companies/{cid}.ownerUids` if they were an owner;
  /// - delete `users/{uid}/memberships/{cid}`.
  ///
  /// Throws [ValidationFailure] for the last owner (client guard).
  Future<void> removeMember(String cid, String uid) async {
    try {
      final company = await _company(cid);
      if (!LastOwnerGuard.canRemove(company.ownerUids, uid)) {
        throw const ValidationFailure('member', LastOwnerGuard.message);
      }
      final member = (await _refs.member(cid, uid).get()).data();
      final wasOwner =
          member?.role == Role.owner || company.ownerUids.contains(uid);
      final batch = _db.batch()..delete(_refs.member(cid, uid));
      if (wasOwner) {
        batch.update(_refs.company(cid), <String, Object?>{
          'ownerUids': FieldValue.arrayRemove(<String>[uid]),
        });
      }
      batch.delete(_refs.membership(uid, cid));
      await _commit(batch, 'member removal');
    } on Object catch (e, st) {
      throw mapFirebaseException(e, st);
    }
  }

  Future<Company> _company(String cid) async {
    final company = (await _refs.company(cid).get()).data();
    if (company == null) throw const NotFoundFailure();
    return company;
  }

  Future<void> _commit(WriteBatch batch, String what) async {
    try {
      await batch.commit().timeout(commitGrace);
    } on TimeoutException {
      developer.log('$what queued (no server ack yet)', name: 'members');
    }
  }
}
