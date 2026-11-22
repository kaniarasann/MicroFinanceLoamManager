import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../domain/models/models.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../data/invite_share_service.dart';
import '../data/members_repository.dart';
import 'company_providers.dart';

part 'members_providers.g.dart';

@Riverpod(keepAlive: true)
MembersRepository membersRepository(Ref ref) =>
    MembersRepository(firestore: ref.watch(firestoreProvider));

@Riverpod(keepAlive: true)
InviteShareService inviteShareService(Ref ref) => InviteShareService();

/// The active company's members (owners first, then by name).
@riverpod
Stream<List<Member>> companyMembers(Ref ref) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) return Stream<List<Member>>.value(const <Member>[]);
  return ref.watch(membersRepositoryProvider).watchMembers(cid);
}

/// The active company's pending invites. Owners only: collectors are not
/// allowed to list invites, so they get an empty list without a query.
@riverpod
Stream<List<Invite>> pendingInvites(Ref ref) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  final role = ref.watch(currentRoleProvider);
  if (cid == null || role != Role.owner) {
    return Stream<List<Invite>>.value(const <Invite>[]);
  }
  return ref.watch(inviteRepositoryProvider).watchPendingInvites(cid);
}

/// `companies/{active}.ownerUids` (empty until the company loads).
@riverpod
List<String> activeOwnerUids(Ref ref) =>
    ref.watch(activeCompanyProvider).value?.ownerUids ?? const <String>[];

/// Members & invites use-cases for the active company (owner).
@Riverpod(keepAlive: true)
MembersActions membersActions(Ref ref) => MembersActions(ref);

class MembersActions {
  MembersActions(this._ref);

  final Ref _ref;

  String get _uid {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }

  String get _cid {
    final cid = _ref.read(activeCompanyIdProvider).value;
    if (cid == null) throw StateError('No active company');
    return cid;
  }

  Future<Invite> createInvite({
    required String inviteeName,
    required String inviteePhone,
    required Role role,
  }) => _ref
      .read(inviteRepositoryProvider)
      .createInvite(
        cid: _cid,
        uid: _uid,
        inviteeName: inviteeName,
        inviteePhoneE164: inviteePhone,
        role: role,
      );

  Future<void> revokeInvite(String code) =>
      _ref.read(inviteRepositoryProvider).revokeInvite(code);

  Future<Invite> resendInvite(Invite invite) =>
      _ref.read(inviteRepositoryProvider).resendInvite(invite, uid: _uid);

  Future<void> changeRole(String uid, Role role) =>
      _ref.read(membersRepositoryProvider).changeRole(_cid, uid, role);

  Future<void> removeMember(String uid) =>
      _ref.read(membersRepositoryProvider).removeMember(_cid, uid);
}
