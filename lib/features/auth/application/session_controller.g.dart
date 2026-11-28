// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns [AuthStage]:
/// - auth stream null → signedOut;
/// - signed in, no MPIN on this device → needsMpinSetup;
/// - signed in with an MPIN (cold start or fresh sign-in) → locked;
/// - correct MPIN / biometric → unlocked;
/// - lock() (auto-lock) → locked.

@ProviderFor(SessionController)
final sessionControllerProvider = SessionControllerProvider._();

/// Owns [AuthStage]:
/// - auth stream null → signedOut;
/// - signed in, no MPIN on this device → needsMpinSetup;
/// - signed in with an MPIN (cold start or fresh sign-in) → locked;
/// - correct MPIN / biometric → unlocked;
/// - lock() (auto-lock) → locked.
final class SessionControllerProvider
    extends $NotifierProvider<SessionController, SessionState> {
  /// Owns [AuthStage]:
  /// - auth stream null → signedOut;
  /// - signed in, no MPIN on this device → needsMpinSetup;
  /// - signed in with an MPIN (cold start or fresh sign-in) → locked;
  /// - correct MPIN / biometric → unlocked;
  /// - lock() (auto-lock) → locked.
  SessionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionControllerHash();

  @$internal
  @override
  SessionController create() => SessionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionState>(value),
    );
  }
}

String _$sessionControllerHash() => r'1903b9ed486d56fd900b6736ad4f6befee3e9d7d';

/// Owns [AuthStage]:
/// - auth stream null → signedOut;
/// - signed in, no MPIN on this device → needsMpinSetup;
/// - signed in with an MPIN (cold start or fresh sign-in) → locked;
/// - correct MPIN / biometric → unlocked;
/// - lock() (auto-lock) → locked.

abstract class _$SessionController extends $Notifier<SessionState> {
  SessionState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SessionState, SessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SessionState, SessionState>,
              SessionState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
