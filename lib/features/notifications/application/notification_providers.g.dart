// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The platform notification seam (tests override it with
/// [InMemoryNotificationGateway]).

@ProviderFor(localNotificationGateway)
final localNotificationGatewayProvider = LocalNotificationGatewayProvider._();

/// The platform notification seam (tests override it with
/// [InMemoryNotificationGateway]).

final class LocalNotificationGatewayProvider
    extends
        $FunctionalProvider<
          LocalNotificationGateway,
          LocalNotificationGateway,
          LocalNotificationGateway
        >
    with $Provider<LocalNotificationGateway> {
  /// The platform notification seam (tests override it with
  /// [InMemoryNotificationGateway]).
  LocalNotificationGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localNotificationGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localNotificationGatewayHash();

  @$internal
  @override
  $ProviderElement<LocalNotificationGateway> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LocalNotificationGateway create(Ref ref) {
    return localNotificationGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalNotificationGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalNotificationGateway>(value),
    );
  }
}

String _$localNotificationGatewayHash() =>
    r'44e8a86223c17b91816ac5d9b654a8f2857ede57';

/// Quiet period before a data change re-plans the notifications. Snapshot
/// bursts (a batch landing, a sync from another device) collapse into one
/// run.

@ProviderFor(notificationDebounce)
final notificationDebounceProvider = NotificationDebounceProvider._();

/// Quiet period before a data change re-plans the notifications. Snapshot
/// bursts (a batch landing, a sync from another device) collapse into one
/// run.

final class NotificationDebounceProvider
    extends $FunctionalProvider<Duration, Duration, Duration>
    with $Provider<Duration> {
  /// Quiet period before a data change re-plans the notifications. Snapshot
  /// bursts (a batch landing, a sync from another device) collapse into one
  /// run.
  NotificationDebounceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationDebounceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationDebounceHash();

  @$internal
  @override
  $ProviderElement<Duration> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Duration create(Ref ref) {
    return notificationDebounce(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Duration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Duration>(value),
    );
  }
}

String _$notificationDebounceHash() =>
    r'a68d869b0e10742771de73ddb2756bb49ba86fc0';

/// The user's notification preferences (defaults until `user_settings`
/// loads or when the doc has none).

@ProviderFor(notificationPrefs)
final notificationPrefsProvider = NotificationPrefsProvider._();

/// The user's notification preferences (defaults until `user_settings`
/// loads or when the doc has none).

final class NotificationPrefsProvider
    extends
        $FunctionalProvider<
          NotificationPrefs,
          NotificationPrefs,
          NotificationPrefs
        >
    with $Provider<NotificationPrefs> {
  /// The user's notification preferences (defaults until `user_settings`
  /// loads or when the doc has none).
  NotificationPrefsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationPrefsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationPrefsHash();

  @$internal
  @override
  $ProviderElement<NotificationPrefs> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationPrefs create(Ref ref) {
    return notificationPrefs(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationPrefs value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationPrefs>(value),
    );
  }
}

String _$notificationPrefsHash() => r'a243f6d35a78dcdb05c297e6e04cab3e78df6ec2';

/// A notification deep link waiting to be opened. It is held while the app
/// is signed out, locked, picking a company or finishing a resume check,
/// and opened (once) by the root widget when [readyDeepLinkProvider] says
/// so.

@ProviderFor(PendingDeepLink)
final pendingDeepLinkProvider = PendingDeepLinkProvider._();

