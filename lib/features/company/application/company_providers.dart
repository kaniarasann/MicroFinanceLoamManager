import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/models.dart';
import '../../auth/application/session_controller.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../../onboarding/data/company_repository.dart';
import '../../onboarding/data/invite_repository.dart';
import 'member_access_monitor.dart';

export 'member_access_monitor.dart' show MemberWatch, RetryBackoff;

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

/// Company ids whose member doc the server confirmed (exists, not from
/// cache, no pending writes) in this app session. Reset per user. Removal
/// can only be concluded for a company in this set.
@Riverpod(keepAlive: true)
Set<String> serverConfirmedMembers(Ref ref) {
  ref.watch(currentUidProvider);
  return <String>{};
}

/// Re-attach delays for the member-doc listener (overridden in tests).
@Riverpod(keepAlive: true)
RetryBackoff memberRetryBackoff(Ref ref) => defaultMemberRetryBackoff;

/// Companies whose register batch is still waiting for the server ack. The
/// member-doc listener is not attached for them until the ack (or the
/// offline timeout), so the first server evaluation can never be a
/// "not a member yet" denial.
@Riverpod(keepAlive: true)
class PendingRegistrations extends _$PendingRegistrations {
  @override
  Set<String> build() {
    ref.watch(currentUidProvider);
    return const <String>{};
  }

  void add(String cid) => state = <String>{...state, cid};

  void remove(String cid) {
    if (state.contains(cid)) state = <String>{...state}..remove(cid);
  }
}

/// The caller's member doc in the active company, tagged with its cid.
/// See [watchMemberAccess] for the (conservative) removal rule.
@Riverpod(keepAlive: true)
Stream<MemberWatch?> activeMemberWatch(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (uid == null || cid == null) return Stream<MemberWatch?>.value(null);
  if (ref.watch(pendingRegistrationsProvider).contains(cid)) {
    // Unknown for now; the role falls back to the membership index.
    return Stream<MemberWatch?>.value(MemberWatch(cid, null));
  }
  final repo = ref.watch(companyRepositoryProvider);
  return watchMemberAccess(
    cid: cid,
    attach: () => repo.watchMemberDoc(cid, uid),
    confirmed: ref.watch(serverConfirmedMembersProvider),
    backoff: ref.watch(memberRetryBackoffProvider),
  );
}

/// The caller's member doc in the active company (null while unknown).
@Riverpod(keepAlive: true)
Member? currentMember(Ref ref) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  final watch = ref.watch(activeMemberWatchProvider).value;
  if (watch == null || watch.cid != cid || watch.removed) return null;
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

/// True while this user is deleting their account. The removed-member guard
/// and the notification scheduler stand down, so the deletion batch is not
/// answered with "lost access" side effects (which would re-create
/// `user_settings`).
@Riverpod(keepAlive: true)
class AccountDeletionInProgress extends _$AccountDeletionInProgress {
  @override
  bool build() {
    ref.watch(currentUidProvider);
    return false;
  }

  void start() => state = true;

