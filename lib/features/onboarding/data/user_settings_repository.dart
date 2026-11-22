import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/firebase/converters.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../domain/models/user_settings.dart';

/// `user_settings/{uid}`: the active company (other prefs come later).
class UserSettingsRepository {
  UserSettingsRepository({required FirebaseFirestore firestore})
    : _db = firestore,
      _refs = TypedRefs(firestore);

  final FirebaseFirestore _db;
  final TypedRefs _refs;

  /// Untyped ref for partial merges. The typed codec writes the whole model,
  /// which would reset notification prefs on an existing doc.
  static DocumentReference<Map<String, dynamic>> rawRef(
    FirebaseFirestore db,
    String uid,
  ) => db.doc(FirestorePaths.userSettings(uid));

  /// The merge patch that sets (or clears) the active company.
  static Map<String, dynamic> activeCompanyPatch(String? cid) =>
      <String, dynamic>{
        'activeCompanyId': cid,
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': 1,
      };

  Future<UserSettings?> get(String uid) async {
    try {
      final s = await _refs.userSettings(uid).get();
      return s.exists ? s.data() : null;
    } on Object catch (e, st) {
      throw mapFirebaseException(e, st);
    }
  }

  /// Null while the doc does not exist yet. Listens on the same untyped ref
  /// the merge writes use, decoding with the [ModelCodecs.userSettings]
  /// codec.
  Stream<UserSettings?> watch(String uid) => rawRef(_db, uid).snapshots().map(
    (DocumentSnapshot<Map<String, dynamic>> s) =>
        s.exists ? ModelCodecs.userSettings.fromFirestore(s, null) : null,
  );

  /// Merge-writes `activeCompanyId`. Returns once the write is in the local
  /// cache; the server ack is not awaited, so it queues offline.
  Future<void> setActiveCompanyId(String uid, String? cid) async {
    final Future<void> write;
    try {
      write = rawRef(
        _db,
        uid,
      ).set(activeCompanyPatch(cid), SetOptions(merge: true));
    } on Object catch (e, st) {
      throw mapFirebaseException(e, st);
    }
    unawaited(
      write.then<void>(
        (_) {},
        onError: (Object e) => developer.log(
          'activeCompanyId write failed',
          name: 'onboarding',
          error: e,
        ),
      ),
    );
  }
}
