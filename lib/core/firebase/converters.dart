import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/models.dart';
import 'firestore_paths.dart';

/// Data-layer bridge between Firestore documents and the pure-Dart domain
/// models.
///
/// Domain JSON stores timestamps as ISO-8601 UTC strings. In Firestore they
/// are `Timestamp`s. This codec does the mapping, injects the doc id on read
/// and strips nothing else (the models already exclude `id` from `toJson`).
final class ModelCodec<T> {
  const ModelCodec({
    required this.fromJson,
    required this.toJson,
    required this.timestampFields,
    this.serverTimestampFields = const <String>{},
  });

  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T value) toJson;

  /// Top-level keys whose domain value is a `DateTime` (ISO string in JSON)
  /// and whose Firestore value is a `Timestamp`.
  final Set<String> timestampFields;

  /// Server-owned timestamps: always written as
  /// `FieldValue.serverTimestamp()`, whatever the model holds. A cached read
  /// of a pending write sees `null` here, so the matching model field is
  /// nullable.
  final Set<String> serverTimestampFields;

  /// `withConverter` `fromFirestore` callback.
  T fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Document ${snapshot.reference.path} has no data');
    }
    return fromJson(<String, dynamic>{
      for (final entry in data.entries) entry.key: _readValue(entry.value),
      'id': snapshot.id,
    });
  }

  /// `withConverter` `toFirestore` callback.
  Map<String, Object?> toFirestore(T value, SetOptions? options) {
    final json = Map<String, Object?>.of(toJson(value))..remove('id');
    for (final field in timestampFields) {
      final raw = json[field];
      if (raw is String) {
        json[field] = Timestamp.fromDate(DateTime.parse(raw));
      }
    }
    for (final field in serverTimestampFields) {
      json[field] = FieldValue.serverTimestamp();
    }
    return json;
  }

  static Object? _readValue(Object? value) => switch (value) {
    Timestamp() => value.toDate().toUtc().toIso8601String(),
    DateTime() => value.toUtc().toIso8601String(),
    _ => value,
  };
}

/// One codec per collection.
abstract final class ModelCodecs {
  static final ModelCodec<AppUser> appUser = ModelCodec<AppUser>(
    fromJson: AppUser.fromJson,
    toJson: (AppUser v) => v.toJson(),
    timestampFields: const <String>{'createdAt'},
  );

  static final ModelCodec<Membership> membership = ModelCodec<Membership>(
    fromJson: Membership.fromJson,
    toJson: (Membership v) => v.toJson(),
    timestampFields: const <String>{'joinedAt'},
  );

  static final ModelCodec<UserSettings> userSettings = ModelCodec<UserSettings>(
    fromJson: UserSettings.fromJson,
    toJson: (UserSettings v) => v.toJson(),
    timestampFields: const <String>{'updatedAt'},
    serverTimestampFields: const <String>{'updatedAt'},
  );

  static final ModelCodec<Company> company = ModelCodec<Company>(
    fromJson: Company.fromJson,
    toJson: (Company v) => v.toJson(),
    timestampFields: const <String>{'createdAt'},
  );

  static final ModelCodec<Member> member = ModelCodec<Member>(
    fromJson: Member.fromJson,
    toJson: (Member v) => v.toJson(),
    timestampFields: const <String>{'joinedAt'},
  );

  static final ModelCodec<Invite> invite = ModelCodec<Invite>(
    fromJson: Invite.fromJson,
    toJson: (Invite v) => v.toJson(),
    timestampFields: const <String>{'createdAt', 'expiresAt', 'acceptedAt'},
  );

  static final ModelCodec<Borrower> borrower = ModelCodec<Borrower>(
    fromJson: Borrower.fromJson,
    toJson: (Borrower v) => v.toJson(),
    timestampFields: const <String>{'createdAt', 'updatedAt'},
  );

  static final ModelCodec<Contract> contract = ModelCodec<Contract>(
    fromJson: Contract.fromJson,
    toJson: (Contract v) => v.toJson(),
    timestampFields: const <String>{'createdAt', 'updatedAt', 'closedAt'},
  );