  void finish() => state = false;
}

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
/// A removal is acted on ONLY when it is server-confirmed (see
/// [watchMemberAccess]): the server confirmed the member doc earlier in
/// this session and later says it is gone / denies access.
///
/// - The active company's member watch reports a confirmed removal.
/// - Or the active company drops out of the membership index (the owner's
///   removeMember batch deletes it together with the member doc) AND the
///   company was server-confirmed this session AND a fresh server read of
///   the member doc says not-exists / permission-denied. An offline or
///   failed check is "unknown" and does nothing.
///
/// On a confirmed removal the guard only: hides the company for this
/// session ([RemovedCompanies]), shows [lostAccessMessage] once, switches
/// `user_settings.activeCompanyId` to the next membership (or null, which
/// routes to onboarding) and schedules a Firestore cache clear. It NEVER
/// deletes `users/{uid}/memberships/*`: the owner's removeMember batch is
/// the only thing that deletes another user's membership doc.
@Riverpod(keepAlive: true)
class CompanyAccessGuard extends _$CompanyAccessGuard {
  final Map<String, String> _names = <String, String>{};

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
        if (w == null || !w.removed) return;
        if (w.cid != ref.read(activeCompanyIdProvider).value) return;
        // Side effects run after this provider frame (they rebuild
        // memberships, which is mid-rebuild right now).
        scheduleMicrotask(() => unawaited(_onConfirmedRemoval(w.cid)));
      })
      ..listen<AsyncValue<String?>>(activeCompanyIdProvider, (
        AsyncValue<String?>? prev,
        AsyncValue<String?> next,
      ) {
        final before = prev?.value;
        if (before == null || !next.hasValue || next.value == before) return;
        if (ref.read(currentUidProvider) == null) return; // signed out
        if (ref.read(removedCompaniesProvider).contains(before)) return;
        final raw = ref.read(membershipsStreamProvider).value;
        if (raw == null || raw.any((Membership m) => m.id == before)) {
          return; // a normal switch
        }
        if (!ref.read(serverConfirmedMembersProvider).contains(before)) {
          return; // never confirmed this session: not evidence of removal
        }
        scheduleMicrotask(() => unawaited(_verifyDroppedCompany(before)));
      });
  }

  void _remember(List<Membership>? list) {
    for (final m in list ?? const <Membership>[]) {
      _names[m.id] = m.companyName;
    }
  }

  Future<void> _verifyDroppedCompany(String cid) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    if (ref.read(accountDeletionInProgressProvider)) return;
    final check = await ref
        .read(companyRepositoryProvider)
        .fetchMemberDocFromServer(cid, uid);
    final gone = switch (check) {
      MemberDocDenied() => true,
      MemberDocSnapshot(member: null, serverConfirmed: true) => true,
      _ => false, // still a member, or unknown (offline)
    };
    if (gone) await _onConfirmedRemoval(cid);
  }

  Future<void> _onConfirmedRemoval(String cid) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    if (ref.read(accountDeletionInProgressProvider)) return;
    if (ref.read(removedCompaniesProvider).contains(cid)) return; // once
    ref.read(removedCompaniesProvider.notifier).add(cid);
    ref.read(serverConfirmedMembersProvider).remove(cid);
    ref
        .read(companyNoticeProvider.notifier)
        .show(lostAccessMessage(_names[cid] ?? 'this company'));
    // The removed company is hidden now, so this resolves to the next one.
    final nextCid = ref.read(activeCompanyIdProvider).value;
    try {
      await ref
          .read(userSettingsRepositoryProvider)
          .setActiveCompanyId(uid, nextCid == cid ? null : nextCid);
    } on Object catch (e) {
      developer.log('Switch after removal failed', name: 'company', error: e);
    }
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

  Future<String>? _registering;

  /// Registers a company (one WriteBatch) and waits until it is active.
  ///
  /// A call made while another register is in flight returns that same
  /// future (never a second company). The member-doc listener for the new
  /// company is held back ([PendingRegistrations]) until the server acks
  /// the batch, or until the offline grace period ends; in the latter case
  /// the app runs on the locally written docs.
  Future<String> registerCompany({
    required String name,
    String? city,
    String? phone,
    required String ownerDisplayName,
    String? ownerPhone,
  }) async {
    final inFlight = _registering;
    if (inFlight != null) return inFlight;
    final future = _register(
      name: name,
      city: city,
      phone: phone,
      ownerDisplayName: ownerDisplayName,
      ownerPhone: ownerPhone,
    );
    _registering = future;
    try {
      return await future;
    } finally {
      if (identical(_registering, future)) _registering = null;
    }
  }

  Future<String> _register({
    required String name,
    String? city,
    String? phone,
    required String ownerDisplayName,
    String? ownerPhone,
  }) async {
    final uid = _uid;
    final cid = const Uuid().v4();
    final pending = _ref.read(pendingRegistrationsProvider.notifier)..add(cid);
    try {
      await _ref
          .read(companyRepositoryProvider)
          .registerCompany(
            uid: uid,
            name: name,
            city: city,
            phoneE164: phone,
            ownerDisplayName: ownerDisplayName,
            ownerPhoneE164: ownerPhone,
            companyId: cid,
          );
    } finally {
      // Ack or offline timeout: attach the member-doc listener now.
      pending.remove(cid);
    }
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