/// A notification deep link waiting to be opened. It is held while the app
/// is signed out, locked, picking a company or finishing a resume check,
/// and opened (once) by the root widget when [readyDeepLinkProvider] says
/// so.
final class PendingDeepLinkProvider
    extends $NotifierProvider<PendingDeepLink, String?> {
  /// A notification deep link waiting to be opened. It is held while the app
  /// is signed out, locked, picking a company or finishing a resume check,
  /// and opened (once) by the root widget when [readyDeepLinkProvider] says
  /// so.
  PendingDeepLinkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingDeepLinkProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingDeepLinkHash();

  @$internal
  @override
  PendingDeepLink create() => PendingDeepLink();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$pendingDeepLinkHash() => r'f61657f368c150afff20a6d099f284f9f245d4b6';

/// A notification deep link waiting to be opened. It is held while the app
/// is signed out, locked, picking a company or finishing a resume check,
/// and opened (once) by the root widget when [readyDeepLinkProvider] says
/// so.

abstract class _$PendingDeepLink extends $Notifier<String?> {
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

/// The pending deep link once it may be opened: unlocked, a company ready
/// and no auto-lock decision in flight. Null otherwise.

@ProviderFor(readyDeepLink)
final readyDeepLinkProvider = ReadyDeepLinkProvider._();

/// The pending deep link once it may be opened: unlocked, a company ready
/// and no auto-lock decision in flight. Null otherwise.

final class ReadyDeepLinkProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// The pending deep link once it may be opened: unlocked, a company ready
  /// and no auto-lock decision in flight. Null otherwise.
  ReadyDeepLinkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readyDeepLinkProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readyDeepLinkHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return readyDeepLink(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$readyDeepLinkHash() => r'83ec3b3f6af9e732a1584e200ee4ac14fe7c7442';

/// Wires notification taps to [PendingDeepLink]: initialises the plugin
/// and reads the payload that cold-started the app. Watched by the root
/// widget.

@ProviderFor(notificationBootstrap)
final notificationBootstrapProvider = NotificationBootstrapProvider._();

/// Wires notification taps to [PendingDeepLink]: initialises the plugin
/// and reads the payload that cold-started the app. Watched by the root
/// widget.

final class NotificationBootstrapProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Wires notification taps to [PendingDeepLink]: initialises the plugin
  /// and reads the payload that cold-started the app. Watched by the root
  /// widget.
  NotificationBootstrapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationBootstrapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationBootstrapHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return notificationBootstrap(ref);
  }
}

String _$notificationBootstrapHash() =>
    r'f338b9e5a560063425d509c711a3dba7e53ff06f';

/// Whether the OS lets this app post notifications (Settings shows a hint
/// when it does not). Re-read after a permission request.

@ProviderFor(notificationsAllowed)
final notificationsAllowedProvider = NotificationsAllowedProvider._();

/// Whether the OS lets this app post notifications (Settings shows a hint
/// when it does not). Re-read after a permission request.

final class NotificationsAllowedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether the OS lets this app post notifications (Settings shows a hint
  /// when it does not). Re-read after a permission request.
  NotificationsAllowedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationsAllowedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationsAllowedHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return notificationsAllowed(ref);
  }
}

String _$notificationsAllowedHash() =>
    r'2388209bf0ad84e2a16817062d38093a710a0961';

/// The Android 13+ `POST_NOTIFICATIONS` prompt.

@ProviderFor(notificationPermission)
final notificationPermissionProvider = NotificationPermissionProvider._();

/// The Android 13+ `POST_NOTIFICATIONS` prompt.

final class NotificationPermissionProvider
    extends
        $FunctionalProvider<
          NotificationPermission,
          NotificationPermission,
          NotificationPermission
        >
    with $Provider<NotificationPermission> {
  /// The Android 13+ `POST_NOTIFICATIONS` prompt.
  NotificationPermissionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationPermissionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationPermissionHash();

  @$internal
  @override
  $ProviderElement<NotificationPermission> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationPermission create(Ref ref) {
    return notificationPermission(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationPermission value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationPermission>(value),
    );
  }
}

String _$notificationPermissionHash() =>
    r'c6bbb92e5f06f6aa9e1fa7e70135fd6e35e597dd';

