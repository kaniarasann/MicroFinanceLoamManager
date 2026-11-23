// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The signed-in uid (null when signed out).

@ProviderFor(currentUid)
final currentUidProvider = CurrentUidProvider._();

/// The signed-in uid (null when signed out).

final class CurrentUidProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// The signed-in uid (null when signed out).
  CurrentUidProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentUidProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentUidHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return currentUid(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$currentUidHash() => r'd4826565c9e22432380bc6016e859a1b77a702e1';

/// Raw `users/{uid}/memberships` stream.

@ProviderFor(membershipsStream)
final membershipsStreamProvider = MembershipsStreamProvider._();

/// Raw `users/{uid}/memberships` stream.

final class MembershipsStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Membership>>,
          List<Membership>,
          Stream<List<Membership>>
        >
    with $FutureModifier<List<Membership>>, $StreamProvider<List<Membership>> {
  /// Raw `users/{uid}/memberships` stream.
  MembershipsStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'membershipsStreamProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$membershipsStreamHash();

  @$internal
  @override
  $StreamProviderElement<List<Membership>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Membership>> create(Ref ref) {
    return membershipsStream(ref);
  }
}

String _$membershipsStreamHash() => r'da10c19c5a931ab0078e4e123c899ec699bd23b4';

/// Companies this user lost access to during this session. They are hidden
/// even if a stale cached membership doc still lists them.

@ProviderFor(RemovedCompanies)
final removedCompaniesProvider = RemovedCompaniesProvider._();

/// Companies this user lost access to during this session. They are hidden
/// even if a stale cached membership doc still lists them.
final class RemovedCompaniesProvider
    extends $NotifierProvider<RemovedCompanies, Set<String>> {
  /// Companies this user lost access to during this session. They are hidden
  /// even if a stale cached membership doc still lists them.
  RemovedCompaniesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'removedCompaniesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$removedCompaniesHash();

  @$internal
  @override
  RemovedCompanies create() => RemovedCompanies();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$removedCompaniesHash() => r'c97638b41729bd14bcf5be8c3e24ade3b5798203';

/// Companies this user lost access to during this session. They are hidden
/// even if a stale cached membership doc still lists them.

abstract class _$RemovedCompanies extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The user's companies (minus [RemovedCompanies]), oldest first.

@ProviderFor(memberships)
final membershipsProvider = MembershipsProvider._();

/// The user's companies (minus [RemovedCompanies]), oldest first.

final class MembershipsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Membership>>,
          AsyncValue<List<Membership>>,
          AsyncValue<List<Membership>>
        >
    with $Provider<AsyncValue<List<Membership>>> {
  /// The user's companies (minus [RemovedCompanies]), oldest first.
  MembershipsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'membershipsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$membershipsHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<List<Membership>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<List<Membership>> create(Ref ref) {
    return memberships(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<Membership>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<Membership>>>(value),
    );
  }
}

String _$membershipsHash() => r'9bf93dea909ddcc5f3a81056cab518ac0623dbe4';

/// `user_settings/{uid}` (null until the doc exists).

@ProviderFor(userSettings)
final userSettingsProvider = UserSettingsProvider._();

/// `user_settings/{uid}` (null until the doc exists).

final class UserSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserSettings?>,
          UserSettings?,
          Stream<UserSettings?>
        >
    with $FutureModifier<UserSettings?>, $StreamProvider<UserSettings?> {
  /// `user_settings/{uid}` (null until the doc exists).
  UserSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userSettingsHash();

  @$internal
  @override
  $StreamProviderElement<UserSettings?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<UserSettings?> create(Ref ref) {
    return userSettings(ref);
  }
}

String _$userSettingsHash() => r'49b32b61e0df15d84a8055263bf3193aad9deb46';

/// The active company id: `user_settings.activeCompanyId`, falling back to
/// the first membership. Loading until memberships (and settings) load.

@ProviderFor(activeCompanyId)
final activeCompanyIdProvider = ActiveCompanyIdProvider._();

/// The active company id: `user_settings.activeCompanyId`, falling back to
/// the first membership. Loading until memberships (and settings) load.

final class ActiveCompanyIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<String?>,
          AsyncValue<String?>,
          AsyncValue<String?>
        >
    with $Provider<AsyncValue<String?>> {
  /// The active company id: `user_settings.activeCompanyId`, falling back to
  /// the first membership. Loading until memberships (and settings) load.
  ActiveCompanyIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeCompanyIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeCompanyIdHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<String?>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<String?> create(Ref ref) {
    return activeCompanyId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<String?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<String?>>(value),
    );
  }
}

