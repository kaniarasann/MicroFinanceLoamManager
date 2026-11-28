// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lock_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Number of auto-lock resume checks running (normally 0 or 1). Non-zero
/// means "the app may be about to lock": deep links wait.

@ProviderFor(LockCheckInFlight)
final lockCheckInFlightProvider = LockCheckInFlightProvider._();

/// Number of auto-lock resume checks running (normally 0 or 1). Non-zero
/// means "the app may be about to lock": deep links wait.
final class LockCheckInFlightProvider
    extends $NotifierProvider<LockCheckInFlight, int> {
  /// Number of auto-lock resume checks running (normally 0 or 1). Non-zero
  /// means "the app may be about to lock": deep links wait.
  LockCheckInFlightProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lockCheckInFlightProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lockCheckInFlightHash();

  @$internal
  @override
  LockCheckInFlight create() => LockCheckInFlight();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$lockCheckInFlightHash() => r'1def590cb7a80fd915622c3a1458110b8632cdbe';

/// Number of auto-lock resume checks running (normally 0 or 1). Non-zero
/// means "the app may be about to lock": deep links wait.

abstract class _$LockCheckInFlight extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Auto-lock on background.
///
/// State is the moment the unlocked app went to the background (null while
/// in the foreground). On resume, if it was away for at least the user's
/// `autoLockMinutes` (device-local, default 1), the session locks.

@ProviderFor(LockController)
final lockControllerProvider = LockControllerProvider._();

/// Auto-lock on background.
///
/// State is the moment the unlocked app went to the background (null while
/// in the foreground). On resume, if it was away for at least the user's
/// `autoLockMinutes` (device-local, default 1), the session locks.
final class LockControllerProvider
    extends $NotifierProvider<LockController, DateTime?> {
  /// Auto-lock on background.
  ///
  /// State is the moment the unlocked app went to the background (null while
  /// in the foreground). On resume, if it was away for at least the user's
  /// `autoLockMinutes` (device-local, default 1), the session locks.
  LockControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lockControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lockControllerHash();

  @$internal
  @override
  LockController create() => LockController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime?>(value),
    );
  }
}

String _$lockControllerHash() => r'8894fd510fdc2770b2d58d1aff8996a7eadd6210';

/// Auto-lock on background.
///
/// State is the moment the unlocked app went to the background (null while
/// in the foreground). On resume, if it was away for at least the user's
/// `autoLockMinutes` (device-local, default 1), the session locks.

abstract class _$LockController extends $Notifier<DateTime?> {
  DateTime? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<DateTime?, DateTime?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DateTime?, DateTime?>,
              DateTime?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
