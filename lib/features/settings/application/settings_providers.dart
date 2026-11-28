import 'dart:async';
import 'dart:developer' as developer;

import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/time/clock_provider.dart';
import '../../../domain/models/models.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/application/session_controller.dart';
import '../../company/application/company_providers.dart';
import '../../notifications/application/notification_providers.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../data/account_repository.dart';
import '../data/sync_signals.dart';
import 'account_exit.dart';

part 'settings_providers.g.dart';

@Riverpod(keepAlive: true)
AccountRepository accountRepository(Ref ref) =>
    AccountRepository(firestore: ref.watch(firestoreProvider));

@Riverpod(keepAlive: true)
SyncSignals syncSignals(Ref ref) =>
    FirestoreSyncSignals(ref.watch(firestoreProvider));

/// "1.0.0 (build 1)".
@Riverpod(keepAlive: true)
Future<String> appVersion(Ref ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (build ${info.buildNumber})';
  } on Object {
    return '';
  }
}

/// Auto-lock choices in minutes (0 = as soon as the app leaves the screen).
const List<int> autoLockChoices = <int>[0, 1, 5, 15];

/// "Immediately" / "After 1 min" / "After 5 min".
String autoLockLabel(int minutes) =>
    minutes == 0 ? 'Immediately' : 'After $minutes min';

/// The device-local auto-lock delay (secure storage, per uid). Device-local
/// on purpose: it is a property of this phone's lock, like the MPIN.
@riverpod
Future<int> autoLockMinutes(Ref ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return AppConfig.defaultAutoLockMinutes;
  return ref.watch(mpinStoreProvider).autoLockMinutes(uid);
}

/// Whether this device can do biometric unlock.
@riverpod
Future<bool> biometricAvailable(Ref ref) =>
    ref.watch(biometricServiceProvider).canCheck();

/// Sync state shown on the Settings card.
enum SyncPhase { synced, pending, offline }

final class SyncState {
  const SyncState(this.phase, {this.lastSyncedAt});

  final SyncPhase phase;

  /// When pending writes last reached the server (this session).
  final DateTime? lastSyncedAt;
}

/// Online + pending-writes state. Pending is true while
/// `waitForPendingWrites` has not completed; it is re-checked whenever the
/// Firestore listeners come back in sync.
@riverpod
class SyncStatus extends _$SyncStatus {
  int _generation = 0;
  bool _online = true;
  bool _pending = false;
  DateTime? _last;

  @override
  SyncState build() {
    final signals = ref.watch(syncSignalsProvider);
    final online = signals.online().listen((bool v) {
      _online = v;
      _emit();
      if (v) _check(signals);
    });
    final sync = signals.inSync().listen((_) => _check(signals));
    ref.onDispose(() {
      unawaited(online.cancel());
      unawaited(sync.cancel());
    });
    _check(signals);
    return const SyncState(SyncPhase.synced);
  }

  void _check(SyncSignals signals) {
    final gen = ++_generation;
    var done = false;
    unawaited(
      signals.waitForPendingWrites().then<void>(
        (_) {
          done = true;
          if (!ref.mounted || gen != _generation) return;
          if (_pending) _last = ref.read(clockProvider).nowIst();
          _pending = false;
          _emit();
        },
        onError: (Object e) =>
            developer.log('waitForPendingWrites', name: 'sync', error: e),
      ),
    );
    // Still waiting after this microtask turn → writes are pending.
    scheduleMicrotask(() {
      if (done || !ref.mounted || gen != _generation) return;
      _pending = true;
      _emit();
    });
  }

  void _emit() {
    if (!ref.mounted) return;
    state = SyncState(
      !_online
          ? SyncPhase.offline
          : (_pending ? SyncPhase.pending : SyncPhase.synced),
      lastSyncedAt: _last,
    );
  }
}

/// No automatic retry: offline the preview fails fast with its message
/// instead of spinning through Riverpod's default back-off.
Duration? noRetry(int retryCount, Object error) => null;

/// The deletion preview for the signed-in user (server reads; fails
/// offline).
@Riverpod(retry: noRetry)
Future<AccountExitPlan> accountExitPlan(Ref ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) throw const PermissionDeniedFailure();
  final facts = await ref.watch(accountRepositoryProvider).loadExitFacts(uid);
  return AccountExitPlan(uid, facts);
}

/// Outcome of [SettingsActions.deleteAccount].
enum DeleteAccountResult {
  deleted,
  cancelled,

  /// The batch is queued on this phone (sent while the connection dropped).
  /// Clean-up and the Auth deletion run when the server acknowledges it.
  pending,
}

/// Shown while a queued deletion waits for the server.
const String deletionPendingMessage =
    "Deletion will finish when you're back online. Keep the app open or "
    'open it again once connected.';

/// Shown if the server later rejects a queued deletion.
const String deletionFailedMessage =
    "Your account couldn't be deleted. Please try again.";

