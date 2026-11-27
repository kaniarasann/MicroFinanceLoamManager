// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_resumer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One contract's onboarding sync list (live), or null when it has none.

@ProviderFor(onboardingQueue)
final onboardingQueueProvider = OnboardingQueueFamily._();

/// One contract's onboarding sync list (live), or null when it has none.

final class OnboardingQueueProvider
    extends
        $FunctionalProvider<
          AsyncValue<OnboardingQueue?>,
          OnboardingQueue?,
          Stream<OnboardingQueue?>
        >
    with $FutureModifier<OnboardingQueue?>, $StreamProvider<OnboardingQueue?> {
  /// One contract's onboarding sync list (live), or null when it has none.
  OnboardingQueueProvider._({
    required OnboardingQueueFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'onboardingQueueProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$onboardingQueueHash();

  @override
  String toString() {
    return r'onboardingQueueProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<OnboardingQueue?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<OnboardingQueue?> create(Ref ref) {
    final argument = this.argument as String;
    return onboardingQueue(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OnboardingQueueProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$onboardingQueueHash() => r'0b04af54388e7c00d9b52fecd139328b1ce0f2ff';

/// One contract's onboarding sync list (live), or null when it has none.

final class OnboardingQueueFamily extends $Family
    with $FunctionalFamilyOverride<Stream<OnboardingQueue?>, String> {
  OnboardingQueueFamily._()
    : super(
        retry: null,
        name: r'onboardingQueueProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One contract's onboarding sync list (live), or null when it has none.

  OnboardingQueueProvider call(String contractId) =>
      OnboardingQueueProvider._(argument: contractId, from: this);

  @override
  String toString() => r'onboardingQueueProvider';
}

/// Contract ids with a pending sync list in the active company. Owners
/// only: collectors never resume (the rules are owner only).

@ProviderFor(pendingOnboardingQueues)
final pendingOnboardingQueuesProvider = PendingOnboardingQueuesProvider._();

/// Contract ids with a pending sync list in the active company. Owners
/// only: collectors never resume (the rules are owner only).

final class PendingOnboardingQueuesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          Stream<List<String>>
        >
    with $FutureModifier<List<String>>, $StreamProvider<List<String>> {
  /// Contract ids with a pending sync list in the active company. Owners
  /// only: collectors never resume (the rules are owner only).
  PendingOnboardingQueuesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingOnboardingQueuesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingOnboardingQueuesHash();

  @$internal
  @override
  $StreamProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<String>> create(Ref ref) {
    return pendingOnboardingQueues(ref);
  }
}

String _$pendingOnboardingQueuesHash() =>
    r'a43d5eece5b3028e3940f69c58440dd538d6dfdc';

/// Finishes onboardings whose later payments are still in their sync
/// list. Runs at most once per contract at a time on this device.

@ProviderFor(onboardingResumer)
final onboardingResumerProvider = OnboardingResumerProvider._();

/// Finishes onboardings whose later payments are still in their sync
/// list. Runs at most once per contract at a time on this device.

final class OnboardingResumerProvider
    extends
        $FunctionalProvider<
          OnboardingResumer,
          OnboardingResumer,
          OnboardingResumer
        >
    with $Provider<OnboardingResumer> {
  /// Finishes onboardings whose later payments are still in their sync
  /// list. Runs at most once per contract at a time on this device.
  OnboardingResumerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingResumerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingResumerHash();

  @$internal
  @override
  $ProviderElement<OnboardingResumer> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OnboardingResumer create(Ref ref) {
    return onboardingResumer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OnboardingResumer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OnboardingResumer>(value),
    );
  }
}

String _$onboardingResumerHash() => r'c15ad5f7d86ffe740831e271619d8fe9e837c2f5';

/// Starts the resumer for owners: on every change of the pending sync
/// lists (including batch 1 reaching the server) and whenever the app
/// comes back to the foreground. Watched by the root widget.

@ProviderFor(onboardingAutoResume)
final onboardingAutoResumeProvider = OnboardingAutoResumeProvider._();

/// Starts the resumer for owners: on every change of the pending sync
/// lists (including batch 1 reaching the server) and whenever the app
/// comes back to the foreground. Watched by the root widget.

final class OnboardingAutoResumeProvider
    extends
        $FunctionalProvider<
          OnboardingAutoResume,
          OnboardingAutoResume,
          OnboardingAutoResume
        >
    with $Provider<OnboardingAutoResume> {
  /// Starts the resumer for owners: on every change of the pending sync
  /// lists (including batch 1 reaching the server) and whenever the app
  /// comes back to the foreground. Watched by the root widget.
  OnboardingAutoResumeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingAutoResumeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingAutoResumeHash();

  @$internal
  @override
  $ProviderElement<OnboardingAutoResume> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OnboardingAutoResume create(Ref ref) {
    return onboardingAutoResume(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OnboardingAutoResume value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OnboardingAutoResume>(value),
    );
  }
}

String _$onboardingAutoResumeHash() =>
    r'8b70e1e51b619697eb480e2bfbeeca05ed0f715e';
