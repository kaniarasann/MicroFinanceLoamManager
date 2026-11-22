import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/models/models.dart';
import '../../auth/application/session_controller.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../../onboarding/data/invite_repository.dart';

part 'company_providers.g.dart';

/// Whether the signed-in user can enter the company shell.
enum CompanyGate {
  /// Memberships not loaded yet.
  loading,

  /// No membership: register or join.
  none,

  /// An active company is selected.
  ready,
}

/// The signed-in uid (null when signed out).
@Riverpod(keepAlive: true)
String? currentUid(Ref ref) => ref.watch(
  sessionControllerProvider.select((SessionState s) => s.user?.uid),
);

/// Raw `users/{uid}/memberships` stream.
@Riverpod(keepAlive: true)
Stream<List<Membership>> membershipsStream(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream<List<Membership>>.value(const <Membership>[]);
  return ref.watch(companyRepositoryProvider).watchMemberships(uid);
}

/// Companies this user lost access to during this session. They are hidden
/// even if a stale cached membership doc still lists them.
@Riverpod(keepAlive: true)
class RemovedCompanies extends _$RemovedCompanies {
  @override
  Set<String> build() {
    ref.watch(currentUidProvider); // reset per user
    return const <String>{};
  }

  void add(String cid) {
    if (!state.contains(cid)) state = <String>{...state, cid};
  }

  void forget(String cid) {
    if (state.contains(cid)) {
      state = <String>{...state}..remove(cid);
    }
  }
}

/// The user's companies (minus [RemovedCompanies]), oldest first.
@Riverpod(keepAlive: true)
AsyncValue<List<Membership>> memberships(Ref ref) {
  final removed = ref.watch(removedCompaniesProvider);
  return ref
      .watch(membershipsStreamProvider)
      .whenData(
        (List<Membership> list) => <Membership>[
          for (final m in list)
            if (!removed.contains(m.id)) m,
        ],
      );
}

/// `user_settings/{uid}` (null until the doc exists).
@Riverpod(keepAlive: true)
Stream<UserSettings?> userSettings(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream<UserSettings?>.value(null);
  return ref.watch(userSettingsRepositoryProvider).watch(uid);
}

/// Pure rule: the stored active company if it is still a membership,
/// otherwise the first membership, otherwise null.
String? resolveActiveCompanyId(List<Membership> memberships, String? stored) {
  if (stored != null && memberships.any((Membership m) => m.id == stored)) {
    return stored;
  }
  return memberships.firstOrNull?.id;
}

/// The active company id: `user_settings.activeCompanyId`, falling back to
/// the first membership. Loading until memberships (and settings) load.
@Riverpod(keepAlive: true)
AsyncValue<String?> activeCompanyId(Ref ref) {
  final ms = ref.watch(membershipsProvider);
  final settings = ref.watch(userSettingsProvider);
  final list = ms.value;
  if (list == null) {
    if (ms.hasError) return AsyncError<String?>(ms.error!, ms.stackTrace!);
    return const AsyncLoading<String?>();
  }
  // A settings read error only disables the stored preference.
  if (!settings.hasValue && !settings.hasError) {
    return const AsyncLoading<String?>();
  }
  return AsyncData<String?>(
    resolveActiveCompanyId(list, settings.value?.activeCompanyId),
  );
}

/// Drives the router's company guard.
@Riverpod(keepAlive: true)
CompanyGate companyGate(Ref ref) {
  if (ref.watch(currentUidProvider) == null) return CompanyGate.loading;
  final active = ref.watch(activeCompanyIdProvider);
  if (active.hasError) return CompanyGate.none;
  if (!active.hasValue) return CompanyGate.loading;
  return active.value == null ? CompanyGate.none : CompanyGate.ready;
}

/// The active company's membership index doc (name + role, offline-safe).
@Riverpod(keepAlive: true)
Membership? activeMembership(Ref ref) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) return null;
  return ref
      .watch(membershipsProvider)
      .value
      ?.where((Membership m) => m.id == cid)
      .firstOrNull;
}