@Riverpod(keepAlive: true)
SettingsActions settingsActions(Ref ref) => SettingsActions(ref);

/// Settings use-cases.
class SettingsActions {
  SettingsActions(this._ref);

  final Ref _ref;

  String get _uid {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) throw const PermissionDeniedFailure();
    return uid;
  }

  /// Saves the notification preferences (`user_settings.notifications`,
  /// offline-safe). Turning a kind on asks for the OS permission when it is
  /// not granted yet.
  Future<void> setNotificationPrefs(NotificationPrefs prefs) async {
    final before = _ref.read(notificationPrefsProvider);
    await _ref
        .read(userSettingsRepositoryProvider)
        .setNotificationPrefs(_uid, prefs);
    final turnedOn =
        (prefs.digestEnabled && !before.digestEnabled) ||
        (prefs.perInstallmentEnabled && !before.perInstallmentEnabled) ||
        (prefs.overdueNudgeEnabled && !before.overdueNudgeEnabled);
    if (turnedOn) {
      final allowed = await _ref
          .read(localNotificationGatewayProvider)
          .areEnabled();
      if (!allowed) {
        await _ref.read(notificationPermissionProvider).request();
      }
    }
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    await _ref.read(mpinStoreProvider).setAutoLockMinutes(_uid, minutes);
    _ref.invalidate(autoLockMinutesProvider);
  }

  /// Signs out: cancels this device's notifications first (they belong to
  /// the signed-in user's company).
  Future<void> signOut() async {
    try {
      await _ref
          .read(collectionNotificationSchedulerProvider.notifier)
          .cancelAll();
    } on Object catch (e) {
      developer.log('Cancel on sign-out failed', name: 'settings', error: e);
    }
    await _ref.read(sessionControllerProvider.notifier).signOut();
  }

  /// Deletes the account (Google Play account-deletion policy):
  /// 1. Google re-auth (cancel → [DeleteAccountResult.cancelled]);
  /// 2. a fresh server preview; blocked if a sole-owner hand-over is due;
  /// 3. one batch: leave / close every company, delete `user_settings` and
  ///    `users/{uid}` (ledger records are kept);
  /// 4. cancel notifications, wipe this device's MPIN, schedule a cache
  ///    clear, delete the Firebase Auth user.
  ///
  /// The removed-member guard and the scheduler stand down meanwhile
  /// ([AccountDeletionInProgress]). Throws [AppFailure].
  Future<DeleteAccountResult> deleteAccount() async {
    final uid = _uid;
    final flag = _ref.read(accountDeletionInProgressProvider.notifier);
    final auth = _ref.read(authRepositoryProvider);
    // Refuse up front when the phone is offline (the server reads below
    // would fail too, but only after the Google prompt).
    final online = await _ref
        .read(syncSignalsProvider)
        .online()
        .first
        .timeout(const Duration(seconds: 2), onTimeout: () => true);
    if (!online) throw const OfflineRequiredFailure();
    if (!await auth.reauthenticateWithGoogle()) {
      return DeleteAccountResult.cancelled;
    }
    flag.start();
    try {
      final facts = await _ref
          .read(accountRepositoryProvider)
          .loadExitFacts(uid);
      final plan = AccountExitPlan(uid, facts);
      if (plan.isBlocked) {
        throw ValidationFailure('account', plan.blocked.first.description);
      }
      await _ref.read(accountRepositoryProvider).commitExit(uid, plan);
    } on AckPendingFailure catch (p) {
      // Queued, not failed: keep the flag (guard + scheduler stand down) and
      // finish when the server acknowledges the batch.
      unawaited(
        p.ack.then<void>(
          (_) => _finishDeletion(),
          onError: (Object e) {
            developer.log('Queued deletion failed', name: 'settings', error: e);
            flag.finish();
            _ref
                .read(companyNoticeProvider.notifier)
                .show(deletionFailedMessage);
          },
        ),
      );
      return DeleteAccountResult.pending;
    } on Object {
      flag.finish();
      rethrow;
    }
    await _finishDeletion();
    return DeleteAccountResult.deleted;
  }

  /// After the deletion batch is acknowledged.
  Future<void> _finishDeletion() async {
    // Past this point the data is gone; finish the device clean-up and the
    // Auth deletion whatever happens.
    try {
      await _ref
          .read(collectionNotificationSchedulerProvider.notifier)
          .cancelAll();
    } on Object catch (e) {
      developer.log('Cancel notifications failed', name: 'settings', error: e);
    }
    try {
      await _ref.read(cacheResetFlagProvider).schedule();
    } on Object catch (e) {
      developer.log('Cache reset flag failed', name: 'settings', error: e);
    }
    await _ref
        .read(sessionControllerProvider.notifier)
        .completeAccountDeletion();
  }
}
