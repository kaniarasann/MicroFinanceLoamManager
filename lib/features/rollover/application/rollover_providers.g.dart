// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rollover_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(rolloverRepository)
final rolloverRepositoryProvider = RolloverRepositoryProvider._();

final class RolloverRepositoryProvider
    extends
        $FunctionalProvider<
          RolloverRepository,
          RolloverRepository,
          RolloverRepository
        >
    with $Provider<RolloverRepository> {
  RolloverRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rolloverRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rolloverRepositoryHash();

  @$internal
  @override
  $ProviderElement<RolloverRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RolloverRepository create(Ref ref) {
    return rolloverRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RolloverRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RolloverRepository>(value),
    );
  }
}

String _$rolloverRepositoryHash() =>
    r'b98a2adaad23c4e68236f2996ad5e33ddd2717bf';

/// Rollover use-case (owner only; the rules enforce it).

@ProviderFor(rolloverActions)
final rolloverActionsProvider = RolloverActionsProvider._();

/// Rollover use-case (owner only; the rules enforce it).

final class RolloverActionsProvider
    extends
        $FunctionalProvider<RolloverActions, RolloverActions, RolloverActions>
    with $Provider<RolloverActions> {
  /// Rollover use-case (owner only; the rules enforce it).
  RolloverActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rolloverActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rolloverActionsHash();

  @$internal
  @override
  $ProviderElement<RolloverActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RolloverActions create(Ref ref) {
    return rolloverActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RolloverActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RolloverActions>(value),
    );
  }
}

String _$rolloverActionsHash() => r'9f2a69364ded897a6542d815873f12b02cfb568b';
