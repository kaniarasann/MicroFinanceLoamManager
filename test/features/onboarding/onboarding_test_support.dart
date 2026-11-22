import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Raw Firestore fixtures for the onboarding tests (same shapes the rules
/// tests use).
abstract final class OnboardingFixtures {
  /// Seeds `invites/{code}`.
  static Future<void> invite(
    FakeFirebaseFirestore db, {
    String code = 'K7Q2MD',
    String companyId = 'cid-a',
    String companyName = 'Sri Lakshmi Finance',
    String? companyCity = 'Chennai',
    String role = 'collector',
    String status = 'pending',
    required DateTime expiresAt,
    String createdBy = 'uid-owner',
    String createdByName = 'Ravi Kumar',
  }) => db.doc('invites/$code').set(<String, Object?>{
    'companyId': companyId,
    'companyName': companyName,
    'companyCity': companyCity,
    'role': role,
    'inviteeName': 'Meena',
    'inviteePhoneE164': '+919845012890',
    'createdBy': createdBy,
    'createdByName': createdByName,
    'createdAt': Timestamp.fromDate(
      expiresAt.subtract(const Duration(days: 7)),
    ),
    'expiresAt': Timestamp.fromDate(expiresAt),
    'status': status,
    'acceptedBy': null,
    'acceptedAt': null,
    'schemaVersion': 1,
  });

  /// Seeds `companies/{cid}`.
  static Future<void> company(
    FakeFirebaseFirestore db, {
    String cid = 'cid-a',
    String name = 'Sri Lakshmi Finance',
    List<String> owners = const <String>['uid-owner'],
  }) => db.doc('companies/$cid').set(<String, Object?>{
    'name': name,
    'nameLower': name.toLowerCase(),
    'city': 'Chennai',
    'phoneE164': null,
    'ownerUids': owners,
    'nextLoanNo': 0,
    'createdBy': owners.first,
    'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1)),
    'schemaVersion': 1,
  });

  /// Seeds a member doc + the matching membership index doc.
  static Future<void> membership(
    FakeFirebaseFirestore db, {
    required String uid,
    required String cid,
    required String name,
    String role = 'owner',
    DateTime? joinedAt,
    bool withMemberDoc = true,
  }) async {
    final joined = Timestamp.fromDate(joinedAt ?? DateTime.utc(2026, 11, 1));
    await db.doc('users/$uid/memberships/$cid').set(<String, Object?>{
      'companyId': cid,
      'companyName': name,
      'role': role,
      'joinedAt': joined,
      'schemaVersion': 1,
    });
    if (withMemberDoc) {
      await db.doc('companies/$cid/members/$uid').set(<String, Object?>{
        'uid': uid,
        'role': role,
        'displayName': uid,
        'phoneE164': null,
        'status': 'active',
        'inviteCode': null,
        'invitedBy': null,
        'joinedAt': joined,
        'schemaVersion': 1,
      });
    }
  }
}
