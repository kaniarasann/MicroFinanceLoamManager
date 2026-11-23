import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/firebase/converters.dart';
import '../../../core/phone/indian_phone.dart';
import '../../../core/time/ist_clock.dart';
import '../../../core/validation/onboarding_validators.dart';
import '../../../domain/models/models.dart';
import 'user_settings_repository.dart';

/// One event from [CompanyRepository.watchMemberDoc].
sealed class MemberDocEvent {
  const MemberDocEvent();
}

/// A snapshot of the member doc ([member] null = the snapshot says it does
/// not exist).
final class MemberDocSnapshot extends MemberDocEvent {
  const MemberDocSnapshot(this.member, {required this.serverConfirmed});

  final Member? member;

  /// From the server (`isFromCache == false`) with no pending local writes.
  final bool serverConfirmed;
}

/// The listener (or a server read) failed with permission-denied.
final class MemberDocDenied extends MemberDocEvent {
  const MemberDocDenied();
}

/// Companies, the caller's member doc and their membership index.
class CompanyRepository {
  CompanyRepository({
    required FirebaseFirestore firestore,
    required Clock clock,
    Uuid uuid = const Uuid(),
    this.commitGrace = const Duration(seconds: 8),
  }) : _db = firestore,
       _refs = TypedRefs(firestore),
       _clock = clock,
       _uuid = uuid;

  final FirebaseFirestore _db;
  final TypedRefs _refs;
  final Clock _clock;
  final Uuid _uuid;

  /// How long [registerCompany] waits for the server ack. After that the
  /// batch is treated as queued offline (it is already in the local cache).
  final Duration commitGrace;

  /// Register company: ONE WriteBatch with
  /// `companies/{cid}` + `companies/{cid}/members/{uid}` (owner) +
  /// `users/{uid}/memberships/{cid}` + `user_settings/{uid}.activeCompanyId`.
  ///
  /// Validates first (throws [ValidationFailure]). Phones are accepted in
  /// any common form and stored as E.164. Returns the new company id
  /// ([companyId] when given, so the caller can track it before the ack).
  Future<String> registerCompany({
    required String uid,
    required String name,
    String? city,
    String? phoneE164,
    required String ownerDisplayName,
    String? ownerPhoneE164,
    String? companyId,
  }) async {
    final trimmedName = name.trim();
    final nameError = OnboardingValidators.companyName(trimmedName);
    if (nameError != null) throw ValidationFailure('name', nameError);
    final displayName = ownerDisplayName.trim();
    final displayError = OnboardingValidators.displayName(displayName);
    if (displayError != null) {
      throw ValidationFailure('ownerDisplayName', displayError);
    }
    final companyPhone = _optionalPhone(phoneE164, 'phone');
    final ownerPhone = _optionalPhone(ownerPhoneE164, 'ownerPhone');
    final trimmedCity = city?.trim();

    final cid = companyId ?? _uuid.v4();
    final now = _clock.nowIst().toUtc();

    final company = Company(
      id: cid,
      name: trimmedName,
      nameLower: trimmedName.toLowerCase(),
      city: (trimmedCity == null || trimmedCity.isEmpty) ? null : trimmedCity,
      phoneE164: companyPhone,
      ownerUids: <String>[uid],
      nextLoanNo: 0,
      createdBy: uid,
      createdAt: now,
    );
    final member = Member(
      id: uid,
      uid: uid,
      role: Role.owner,
      displayName: displayName,
      phoneE164: ownerPhone,
      joinedAt: now,
    );
    final membership = Membership(
      id: cid,
      companyId: cid,
      companyName: trimmedName,
      role: Role.owner,
      joinedAt: now,
    );

    final batch = _db.batch()
      ..set(_refs.company(cid), company)
      ..set(_refs.member(cid, uid), member)
      ..set(_refs.membership(uid, cid), membership)
      ..set(
        UserSettingsRepository.rawRef(_db, uid),
        UserSettingsRepository.activeCompanyPatch(cid),
        SetOptions(merge: true),
      );

    try {
      // Offline-tolerant: the batch is applied to the local cache at once
      // and queued. Only wait a short while for the server ack, so a rules
      // rejection while online still surfaces.
      await batch.commit().timeout(commitGrace);
    } on TimeoutException {
      developer.log(
        'Register batch queued (no server ack yet)',
        name: 'onboarding',
      );
    } on Object catch (e, st) {
      throw mapFirebaseException(e, st);
    }
    return cid;
  }

