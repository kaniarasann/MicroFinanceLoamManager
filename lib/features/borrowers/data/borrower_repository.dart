import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/firebase/converters.dart';
import '../../../core/firebase/write_outcome.dart';
import '../../../core/phone/indian_phone.dart';
import '../../../core/time/ist_clock.dart';
import '../../../core/validation/borrower_validators.dart';
import '../../../domain/models/models.dart';

export '../../../core/firebase/write_outcome.dart';

/// The result of [BorrowerRepository.createBorrower].
final class BorrowerCreated {
  const BorrowerCreated(this.id, this.outcome);

  final String id;
  final WriteOutcome outcome;
}

/// `companies/{cid}/borrowers`. Owner-only writes (mirrored by the rules:
/// create/update if owner, `createdBy == uid`, `createdBy` / `createdAt`
/// never change, delete never; archive instead).
///
/// Every write is a single document write: it lands in the local cache at
/// once and queues offline. The call waits up to [commitGrace] for the
/// server ack, so a rules rejection while online still surfaces.
class BorrowerRepository {
  BorrowerRepository({
    required FirebaseFirestore firestore,
    required Clock clock,
    Uuid uuid = const Uuid(),
    this.commitGrace = const Duration(seconds: 2),
  }) : _refs = TypedRefs(firestore),
       _clock = clock,
       _uuid = uuid;

  final TypedRefs _refs;
  final Clock _clock;
  final Uuid _uuid;

  /// How long a write waits for the server ack before it counts as queued.
  final Duration commitGrace;

  /// Non-archived borrowers, ordered by `nameLower`
  /// (index: archived ASC, nameLower ASC).
  Stream<List<Borrower>> watchBorrowers(String cid) => _refs
      .borrowers(cid)
      .where('archived', isEqualTo: false)
      .orderBy('nameLower')
      .snapshots()
      .map(
        (QuerySnapshot<Borrower> s) => <Borrower>[
          for (final d in s.docs) d.data(),
        ],
      );

  /// One borrower (null when missing).
  Stream<Borrower?> watchBorrower(String cid, String id) => _refs
      .borrower(cid, id)
      .snapshots()
      .map((DocumentSnapshot<Borrower> s) => s.exists ? s.data() : null);

  /// Creates a borrower with a client uuid v4 id. Validates first (throws
  /// [ValidationFailure]); [phone] may be in any common form and is stored
  /// as E.164.
  Future<BorrowerCreated> createBorrower({
    required String cid,
    required String name,
    required String phone,
    String? locality,
    String? notes,
    required String createdBy,
  }) async {
    final fields = _validated(name, phone);
    final id = _uuid.v4();
    final now = _clock.nowIst().toUtc();
    final borrower = Borrower(
      id: id,
      name: fields.name,
      nameLower: fields.name.toLowerCase(),
      phoneE164: fields.phoneE164,
      locality: _optional(locality),
      notes: _optional(notes),
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
    );
    final outcome = await _commit(
      () => _refs.borrower(cid, id).set(borrower),
      'borrower create',
    );
    return BorrowerCreated(id, outcome);
  }

  /// Updates the editable fields. `createdBy` / `createdAt` are untouched.
  Future<WriteOutcome> updateBorrower({
    required String cid,
    required String id,
    required String name,
    required String phone,
    String? locality,
    String? notes,
  }) {
    final fields = _validated(name, phone);
    return _commit(
      () => _refs.borrower(cid, id).update(<String, Object?>{
        'name': fields.name,
        'nameLower': fields.name.toLowerCase(),
        'phoneE164': fields.phoneE164,
        'locality': _optional(locality),
        'notes': _optional(notes),
        'updatedAt': _nowStamp(),
      }),
      'borrower update',
    );
  }

  /// Hides a borrower from the list. Nothing is ever deleted.
  Future<WriteOutcome> archiveBorrower(String cid, String id) => _commit(
    () => _refs.borrower(cid, id).update(<String, Object?>{
      'archived': true,
      'updatedAt': _nowStamp(),
    }),
    'borrower archive',
  );

  Timestamp _nowStamp() => Timestamp.fromDate(_clock.nowIst().toUtc());

  ({String name, String phoneE164}) _validated(String name, String phone) {
    final trimmed = name.trim();
    final nameError = BorrowerValidators.name(trimmed);
    if (nameError != null) throw ValidationFailure('name', nameError);
    final e164 = IndianPhone.toE164(phone);
    if (e164 == null) {
      throw const ValidationFailure('phone', IndianPhone.invalidMessage);
    }
    return (name: trimmed, phoneE164: e164);
  }

  static String? _optional(String? value) {
    final v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<WriteOutcome> _commit(Future<void> Function() write, String what) =>
      awaitServerAck(write(), commitGrace, what);
}
