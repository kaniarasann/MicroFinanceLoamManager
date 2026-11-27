/// Static Firestore path builders. Every tenant path is under
/// `companies/{cid}`; never build paths by hand elsewhere.
abstract final class FirestorePaths {
  // Top level.
  static const String companiesCollection = 'companies';
  static const String invitesCollection = 'invites';
  static const String usersCollection = 'users';
  static const String userSettingsCollection = 'user_settings';

  static String company(String cid) => '$companiesCollection/$cid';

  static String members(String cid) => '${company(cid)}/members';
  static String member(String cid, String uid) => '${members(cid)}/$uid';

  static String borrowers(String cid) => '${company(cid)}/borrowers';
  static String borrower(String cid, String borrowerId) =>
      '${borrowers(cid)}/$borrowerId';

  static String contracts(String cid) => '${company(cid)}/contracts';
  static String contract(String cid, String contractId) =>
      '${contracts(cid)}/$contractId';

  /// Onboarding sync lists: one doc per onboarded contract (doc id =
  /// contract id) holding the payments written after batch 1.
  static String onboardingQueues(String cid) =>
      '${company(cid)}/onboardingQueues';
  static String onboardingQueue(String cid, String contractId) =>
      '${onboardingQueues(cid)}/$contractId';

  static String installments(String cid) => '${company(cid)}/installments';
  static String installment(String cid, String installmentId) =>
      '${installments(cid)}/$installmentId';

  static String transactions(String cid) => '${company(cid)}/transactions';
  static String transaction(String cid, String txId) =>
      '${transactions(cid)}/$txId';

  static String invite(String code) => '$invitesCollection/$code';

  static String user(String uid) => '$usersCollection/$uid';
  static String memberships(String uid) => '${user(uid)}/memberships';
  static String membership(String uid, String cid) =>
      '${memberships(uid)}/$cid';

  static String userSettings(String uid) => '$userSettingsCollection/$uid';
}