  /// The caller's companies (membership index), oldest first.
  Stream<List<Membership>> watchMemberships(String uid) =>
      _refs.memberships(uid).snapshots().map((QuerySnapshot<Membership> s) {
        final list = <Membership>[for (final d in s.docs) d.data()]
          ..sort((Membership a, Membership b) {
            final byDate = a.joinedAt.compareTo(b.joinedAt);
            return byDate != 0
                ? byDate
                : a.companyName.compareTo(b.companyName);
          });
        return list;
      });

  /// `companies/{cid}`, or null when it does not exist / is not readable.
  Stream<Company?> watchCompany(String cid) => _refs
      .company(cid)
      .snapshots()
      .map((DocumentSnapshot<Company> s) => s.exists ? s.data() : null)
      .transform(_permissionDeniedAsNull<Company>());

  /// Raw events for the caller's member doc in [cid], with snapshot
  /// metadata. The repository never decides "removed": that needs session
  /// history and lives in `watchMemberAccess` (company layer).
  ///
  /// - [MemberDocSnapshot.serverConfirmed] is true only for a snapshot that
  ///   came from the server with no local pending writes overlaid.
  /// - permission-denied becomes a [MemberDocDenied] event (the SDK then
  ///   closes the listener; the caller re-attaches).
  ///
  /// There is deliberately no client API that deletes the caller's own
  /// membership docs as part of removed-member handling.
  Stream<MemberDocEvent> watchMemberDoc(String cid, String uid) => _refs
      .member(cid, uid)
      .snapshots(includeMetadataChanges: true)
      .map<MemberDocEvent>(
        (DocumentSnapshot<Member> s) => MemberDocSnapshot(
          s.exists ? s.data() : null,
          serverConfirmed:
              !s.metadata.isFromCache && !s.metadata.hasPendingWrites,
        ),
      )
      .transform(
        StreamTransformer<MemberDocEvent, MemberDocEvent>.fromHandlers(
          handleError:
              (Object error, StackTrace st, EventSink<MemberDocEvent> sink) {
                if (_isPermissionDenied(error)) {
                  sink.add(const MemberDocDenied());
                } else {
                  sink.addError(error, st);
                }
              },
        ),
      );

  /// One server read of the caller's member doc in [cid]. Returns null when
  /// the server cannot be reached (offline, timeout, other errors), so the
  /// caller never mistakes "unknown" for "removed".
  Future<MemberDocEvent?> fetchMemberDocFromServer(
    String cid,
    String uid,
  ) async {
    try {
      final s = await _refs
          .member(cid, uid)
          .get(const GetOptions(source: Source.server))
          .timeout(commitGrace);
      return MemberDocSnapshot(
        s.exists ? s.data() : null,
        serverConfirmed: !s.metadata.isFromCache,
      );
    } on Object catch (e) {
      if (_isPermissionDenied(e)) return const MemberDocDenied();
      developer.log('Member server check failed', name: 'onboarding', error: e);
      return null;
    }
  }

  static bool _isPermissionDenied(Object error) =>
      error is FirebaseException && error.code == 'permission-denied';

  static String? _optionalPhone(String? input, String field) {
    if (input == null || input.trim().isEmpty) return null;
    final e164 = IndianPhone.toE164(input);
    if (e164 == null) {
      throw ValidationFailure(field, IndianPhone.invalidMessage);
    }
    return e164;
  }

  static StreamTransformer<T?, T?> _permissionDeniedAsNull<T>() =>
      StreamTransformer<T?, T?>.fromHandlers(
        handleError: (Object error, StackTrace st, EventSink<T?> sink) {
          if (_isPermissionDenied(error)) {
            sink.add(null);
          } else {
            sink.addError(error, st);
          }
        },
      );
}