String _$activeCompanyIdHash() => r'81f0a82eb96445c0073c41888f056266a630e685';

/// Drives the router's company guard.

@ProviderFor(companyGate)
final companyGateProvider = CompanyGateProvider._();

/// Drives the router's company guard.

final class CompanyGateProvider
    extends $FunctionalProvider<CompanyGate, CompanyGate, CompanyGate>
    with $Provider<CompanyGate> {
  /// Drives the router's company guard.
  CompanyGateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'companyGateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$companyGateHash();

  @$internal
  @override
  $ProviderElement<CompanyGate> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CompanyGate create(Ref ref) {
    return companyGate(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CompanyGate value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CompanyGate>(value),
    );
  }
}

String _$companyGateHash() => r'5679ca1df731d8a41d6587a94988036553cefee2';

/// The active company's membership index doc (name + role, offline-safe).

@ProviderFor(activeMembership)
final activeMembershipProvider = ActiveMembershipProvider._();

/// The active company's membership index doc (name + role, offline-safe).

final class ActiveMembershipProvider
    extends $FunctionalProvider<Membership?, Membership?, Membership?>
    with $Provider<Membership?> {
  /// The active company's membership index doc (name + role, offline-safe).
  ActiveMembershipProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeMembershipProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeMembershipHash();

  @$internal
  @override
  $ProviderElement<Membership?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Membership? create(Ref ref) {
    return activeMembership(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Membership? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Membership?>(value),
    );
  }
}

String _$activeMembershipHash() => r'9b67779c6b6a18fc61fcc46cba7a25d6a0241952';

/// `companies/{activeCompanyId}`.

@ProviderFor(activeCompany)
final activeCompanyProvider = ActiveCompanyProvider._();

/// `companies/{activeCompanyId}`.

final class ActiveCompanyProvider
    extends
        $FunctionalProvider<AsyncValue<Company?>, Company?, Stream<Company?>>
    with $FutureModifier<Company?>, $StreamProvider<Company?> {
  /// `companies/{activeCompanyId}`.
  ActiveCompanyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeCompanyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeCompanyHash();

  @$internal
  @override
  $StreamProviderElement<Company?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Company?> create(Ref ref) {
    return activeCompany(ref);
  }
}

String _$activeCompanyHash() => r'b28e8f2b49ce913e0645f00bc5bd5a6f1fa1537d';

/// Company ids whose member doc the server confirmed (exists, not from
/// cache, no pending writes) in this app session. Reset per user. Removal
/// can only be concluded for a company in this set.

@ProviderFor(serverConfirmedMembers)
final serverConfirmedMembersProvider = ServerConfirmedMembersProvider._();

/// Company ids whose member doc the server confirmed (exists, not from
/// cache, no pending writes) in this app session. Reset per user. Removal
/// can only be concluded for a company in this set.

