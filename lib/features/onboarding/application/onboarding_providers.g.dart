// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(companyRepository)
final companyRepositoryProvider = CompanyRepositoryProvider._();

final class CompanyRepositoryProvider
    extends
        $FunctionalProvider<
          CompanyRepository,
          CompanyRepository,
          CompanyRepository
        >
    with $Provider<CompanyRepository> {
  CompanyRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'companyRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$companyRepositoryHash();

  @$internal
  @override
  $ProviderElement<CompanyRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CompanyRepository create(Ref ref) {
    return companyRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CompanyRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CompanyRepository>(value),
    );
  }
}

String _$companyRepositoryHash() => r'266a969240d801f486d3a581410cb48114358cb2';

@ProviderFor(inviteRepository)
final inviteRepositoryProvider = InviteRepositoryProvider._();

final class InviteRepositoryProvider
    extends
        $FunctionalProvider<
          InviteRepository,
          InviteRepository,
          InviteRepository
        >
    with $Provider<InviteRepository> {
  InviteRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inviteRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inviteRepositoryHash();

  @$internal
  @override
  $ProviderElement<InviteRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  InviteRepository create(Ref ref) {
    return inviteRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InviteRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InviteRepository>(value),
    );
  }
}

String _$inviteRepositoryHash() => r'1c74f241c1ef9e57b7046a6b55f7112dca5129f1';

@ProviderFor(userSettingsRepository)
final userSettingsRepositoryProvider = UserSettingsRepositoryProvider._();

final class UserSettingsRepositoryProvider
    extends
        $FunctionalProvider<
          UserSettingsRepository,
          UserSettingsRepository,
          UserSettingsRepository
        >
    with $Provider<UserSettingsRepository> {
  UserSettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userSettingsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userSettingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<UserSettingsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UserSettingsRepository create(Ref ref) {
    return userSettingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserSettingsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserSettingsRepository>(value),
    );
  }
}

String _$userSettingsRepositoryHash() =>
    r'7f30327e99c356baa07cc7556eb74866cd4aa8a2';

@ProviderFor(cacheResetFlag)
final cacheResetFlagProvider = CacheResetFlagProvider._();

final class CacheResetFlagProvider
    extends $FunctionalProvider<CacheResetFlag, CacheResetFlag, CacheResetFlag>
    with $Provider<CacheResetFlag> {
  CacheResetFlagProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cacheResetFlagProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cacheResetFlagHash();

  @$internal
  @override
  $ProviderElement<CacheResetFlag> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CacheResetFlag create(Ref ref) {
    return cacheResetFlag(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CacheResetFlag value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CacheResetFlag>(value),
    );
  }
}

String _$cacheResetFlagHash() => r'268644fcb0924e6792141c52a5e7ccff9a40eef8';

@ProviderFor(installReferrerSource)
final installReferrerSourceProvider = InstallReferrerSourceProvider._();

final class InstallReferrerSourceProvider
    extends
        $FunctionalProvider<
          InstallReferrerSource,
          InstallReferrerSource,
          InstallReferrerSource
        >
    with $Provider<InstallReferrerSource> {
  InstallReferrerSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installReferrerSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installReferrerSourceHash();

  @$internal
  @override
  $ProviderElement<InstallReferrerSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InstallReferrerSource create(Ref ref) {
    return installReferrerSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InstallReferrerSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InstallReferrerSource>(value),
    );
  }
}

String _$installReferrerSourceHash() =>
    r'e4a1f97c19579d57eb325664e8ebf05d832f9dd5';

/// An invite code waiting to pre-fill the join screen: from a `/join?code=`
/// deep link that arrived while locked, or from the Play install referrer.
/// The join screen [take]s it.

@ProviderFor(PendingInviteCode)
final pendingInviteCodeProvider = PendingInviteCodeProvider._();

/// An invite code waiting to pre-fill the join screen: from a `/join?code=`
/// deep link that arrived while locked, or from the Play install referrer.
/// The join screen [take]s it.
final class PendingInviteCodeProvider
    extends $NotifierProvider<PendingInviteCode, String?> {
  /// An invite code waiting to pre-fill the join screen: from a `/join?code=`
  /// deep link that arrived while locked, or from the Play install referrer.
  /// The join screen [take]s it.
  PendingInviteCodeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingInviteCodeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingInviteCodeHash();

  @$internal
  @override
  PendingInviteCode create() => PendingInviteCode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$pendingInviteCodeHash() => r'c21fe1e5233b7ffc997f0a1efa50aafe3491743d';

/// An invite code waiting to pre-fill the join screen: from a `/join?code=`
/// deep link that arrived while locked, or from the Play install referrer.
/// The join screen [take]s it.

abstract class _$PendingInviteCode extends $Notifier<String?> {
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

/// Reads the Play install referrer once per install and offers its code.
/// Watched by the root widget; failures are ignored by the source.

@ProviderFor(installReferrerBootstrap)
final installReferrerBootstrapProvider = InstallReferrerBootstrapProvider._();

/// Reads the Play install referrer once per install and offers its code.
/// Watched by the root widget; failures are ignored by the source.

final class InstallReferrerBootstrapProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Reads the Play install referrer once per install and offers its code.
  /// Watched by the root widget; failures are ignored by the source.
  InstallReferrerBootstrapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installReferrerBootstrapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installReferrerBootstrapHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return installReferrerBootstrap(ref);
  }
}

String _$installReferrerBootstrapHash() =>
    r'e495d5263f53abab2745431afe3c620fc59afd44';