  static final ModelCodec<Installment> installment = ModelCodec<Installment>(
    fromJson: Installment.fromJson,
    toJson: (Installment v) => v.toJson(),
    timestampFields: const <String>{'createdAt'},
  );

  /// `recordedAt` is always the server time (rules: `== request.time`).
  static final ModelCodec<LedgerTransaction> transaction =
      ModelCodec<LedgerTransaction>(
        fromJson: LedgerTransaction.fromJson,
        toJson: (LedgerTransaction v) => v.toJson(),
        timestampFields: const <String>{'recordedAt', 'clientRecordedAt'},
        serverTimestampFields: const <String>{'recordedAt'},
      );
}

extension _TypedCollection on CollectionReference<Map<String, dynamic>> {
  CollectionReference<T> typed<T>(ModelCodec<T> codec) => withConverter<T>(
    fromFirestore: codec.fromFirestore,
    toFirestore: codec.toFirestore,
  );
}

extension _TypedDocument on DocumentReference<Map<String, dynamic>> {
  DocumentReference<T> typed<T>(ModelCodec<T> codec) => withConverter<T>(
    fromFirestore: codec.fromFirestore,
    toFirestore: codec.toFirestore,
  );
}

/// Typed collection / document references built from [FirestorePaths].
/// Repositories use these instead of raw paths.
final class TypedRefs {
  const TypedRefs(this.db);

  final FirebaseFirestore db;

  CollectionReference<T> _col<T>(String path, ModelCodec<T> codec) =>
      db.collection(path).typed(codec);

  DocumentReference<T> _doc<T>(String path, ModelCodec<T> codec) =>
      db.doc(path).typed(codec);

  // users/{uid}
  DocumentReference<AppUser> user(String uid) =>
      _doc(FirestorePaths.user(uid), ModelCodecs.appUser);

  CollectionReference<Membership> memberships(String uid) =>
      _col(FirestorePaths.memberships(uid), ModelCodecs.membership);
  DocumentReference<Membership> membership(String uid, String cid) =>
      _doc(FirestorePaths.membership(uid, cid), ModelCodecs.membership);

  // user_settings/{uid}
  DocumentReference<UserSettings> userSettings(String uid) =>
      _doc(FirestorePaths.userSettings(uid), ModelCodecs.userSettings);

  // companies/{cid}
  CollectionReference<Company> companies() =>
      _col(FirestorePaths.companiesCollection, ModelCodecs.company);
  DocumentReference<Company> company(String cid) =>
      _doc(FirestorePaths.company(cid), ModelCodecs.company);

  CollectionReference<Member> members(String cid) =>
      _col(FirestorePaths.members(cid), ModelCodecs.member);
  DocumentReference<Member> member(String cid, String uid) =>
      _doc(FirestorePaths.member(cid, uid), ModelCodecs.member);

  CollectionReference<Borrower> borrowers(String cid) =>
      _col(FirestorePaths.borrowers(cid), ModelCodecs.borrower);
  DocumentReference<Borrower> borrower(String cid, String borrowerId) =>
      _doc(FirestorePaths.borrower(cid, borrowerId), ModelCodecs.borrower);

  CollectionReference<Contract> contracts(String cid) =>
      _col(FirestorePaths.contracts(cid), ModelCodecs.contract);
  DocumentReference<Contract> contract(String cid, String contractId) =>
      _doc(FirestorePaths.contract(cid, contractId), ModelCodecs.contract);

  CollectionReference<Installment> installments(String cid) =>
      _col(FirestorePaths.installments(cid), ModelCodecs.installment);
  DocumentReference<Installment> installment(String cid, String id) =>
      _doc(FirestorePaths.installment(cid, id), ModelCodecs.installment);

  CollectionReference<LedgerTransaction> transactions(String cid) =>
      _col(FirestorePaths.transactions(cid), ModelCodecs.transaction);
  DocumentReference<LedgerTransaction> transaction(String cid, String txId) =>
      _doc(FirestorePaths.transaction(cid, txId), ModelCodecs.transaction);

  // invites/{code}
  CollectionReference<Invite> invites() =>
      _col(FirestorePaths.invitesCollection, ModelCodecs.invite);
  DocumentReference<Invite> invite(String code) =>
      _doc(FirestorePaths.invite(code), ModelCodecs.invite);
}