/// `companies/{activeCompanyId}`.
@Riverpod(keepAlive: true)
Stream<Company?> activeCompany(Ref ref) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) return Stream<Company?>.value(null);
  return ref.watch(companyRepositoryProvider).watchCompany(cid);
}

/// One emission of the caller's member doc in company [cid].
final class MemberWatch {
  const MemberWatch(this.cid, this.member);

  final String cid;

  /// Null = confirmed gone (server says not-exists, or permission-denied).
  final Member? member;
}

/// The caller's member doc in the active company, tagged with its cid.
@Riverpod(keepAlive: true)
Stream<MemberWatch?> activeMemberWatch(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (uid == null || cid == null) return Stream<MemberWatch?>.value(null);
  return ref
      .watch(companyRepositoryProvider)
      .watchMember(cid, uid)
      .map((Member? m) => MemberWatch(cid, m));
}

/// The caller's member doc in the active company (null while unknown).
@Riverpod(keepAlive: true)
Member? currentMember(Ref ref) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  final watch = ref.watch(activeMemberWatchProvider).value;
  if (watch == null || watch.cid != cid) return null;
  return watch.member;
}

/// The caller's role in the active company. The member doc is the source of
/// truth (rules check it); the membership index is the offline fallback.
@Riverpod(keepAlive: true)
Role? currentRole(Ref ref) =>
    ref.watch(currentMemberProvider)?.role ??
    ref.watch(activeMembershipProvider)?.role;

/// Display name of the active company.
@Riverpod(keepAlive: true)
String? activeCompanyName(Ref ref) =>
    ref.watch(activeCompanyProvider).value?.name ??
    ref.watch(activeMembershipProvider)?.companyName;

/// A one-time user message from the company layer (e.g. lost access). The
/// root widget shows it as a snackbar and [consume]s it.
@Riverpod(keepAlive: true)
class CompanyNotice extends _$CompanyNotice {
  @override
  String? build() => null;

  void show(String message) => state = message;

  void consume() => state = null;
}

/// "You no longer have access to {company}".
String lostAccessMessage(String companyName) =>
    'You no longer have access to $companyName';

/// Removed-member handling. Watched by the root widget.
///
/// - The active company's member doc is confirmed gone (server not-exists or
///   permission-denied): hide that company ([RemovedCompanies]) and clean up
///   the user's own membership doc.
/// - The active company disappears from the memberships (an owner deleted
///   it, or the step above): show [lostAccessMessage] once, switch
///   `user_settings.activeCompanyId` to the next membership (or null, which
///   routes to onboarding), and schedule a Firestore cache clear for the
///   next cold start.
@Riverpod(keepAlive: true)
class CompanyAccessGuard extends _$CompanyAccessGuard {
  final Map<String, String> _names = <String, String>{};
  final Set<String> _handled = <String>{};

  @override
  void build() {
    ref
      ..listen<AsyncValue<List<Membership>>>(
        membershipsStreamProvider,
        (_, AsyncValue<List<Membership>> next) => _remember(next.value),
        fireImmediately: true,
      )
      ..listen<AsyncValue<MemberWatch?>>(activeMemberWatchProvider, (
        _,
        AsyncValue<MemberWatch?> next,
      ) {
        final w = next.value;
        if (w == null || w.member != null) return;
        if (w.cid != ref.read(activeCompanyIdProvider).value) return;
        // Side effects run after this provider frame (they rebuild
        // memberships, which is mid-rebuild right now).
        scheduleMicrotask(() => _onMemberGone(w.cid));
      })
      ..listen<AsyncValue<String?>>(activeCompanyIdProvider, (
        AsyncValue<String?>? prev,
        AsyncValue<String?> next,
      ) {
        final before = prev?.value;
        if (before == null || !next.hasValue || next.value == before) return;
        if (ref.read(currentUidProvider) == null) return; // signed out
        final raw = ref.read(membershipsStreamProvider).value;
        if (raw == null) return;
        final removed = ref.read(removedCompaniesProvider);
        final stillMember =
            raw.any((Membership m) => m.id == before) &&
            !removed.contains(before);
        if (!stillMember) {
          final after = next.value;
          scheduleMicrotask(() => unawaited(_onLostAccess(before, after)));
        }
      });
  }

