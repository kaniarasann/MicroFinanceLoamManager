// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lock_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

String _$lockControllerHash() => r'2b9e231c79e2403d9e392063c92b69b1eec7738e';

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