final class ServerConfirmedMembersProvider
    extends $FunctionalProvider<Set<String>, Set<String>, Set<String>>
    with $Provider<Set<String>> {
  /// Company ids whose member doc the server confirmed (exists, not from
  /// cache, no pending writes) in this app session. Reset per user. Removal
  /// can only be concluded for a company in this set.
  ServerConfirmedMembersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverConfirmedMembersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverConfirmedMembersHash();

  @$internal
  @override
  $ProviderElement<Set<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<String> create(Ref ref) {
    return serverConfirmedMembers(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$serverConfirmedMembersHash() =>
    r'aa57853a12f10a87be1cc6704491e96130597722';

/// Re-attach delays for the member-doc listener (overridden in tests).

@ProviderFor(memberRetryBackoff)
final memberRetryBackoffProvider = MemberRetryBackoffProvider._();

/// Re-attach delays for the member-doc listener (overridden in tests).

final class MemberRetryBackoffProvider
    extends $FunctionalProvider<RetryBackoff, RetryBackoff, RetryBackoff>
    with $Provider<RetryBackoff> {
  /// Re-attach delays for the member-doc listener (overridden in tests).
  MemberRetryBackoffProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberRetryBackoffProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberRetryBackoffHash();

  @$internal
  @override
  $ProviderElement<RetryBackoff> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RetryBackoff create(Ref ref) {
    return memberRetryBackoff(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RetryBackoff value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RetryBackoff>(value),
    );
  }
}

String _$memberRetryBackoffHash() =>
    r'82069c2481fd1735cd7aa013c1c9bdba6e4d2182';

/// Companies whose register batch is still waiting for the server ack. The
/// member-doc listener is not attached for them until the ack (or the
/// offline timeout), so the first server evaluation can never be a
/// "not a member yet" denial.

@ProviderFor(PendingRegistrations)
final pendingRegistrationsProvider = PendingRegistrationsProvider._();

/// Companies whose register batch is still waiting for the server ack. The
/// member-doc listener is not attached for them until the ack (or the
/// offline timeout), so the first server evaluation can never be a
/// "not a member yet" denial.
final class PendingRegistrationsProvider
    extends $NotifierProvider<PendingRegistrations, Set<String>> {
  /// Companies whose register batch is still waiting for the server ack. The
  /// member-doc listener is not attached for them until the ack (or the
  /// offline timeout), so the first server evaluation can never be a
  /// "not a member yet" denial.
  PendingRegistrationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingRegistrationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingRegistrationsHash();

  @$internal
  @override
  PendingRegistrations create() => PendingRegistrations();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$pendingRegistrationsHash() =>
    r'a11de862fb117437e7e9ba4212db77f79e4a1e3b';

/// Companies whose register batch is still waiting for the server ack. The
/// member-doc listener is not attached for them until the ack (or the
/// offline timeout), so the first server evaluation can never be a
/// "not a member yet" denial.

abstract class _$PendingRegistrations extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The caller's member doc in the active company, tagged with its cid.
/// See [watchMemberAccess] for the (conservative) removal rule.

@ProviderFor(activeMemberWatch)
final activeMemberWatchProvider = ActiveMemberWatchProvider._();

/// The caller's member doc in the active company, tagged with its cid.
/// See [watchMemberAccess] for the (conservative) removal rule.

final class ActiveMemberWatchProvider
    extends
        $FunctionalProvider<
          AsyncValue<MemberWatch?>,
          MemberWatch?,
          Stream<MemberWatch?>
        >
    with $FutureModifier<MemberWatch?>, $StreamProvider<MemberWatch?> {
  /// The caller's member doc in the active company, tagged with its cid.
  /// See [watchMemberAccess] for the (conservative) removal rule.
  ActiveMemberWatchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeMemberWatchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeMemberWatchHash();

  @$internal
  @override
  $StreamProviderElement<MemberWatch?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<MemberWatch?> create(Ref ref) {
    return activeMemberWatch(ref);
  }
}

String _$activeMemberWatchHash() => r'27039722c227f8c979ba9ee3e9c185364873e3ed';

/// The caller's member doc in the active company (null while unknown).

@ProviderFor(currentMember)
final currentMemberProvider = CurrentMemberProvider._();

/// The caller's member doc in the active company (null while unknown).

final class CurrentMemberProvider
    extends $FunctionalProvider<Member?, Member?, Member?>
    with $Provider<Member?> {
  /// The caller's member doc in the active company (null while unknown).
  CurrentMemberProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentMemberProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentMemberHash();

  @$internal
  @override
  $ProviderElement<Member?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Member? create(Ref ref) {
    return currentMember(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Member? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Member?>(value),
    );
  }
}

String _$currentMemberHash() => r'cebf2c364b98816510b7638498a1a24eb9cadd1c';

/// The caller's role in the active company. The member doc is the source of
/// truth (rules check it); the membership index is the offline fallback.

@ProviderFor(currentRole)
final currentRoleProvider = CurrentRoleProvider._();

/// The caller's role in the active company. The member doc is the source of
/// truth (rules check it); the membership index is the offline fallback.

final class CurrentRoleProvider extends $FunctionalProvider<Role?, Role?, Role?>
    with $Provider<Role?> {
  /// The caller's role in the active company. The member doc is the source of
  /// truth (rules check it); the membership index is the offline fallback.
  CurrentRoleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentRoleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentRoleHash();

  @$internal
  @override
  $ProviderElement<Role?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Role? create(Ref ref) {
    return currentRole(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Role? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Role?>(value),
    );
  }
}

String _$currentRoleHash() => r'7b36e1e0710b85254593c0384bb16ee2600c570e';

/// Display name of the active company.

@ProviderFor(activeCompanyName)
final activeCompanyNameProvider = ActiveCompanyNameProvider._();

/// Display name of the active company.

final class ActiveCompanyNameProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// Display name of the active company.
  ActiveCompanyNameProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeCompanyNameProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeCompanyNameHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return activeCompanyName(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$activeCompanyNameHash() => r'a458da0eae951af6efd774cfcfd0aceb97b3d58a';

/// A one-time user message from the company layer (e.g. lost access). The
/// root widget shows it as a snackbar and [consume]s it.

@ProviderFor(CompanyNotice)
final companyNoticeProvider = CompanyNoticeProvider._();

/// A one-time user message from the company layer (e.g. lost access). The
/// root widget shows it as a snackbar and [consume]s it.
final class CompanyNoticeProvider
    extends $NotifierProvider<CompanyNotice, String?> {
  /// A one-time user message from the company layer (e.g. lost access). The
  /// root widget shows it as a snackbar and [consume]s it.
  CompanyNoticeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'companyNoticeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$companyNoticeHash();

  @$internal
  @override
  CompanyNotice create() => CompanyNotice();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$companyNoticeHash() => r'aeeeb8f111f9d4dcceea67c22c24bddd634b33f2';

/// A one-time user message from the company layer (e.g. lost access). The
/// root widget shows it as a snackbar and [consume]s it.

abstract class _$CompanyNotice extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

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

@ProviderFor(CompanyAccessGuard)
final companyAccessGuardProvider = CompanyAccessGuardProvider._();

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
final class CompanyAccessGuardProvider
    extends $NotifierProvider<CompanyAccessGuard, void> {
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
  CompanyAccessGuardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'companyAccessGuardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$companyAccessGuardHash();

  @$internal
  @override
  CompanyAccessGuard create() => CompanyAccessGuard();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$companyAccessGuardHash() =>
    r'2e84eb08b22c4b15b3ee295737aba6332c4ef293';

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

abstract class _$CompanyAccessGuard extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Company use-cases called by the onboarding screens and the switcher.

@ProviderFor(companyActions)
final companyActionsProvider = CompanyActionsProvider._();

/// Company use-cases called by the onboarding screens and the switcher.

final class CompanyActionsProvider
    extends $FunctionalProvider<CompanyActions, CompanyActions, CompanyActions>
    with $Provider<CompanyActions> {
  /// Company use-cases called by the onboarding screens and the switcher.
  CompanyActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'companyActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$companyActionsHash();

  @$internal
  @override
  $ProviderElement<CompanyActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CompanyActions create(Ref ref) {
    return companyActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CompanyActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CompanyActions>(value),
    );
  }
}

String _$companyActionsHash() => r'418e7635429eb5730bb12a2d50b7a3a973aff537';