/// Keeps the device's local notifications in line with the active
/// company's schedule.
///
/// It re-plans (debounced, see [notificationDebounce]) whenever its inputs
/// change:
/// - the portfolio projection: a contract created or onboarded, a payment
///   recorded or reversed, a reschedule, rollover, waiver or cancellation,
///   and any change synced from another device all arrive as snapshot
///   changes;
/// - the active company (switch), the signed-in user, `user_settings`
///   notification prefs, the IST day;
/// - app start (the first build).
///
/// Signed out, no company or an account deletion in progress → everything
/// is cancelled. The plan itself is [planCollectionNotifications]; an
/// unchanged plan is not re-sent to the OS. State is the last plan sent
/// (null before the first run).

@ProviderFor(CollectionNotificationScheduler)
final collectionNotificationSchedulerProvider =
    CollectionNotificationSchedulerProvider._();

/// Keeps the device's local notifications in line with the active
/// company's schedule.
///
/// It re-plans (debounced, see [notificationDebounce]) whenever its inputs
/// change:
/// - the portfolio projection: a contract created or onboarded, a payment
///   recorded or reversed, a reschedule, rollover, waiver or cancellation,
///   and any change synced from another device all arrive as snapshot
///   changes;
/// - the active company (switch), the signed-in user, `user_settings`
///   notification prefs, the IST day;
/// - app start (the first build).
///
/// Signed out, no company or an account deletion in progress → everything
/// is cancelled. The plan itself is [planCollectionNotifications]; an
/// unchanged plan is not re-sent to the OS. State is the last plan sent
/// (null before the first run).
final class CollectionNotificationSchedulerProvider
    extends
        $NotifierProvider<
          CollectionNotificationScheduler,
          List<PlannedNotification>?
        > {
  /// Keeps the device's local notifications in line with the active
  /// company's schedule.
  ///
  /// It re-plans (debounced, see [notificationDebounce]) whenever its inputs
  /// change:
  /// - the portfolio projection: a contract created or onboarded, a payment
  ///   recorded or reversed, a reschedule, rollover, waiver or cancellation,
  ///   and any change synced from another device all arrive as snapshot
  ///   changes;
  /// - the active company (switch), the signed-in user, `user_settings`
  ///   notification prefs, the IST day;
  /// - app start (the first build).
  ///
  /// Signed out, no company or an account deletion in progress → everything
  /// is cancelled. The plan itself is [planCollectionNotifications]; an
  /// unchanged plan is not re-sent to the OS. State is the last plan sent
  /// (null before the first run).
  CollectionNotificationSchedulerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'collectionNotificationSchedulerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$collectionNotificationSchedulerHash();

  @$internal
  @override
  CollectionNotificationScheduler create() => CollectionNotificationScheduler();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<PlannedNotification>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<PlannedNotification>?>(value),
    );
  }
}

String _$collectionNotificationSchedulerHash() =>
    r'e637a03fa0d12785256b7a42400b5da916a268b0';

/// Keeps the device's local notifications in line with the active
/// company's schedule.
///
/// It re-plans (debounced, see [notificationDebounce]) whenever its inputs
/// change:
/// - the portfolio projection: a contract created or onboarded, a payment
///   recorded or reversed, a reschedule, rollover, waiver or cancellation,
///   and any change synced from another device all arrive as snapshot
///   changes;
/// - the active company (switch), the signed-in user, `user_settings`
///   notification prefs, the IST day;
/// - app start (the first build).
///
/// Signed out, no company or an account deletion in progress → everything
/// is cancelled. The plan itself is [planCollectionNotifications]; an
/// unchanged plan is not re-sent to the OS. State is the last plan sent
/// (null before the first run).

abstract class _$CollectionNotificationScheduler
    extends $Notifier<List<PlannedNotification>?> {
  List<PlannedNotification>? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<List<PlannedNotification>?, List<PlannedNotification>?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                List<PlannedNotification>?,
                List<PlannedNotification>?
              >,
              List<PlannedNotification>?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