  void _remember(List<Membership>? list) {
    for (final m in list ?? const <Membership>[]) {
      _names[m.id] = m.companyName;
    }
  }

  void _onMemberGone(String cid) {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    ref.read(removedCompaniesProvider.notifier).add(cid);
    unawaited(
      ref.read(companyRepositoryProvider).deleteOwnMembership(uid, cid),
    );
  }

  Future<void> _onLostAccess(String cid, String? nextCid) async {
    if (!_handled.add(cid)) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    ref.read(removedCompaniesProvider.notifier).add(cid);
    ref
        .read(companyNoticeProvider.notifier)
        .show(lostAccessMessage(_names[cid] ?? 'this company'));
    try {
      await ref
          .read(userSettingsRepositoryProvider)
          .setActiveCompanyId(uid, nextCid);
    } on Object catch (e) {
      developer.log('Switch after removal failed', name: 'company', error: e);
    }
    unawaited(
      ref.read(companyRepositoryProvider).deleteOwnMembership(uid, cid),
    );
    try {
      await ref.read(cacheResetFlagProvider).schedule();
    } on Object catch (e) {
      developer.log('Cache reset flag failed', name: 'company', error: e);
    }
  }
}

/// Company use-cases called by the onboarding screens and the switcher.
@Riverpod(keepAlive: true)
CompanyActions companyActions(Ref ref) => CompanyActions(ref);

class CompanyActions {
  CompanyActions(this._ref);

  final Ref _ref;

  /// How long to wait for the new company to become active locally.
  static const Duration activationWait = Duration(seconds: 5);

  String get _uid {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }

  /// Registers a company (one WriteBatch) and waits until it is active.
  Future<String> registerCompany({
    required String name,
    String? city,
    String? phone,
    required String ownerDisplayName,
    String? ownerPhone,
  }) async {
    final cid = await _ref
        .read(companyRepositoryProvider)
        .registerCompany(
          uid: _uid,
          name: name,
          city: city,
          phoneE164: phone,
          ownerDisplayName: ownerDisplayName,
          ownerPhoneE164: ownerPhone,
        );
    await _awaitActive(cid);
    return cid;
  }

  Future<InvitePreview> lookupInvite(String code) =>
      _ref.read(inviteRepositoryProvider).lookup(code);

  /// Accepts an invite (online transaction), then makes it the active
  /// company (a separate, queued write).
  Future<InvitePreview> acceptInvite(String code) async {
    final uid = _uid;
    final preview = await _ref
        .read(inviteRepositoryProvider)
        .accept(code, uid: uid);
    _ref.read(removedCompaniesProvider.notifier).forget(preview.companyId);
    await _ref
        .read(userSettingsRepositoryProvider)
        .setActiveCompanyId(uid, preview.companyId);
    await _awaitActive(preview.companyId);
    return preview;
  }

  /// Switches the active company (`user_settings.activeCompanyId`).
  Future<void> switchTo(String cid) async {
    await _ref
        .read(userSettingsRepositoryProvider)
        .setActiveCompanyId(_uid, cid);
  }

  Future<void> _awaitActive(String cid) async {
    final done = Completer<void>();
    final sub = _ref.listen<AsyncValue<String?>>(activeCompanyIdProvider, (
      _,
      AsyncValue<String?> next,
    ) {
      if (next.value == cid && !done.isCompleted) done.complete();
    }, fireImmediately: true);
    try {
      await done.future.timeout(activationWait, onTimeout: () {});
    } finally {
      sub.close();
    }
  }
}
