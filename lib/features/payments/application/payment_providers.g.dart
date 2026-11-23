// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(paymentRepository)
final paymentRepositoryProvider = PaymentRepositoryProvider._();

final class PaymentRepositoryProvider
    extends
        $FunctionalProvider<
          PaymentRepository,
          PaymentRepository,
          PaymentRepository
        >
    with $Provider<PaymentRepository> {
  PaymentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentRepositoryHash();

  @$internal
  @override
  $ProviderElement<PaymentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PaymentRepository create(Ref ref) {
    return paymentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaymentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaymentRepository>(value),
    );
  }
}

String _$paymentRepositoryHash() => r'0d105e2b20cb4d0843e26529db70fd950c2e5d21';

/// Payment use-cases: record (owner or collector) and reverse (owner; the
/// rules enforce it).

@ProviderFor(paymentActions)
final paymentActionsProvider = PaymentActionsProvider._();

/// Payment use-cases: record (owner or collector) and reverse (owner; the
/// rules enforce it).

final class PaymentActionsProvider
    extends $FunctionalProvider<PaymentActions, PaymentActions, PaymentActions>
    with $Provider<PaymentActions> {
  /// Payment use-cases: record (owner or collector) and reverse (owner; the
  /// rules enforce it).
  PaymentActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentActionsHash();

  @$internal
  @override
  $ProviderElement<PaymentActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PaymentActions create(Ref ref) {
    return paymentActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaymentActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaymentActions>(value),
    );
  }
}

String _$paymentActionsHash() => r'e8b0ad9a62dc9e36d0ee1d4d828f0c8e16d5af1c';
