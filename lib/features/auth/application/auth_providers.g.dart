// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Auth / lock dependencies. Tests override these with fakes.

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

/// Auth / lock dependencies. Tests override these with fakes.

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  /// Auth / lock dependencies. Tests override these with fakes.
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'434ca334c8df7e8cbbb671cf741b4711f95104e1';

@ProviderFor(secureKeyValueStore)
final secureKeyValueStoreProvider = SecureKeyValueStoreProvider._();

final class SecureKeyValueStoreProvider
    extends
        $FunctionalProvider<
          SecureKeyValueStore,
          SecureKeyValueStore,
          SecureKeyValueStore
        >
    with $Provider<SecureKeyValueStore> {
  SecureKeyValueStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureKeyValueStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureKeyValueStoreHash();

  @$internal
  @override
  $ProviderElement<SecureKeyValueStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SecureKeyValueStore create(Ref ref) {
    return secureKeyValueStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureKeyValueStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureKeyValueStore>(value),
    );
  }
}

String _$secureKeyValueStoreHash() =>
    r'78bdb6ff36a93c16d7e2c7414b2632726de5ab05';

@ProviderFor(mpinStore)
final mpinStoreProvider = MpinStoreProvider._();

final class MpinStoreProvider
    extends $FunctionalProvider<MpinStore, MpinStore, MpinStore>
    with $Provider<MpinStore> {
  MpinStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mpinStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mpinStoreHash();

  @$internal
  @override
  $ProviderElement<MpinStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MpinStore create(Ref ref) {
    return mpinStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MpinStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MpinStore>(value),
    );
  }
}

String _$mpinStoreHash() => r'acda57db0e5923af03323f369bc2d35a4f75485f';

@ProviderFor(biometricService)
final biometricServiceProvider = BiometricServiceProvider._();

final class BiometricServiceProvider
    extends
        $FunctionalProvider<
          BiometricService,
          BiometricService,
          BiometricService
        >
    with $Provider<BiometricService> {
  BiometricServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'biometricServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$biometricServiceHash();

  @$internal
  @override
  $ProviderElement<BiometricService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BiometricService create(Ref ref) {
    return biometricService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BiometricService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BiometricService>(value),
    );
  }
}

String _$biometricServiceHash() => r'07d4fc21e49976515d31ca63734425ff82b22662';
