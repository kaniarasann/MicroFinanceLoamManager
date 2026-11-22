import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/firebase/converters.dart';
import '../../../core/phone/indian_phone.dart';
import '../../../core/time/ist_clock.dart';
import '../../../core/validation/onboarding_validators.dart';
import '../../../domain/models/models.dart';

/// What the join screen shows before the user accepts.
final class InvitePreview {
  const InvitePreview({
    required this.code,
    required this.companyId,
    required this.companyName,
    required this.role,
    required this.invitedByName,
    required this.inviteeName,
    required this.inviteePhoneE164,
    required this.expiresAt,
    this.companyCity,
  });

  factory InvitePreview.fromInvite(Invite invite) => InvitePreview(
    code: invite.id,
    companyId: invite.companyId,
    companyName: invite.companyName,
    companyCity: invite.companyCity,
    role: invite.role,
    invitedByName: invite.createdByName,
    inviteeName: invite.inviteeName,
    inviteePhoneE164: invite.inviteePhoneE164,
    expiresAt: invite.expiresAt,
  );

  final String code;
  final String companyId;
  final String companyName;
  final String? companyCity;
  final Role role;
  final String invitedByName;
  final String inviteeName;
  final String inviteePhoneE164;
  final DateTime expiresAt;
}

/// Invites: create / list / revoke / resend (owner) and lookup / the
/// online-only accept transaction (invitee).
class InviteRepository {
  InviteRepository({
    required FirebaseFirestore firestore,
    required Clock clock,
    Random? random,
    this.timeout = const Duration(seconds: 20),
    this.commitGrace = const Duration(seconds: 8),
  }) : _db = firestore,
       _refs = TypedRefs(firestore),
       _clock = clock,
       _random = random ?? Random.secure();

  final FirebaseFirestore _db;
  final TypedRefs _refs;
  final Clock _clock;
  final Random _random;

  /// Collision-checked code attempts before [createInvite] gives up.
  static const int maxCodeAttempts = 5;

  /// How long [revokeInvite] waits for the server ack before treating the
  /// update as queued offline.
  final Duration commitGrace;

  /// Network deadline for lookup / accept; past it the user is told to go
  /// online.
  final Duration timeout;

  DateTime get _now => _clock.nowIst().toUtc();

