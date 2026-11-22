// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clock_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-wide [Clock]. Override with a [FixedClock] in tests:
/// `clockProvider.overrideWithValue(FixedClock.ist(2023, 10, 24))`.

@ProviderFor(clock)
final clockProvider = ClockProvider._();

/// App-wide [Clock]. Override with a [FixedClock] in tests:
/// `clockProvider.overrideWithValue(FixedClock.ist(2023, 10, 24))`.

final class ClockProvider extends $FunctionalProvider<Clock, Clock, Clock>
    with $Provider<Clock> {
  /// App-wide [Clock]. Override with a [FixedClock] in tests:
  /// `clockProvider.overrideWithValue(FixedClock.ist(2023, 10, 24))`.
  ClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clockHash();

  @$internal
  @override
  $ProviderElement<Clock> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Clock create(Ref ref) {
    return clock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Clock value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Clock>(value),
    );
  }
}

String _$clockHash() => r'39eecdd3b7363380db7b9d536b48fade918db022';
