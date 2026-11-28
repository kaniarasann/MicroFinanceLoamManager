// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountRepository)
final accountRepositoryProvider = AccountRepositoryProvider._();

final class AccountRepositoryProvider
    extends
        $FunctionalProvider<
          AccountRepository,
          AccountRepository,
          AccountRepository
        >
    with $Provider<AccountRepository> {
  AccountRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountRepositoryHash();

  @$internal
  @override
  $ProviderElement<AccountRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountRepository create(Ref ref) {
    return accountRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountRepository>(value),
    );
  }
}

String _$accountRepositoryHash() => r'd487da1417fdcfa0c0d7c6132841a8123a907eb9';

@ProviderFor(syncSignals)
final syncSignalsProvider = SyncSignalsProvider._();

final class SyncSignalsProvider
    extends $FunctionalProvider<SyncSignals, SyncSignals, SyncSignals>
    with $Provider<SyncSignals> {
  SyncSignalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncSignalsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncSignalsHash();

  @$internal
  @override
  $ProviderElement<SyncSignals> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncSignals create(Ref ref) {
    return syncSignals(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncSignals value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncSignals>(value),
    );
  }
}

String _$syncSignalsHash() => r'13a7ad2bffa0f8bba7d917d9afba946b0a62b5d3';

/// "1.0.0 (build 1)".

@ProviderFor(appVersion)
final appVersionProvider = AppVersionProvider._();

/// "1.0.0 (build 1)".

final class AppVersionProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// "1.0.0 (build 1)".
  AppVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appVersionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appVersionHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return appVersion(ref);
  }
}

String _$appVersionHash() => r'6db7c1d0e891068456ae0f6304e2122909399ac8';

/// The device-local auto-lock delay (secure storage, per uid). Device-local
/// on purpose: it is a property of this phone's lock, like the MPIN.

@ProviderFor(autoLockMinutes)
final autoLockMinutesProvider = AutoLockMinutesProvider._();

/// The device-local auto-lock delay (secure storage, per uid). Device-local
/// on purpose: it is a property of this phone's lock, like the MPIN.

final class AutoLockMinutesProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// The device-local auto-lock delay (secure storage, per uid). Device-local
  /// on purpose: it is a property of this phone's lock, like the MPIN.
  AutoLockMinutesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoLockMinutesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoLockMinutesHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return autoLockMinutes(ref);
  }
}

String _$autoLockMinutesHash() => r'277d04f375b815b41b63a8c792efe4e1de7ea210';

/// Whether this device can do biometric unlock.

@ProviderFor(biometricAvailable)
final biometricAvailableProvider = BiometricAvailableProvider._();

/// Whether this device can do biometric unlock.

final class BiometricAvailableProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether this device can do biometric unlock.
  BiometricAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'biometricAvailableProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$biometricAvailableHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return biometricAvailable(ref);
  }
}

String _$biometricAvailableHash() =>
    r'd984ed39321527cca87858062f4ef911c2ea29b7';

/// Online + pending-writes state. Pending is true while
/// `waitForPendingWrites` has not completed; it is re-checked whenever the
/// Firestore listeners come back in sync.

@ProviderFor(SyncStatus)
final syncStatusProvider = SyncStatusProvider._();

/// Online + pending-writes state. Pending is true while
/// `waitForPendingWrites` has not completed; it is re-checked whenever the
/// Firestore listeners come back in sync.
final class SyncStatusProvider
    extends $NotifierProvider<SyncStatus, SyncState> {
  /// Online + pending-writes state. Pending is true while
  /// `waitForPendingWrites` has not completed; it is re-checked whenever the
  /// Firestore listeners come back in sync.
  SyncStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncStatusHash();

  @$internal
  @override
  SyncStatus create() => SyncStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncState>(value),
    );
  }
}

String _$syncStatusHash() => r'9a4826dc83ad999776a59cf4c744298feb042c61';

/// Online + pending-writes state. Pending is true while
/// `waitForPendingWrites` has not completed; it is re-checked whenever the
/// Firestore listeners come back in sync.

abstract class _$SyncStatus extends $Notifier<SyncState> {
  SyncState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SyncState, SyncState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncState, SyncState>,
              SyncState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The deletion preview for the signed-in user (server reads; fails
/// offline).

@ProviderFor(accountExitPlan)
final accountExitPlanProvider = AccountExitPlanProvider._();

/// The deletion preview for the signed-in user (server reads; fails
/// offline).

final class AccountExitPlanProvider
    extends
        $FunctionalProvider<
          AsyncValue<AccountExitPlan>,
          AccountExitPlan,
          FutureOr<AccountExitPlan>
        >
    with $FutureModifier<AccountExitPlan>, $FutureProvider<AccountExitPlan> {
  /// The deletion preview for the signed-in user (server reads; fails
  /// offline).
  AccountExitPlanProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'accountExitPlanProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountExitPlanHash();

  @$internal
  @override
  $FutureProviderElement<AccountExitPlan> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AccountExitPlan> create(Ref ref) {
    return accountExitPlan(ref);
  }
}

String _$accountExitPlanHash() => r'7fc0f207665b1e90db060032462b89c0a84db132';

@ProviderFor(settingsActions)
final settingsActionsProvider = SettingsActionsProvider._();

final class SettingsActionsProvider
    extends
        $FunctionalProvider<SettingsActions, SettingsActions, SettingsActions>
    with $Provider<SettingsActions> {
  SettingsActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsActionsHash();

  @$internal
  @override
  $ProviderElement<SettingsActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SettingsActions create(Ref ref) {
    return settingsActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsActions>(value),
    );
  }
}

String _$settingsActionsHash() => r'24ad85c2ed0dbf727511fda6962e2ec90bbae954';
