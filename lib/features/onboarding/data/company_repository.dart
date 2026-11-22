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
  /// any common form and stored as E.164. Returns the new company id.
  Future<String> registerCompany({
    required String uid,
    required String name,
    String? city,
    String? phoneE164,
    required String ownerDisplayName,
    String? ownerPhoneE164,
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

    final cid = _uuid.v4();
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

  /// The caller's member doc in [cid].
  ///
  /// Emits null when the doc is confirmed gone: a **server** snapshot that
  /// does not exist, or permission-denied (rules: not a member any more).
  /// A cache-only "does not exist" is skipped, so an offline cold start
  /// with an empty cache never looks like a removal.
  Stream<Member?> watchMember(String cid, String uid) => _refs
      .member(cid, uid)
      .snapshots(includeMetadataChanges: true)
      .where(
        (DocumentSnapshot<Member> s) => s.exists || !s.metadata.isFromCache,
      )
      .map((DocumentSnapshot<Member> s) => s.exists ? s.data() : null)
      .transform(_permissionDeniedAsNull<Member>());

  /// Best-effort removal of the caller's own membership index doc after
  /// they lost access to [cid] (rules allow self-delete). Never throws.
  Future<void> deleteOwnMembership(String uid, String cid) async {
    try {
      await _refs.membership(uid, cid).delete().timeout(commitGrace);
    } on Object catch (e) {
      developer.log('Membership cleanup failed', name: 'onboarding', error: e);
    }
  }

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
          if (error is FirebaseException && error.code == 'permission-denied') {
            sink.add(null);
          } else {
            sink.addError(error, st);
          }
        },
      );
}
