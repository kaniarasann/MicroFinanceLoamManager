// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'members_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(membersRepository)
final membersRepositoryProvider = MembersRepositoryProvider._();

final class MembersRepositoryProvider
    extends
        $FunctionalProvider<
          MembersRepository,
          MembersRepository,
          MembersRepository
        >
    with $Provider<MembersRepository> {
  MembersRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'membersRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$membersRepositoryHash();

  @$internal
  @override
  $ProviderElement<MembersRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MembersRepository create(Ref ref) {
    return membersRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MembersRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MembersRepository>(value),
    );
  }
}

String _$membersRepositoryHash() => r'709fad27d12045010cc9266c1798da895e3e84b0';

@ProviderFor(inviteShareService)
final inviteShareServiceProvider = InviteShareServiceProvider._();

final class InviteShareServiceProvider
    extends
        $FunctionalProvider<
          InviteShareService,
          InviteShareService,
          InviteShareService
        >
    with $Provider<InviteShareService> {
  InviteShareServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inviteShareServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inviteShareServiceHash();

  @$internal
  @override
  $ProviderElement<InviteShareService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InviteShareService create(Ref ref) {
    return inviteShareService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InviteShareService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InviteShareService>(value),
    );
  }
}

String _$inviteShareServiceHash() =>
    r'87c4d8df7caefdcfcf2b4d19cbf140a950e0da17';

/// The active company's members (owners first, then by name).

@ProviderFor(companyMembers)
final companyMembersProvider = CompanyMembersProvider._();

/// The active company's members (owners first, then by name).

final class CompanyMembersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Member>>,
          List<Member>,
          Stream<List<Member>>
        >
    with $FutureModifier<List<Member>>, $StreamProvider<List<Member>> {
  /// The active company's members (owners first, then by name).
  CompanyMembersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'companyMembersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$companyMembersHash();

  @$internal
  @override
  $StreamProviderElement<List<Member>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Member>> create(Ref ref) {
    return companyMembers(ref);
  }
}

String _$companyMembersHash() => r'8062256b0acfab7d358b59e54aa8a42323c34a6a';

/// The active company's pending invites. Owners only: collectors are not
/// allowed to list invites, so they get an empty list without a query.

@ProviderFor(pendingInvites)
final pendingInvitesProvider = PendingInvitesProvider._();

/// The active company's pending invites. Owners only: collectors are not
/// allowed to list invites, so they get an empty list without a query.

final class PendingInvitesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Invite>>,
          List<Invite>,
          Stream<List<Invite>>
        >
    with $FutureModifier<List<Invite>>, $StreamProvider<List<Invite>> {
  /// The active company's pending invites. Owners only: collectors are not
  /// allowed to list invites, so they get an empty list without a query.
  PendingInvitesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingInvitesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingInvitesHash();

  @$internal
  @override
  $StreamProviderElement<List<Invite>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Invite>> create(Ref ref) {
    return pendingInvites(ref);
  }
}

String _$pendingInvitesHash() => r'e2812ee8926aacb448de0e9a3ddb30aac4d6b0a3';

/// `companies/{active}.ownerUids` (empty until the company loads).

@ProviderFor(activeOwnerUids)
final activeOwnerUidsProvider = ActiveOwnerUidsProvider._();

/// `companies/{active}.ownerUids` (empty until the company loads).

final class ActiveOwnerUidsProvider
    extends $FunctionalProvider<List<String>, List<String>, List<String>>
    with $Provider<List<String>> {
  /// `companies/{active}.ownerUids` (empty until the company loads).
  ActiveOwnerUidsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeOwnerUidsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeOwnerUidsHash();

  @$internal
  @override
  $ProviderElement<List<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<String> create(Ref ref) {
    return activeOwnerUids(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$activeOwnerUidsHash() => r'09a4812e889b23cb0797b0584749ccbb59651974';

/// Members & invites use-cases for the active company (owner).

@ProviderFor(membersActions)
final membersActionsProvider = MembersActionsProvider._();

/// Members & invites use-cases for the active company (owner).

final class MembersActionsProvider
    extends $FunctionalProvider<MembersActions, MembersActions, MembersActions>
    with $Provider<MembersActions> {
  /// Members & invites use-cases for the active company (owner).
  MembersActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'membersActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$membersActionsHash();

  @$internal
  @override
  $ProviderElement<MembersActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MembersActions create(Ref ref) {
    return membersActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MembersActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MembersActions>(value),
    );
  }
}

String _$membersActionsHash() => r'8c31cab2b179bdace19d697fde8c1a00d03a65c0';