  /// Server-only lookup of `invites/{code}`.
  ///
  /// Throws [ValidationFailure] (bad format), [NotFoundFailure],
  /// [ExpiredFailure], [InviteUnavailableFailure] (accepted / revoked) or
  /// [OfflineRequiredFailure].
  Future<InvitePreview> lookup(String rawCode) async {
    final code = _checkedCode(rawCode);
    final DocumentSnapshot<Invite> snap;
    try {
      snap = await _refs
          .invite(code)
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);
    } on TimeoutException {
      throw const OfflineRequiredFailure();
    } on Object catch (e, st) {
      throw mapFirebaseException(e, st);
    }
    return InvitePreview.fromInvite(_acceptable(snap));
  }

  /// Accepts [rawCode] for the signed-in [uid] in ONE online transaction:
  /// - read the invite (pending, not expired);
  /// - create `companies/{cid}/members/{uid}` with `inviteCode`;
  /// - create `users/{uid}/memberships/{cid}`;
  /// - mark the invite accepted (acceptedBy, acceptedAt = server time);
  /// - owner invites also `arrayUnion` the uid into `companies/{cid}.ownerUids`
  ///   (the rules require it in the same transaction).
  ///
  /// [displayName] / [phoneE164] default to the invite's invitee details.
  /// Returns the accepted invite's preview (company id and name).
  Future<InvitePreview> accept(
    String rawCode, {
    required String uid,
    String? displayName,
    String? phoneE164,
  }) async {
    final code = _checkedCode(rawCode);
    try {
      return await _db
          .runTransaction<InvitePreview>((Transaction tx) async {
            final snap = await tx.get(_refs.invite(code));
            final invite = _acceptable(snap);
            final now = _now;
            final cid = invite.companyId;
            final name = displayName?.trim();
            tx
              ..set(
                _refs.member(cid, uid),
                Member(
                  id: uid,
                  uid: uid,
                  role: invite.role,
                  displayName: (name == null || name.isEmpty)
                      ? invite.inviteeName
                      : name,
                  phoneE164: phoneE164 ?? invite.inviteePhoneE164,
                  inviteCode: code,
                  invitedBy: invite.createdBy,
                  joinedAt: now,
                ),
              )
              ..set(
                _refs.membership(uid, cid),
                Membership(
                  id: cid,
                  companyId: cid,
                  companyName: invite.companyName,
                  role: invite.role,
                  joinedAt: now,
                ),
              )
              ..update(_refs.invite(code), <String, Object?>{
                'status': InviteStatus.accepted.name,
                'acceptedBy': uid,
                'acceptedAt': FieldValue.serverTimestamp(),
              });
            if (invite.role == Role.owner) {
              tx.update(_refs.company(cid), <String, Object?>{
                'ownerUids': FieldValue.arrayUnion(<String>[uid]),
              });
            }
            return InvitePreview.fromInvite(invite);
          })
          .timeout(timeout);
    } on TimeoutException {
      throw const OfflineRequiredFailure();
    } on Object catch (e, st) {
      throw mapFirebaseException(e, st);
    }
  }

  /// A random 6-character code from [InviteCode.alphabet].
  String generateCode() {
    const alphabet = InviteCode.alphabet;
    final buffer = StringBuffer();
    for (var i = 0; i < InviteCode.length; i++) {
      buffer.write(alphabet[_random.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  /// Creates `invites/{code}` for company [cid] (owner, **online only**).
  ///
  /// - validates the invitee name and +91 mobile ([ValidationFailure]);
  /// - reads the company (name, city) and the caller's member doc (their
  ///   display name) from the server, which also proves we are online;
  /// - picks a code with `Random.secure()` and checks it is unused with a
  ///   server `get`, retrying up to [maxCodeAttempts] times;
  /// - writes the invite: pending, `expiresAt = now + 7 days`.
  ///
  /// Throws [OfflineRequiredFailure] without a connection.
  Future<Invite> createInvite({
    required String cid,
    required String uid,
    required String inviteeName,
    required String inviteePhoneE164,
    required Role role,
  }) async {
    final name = inviteeName.trim();
    final nameError = OnboardingValidators.inviteeName(name);
    if (nameError != null) throw ValidationFailure('inviteeName', nameError);
    final phone = IndianPhone.toE164(inviteePhoneE164);
    if (phone == null) {
      throw const ValidationFailure('inviteePhone', IndianPhone.invalidMessage);
    }
    try {
      return await _createInvite(
        cid: cid,
        uid: uid,
        name: name,
        phone: phone,
        role: role,
      ).timeout(timeout);
    } on TimeoutException {
      throw const OfflineRequiredFailure();
    } on Object catch (e, st) {
      throw mapFirebaseException(e, st);
    }
  }

  Future<Invite> _createInvite({
    required String cid,
    required String uid,
    required String name,
    required String phone,
    required Role role,
  }) async {
    const server = GetOptions(source: Source.server);
    final company = (await _refs.company(cid).get(server)).data();
    if (company == null) throw const NotFoundFailure();
    final me = (await _refs.member(cid, uid).get(server)).data();
    if (me == null) throw const PermissionDeniedFailure();

    String? code;
    for (var attempt = 0; attempt < maxCodeAttempts; attempt++) {
      final candidate = generateCode();
      final existing = await _refs.invite(candidate).get(server);
      if (!existing.exists) {
        code = candidate;
        break;
      }
    }
    if (code == null) {
      throw const UnknownFailure('invite-code-collision');
    }
    final now = _now;
    final invite = Invite(
      id: code,
      companyId: cid,
      companyName: company.name,
      companyCity: company.city,
      role: role,
      inviteeName: name,
      inviteePhoneE164: phone,
      createdBy: uid,
      createdByName: me.displayName,
      createdAt: now,
      expiresAt: now.add(Invite.validity),
    );
    await _refs.invite(code).set(invite);
    return invite;
  }

  /// The company's pending invites (owner only; rules allow this list only
  /// when constrained by `companyId`), newest first. Includes expired
  /// pending invites, which the screen offers to resend.
  Stream<List<Invite>> watchPendingInvites(String cid) => _refs
      .invites()
      .where('companyId', isEqualTo: cid)
      .where('status', isEqualTo: InviteStatus.pending.name)
      .snapshots()
      .map(
        (QuerySnapshot<Invite> s) => <Invite>[for (final d in s.docs) d.data()]
          ..sort((Invite a, Invite b) => b.createdAt.compareTo(a.createdAt)),
      );

  /// Revokes a pending invite (owner). Offline-tolerant: the update is
  /// queued if the server does not answer within [commitGrace].
  Future<void> revokeInvite(String code) async {
    try {
      await _refs
          .invite(code)
          .update(<String, Object?>{'status': InviteStatus.revoked.name})
          .timeout(commitGrace);
    } on TimeoutException {
      developer.log('Invite revoke queued', name: 'invites');
    } on Object catch (e, st) {
      throw mapFirebaseException(e, st);
    }
  }

  /// Resend: an unexpired invite is returned as is (the screen re-opens its
  /// share message). An expired one is replaced: a fresh code with the same
  /// invitee and role is created (online), then the old code is revoked.
  Future<Invite> resendInvite(Invite invite, {required String uid}) async {
    if (!invite.isExpired(_now)) return invite;
    final fresh = await createInvite(
      cid: invite.companyId,
      uid: uid,
      inviteeName: invite.inviteeName,
      inviteePhoneE164: invite.inviteePhoneE164,
      role: invite.role,
    );
    await revokeInvite(invite.id);
    return fresh;
  }

  static String _checkedCode(String raw) {
    final code = raw.trim().toUpperCase();
    if (!InviteCode.isValid(code)) {
      throw const ValidationFailure(
        'code',
        'Enter the 6-character code from your invite.',
      );
    }
    return code;
  }

  Invite _acceptable(DocumentSnapshot<Invite> snap) {
    final invite = snap.exists ? snap.data() : null;
    if (invite == null) throw const NotFoundFailure();
    if (invite.status != InviteStatus.pending) {
      throw const InviteUnavailableFailure();
    }
    if (invite.isExpired(_now)) throw const ExpiredFailure();
    return invite;
  }
}
