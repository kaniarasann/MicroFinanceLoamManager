import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/time/clock_provider.dart';
import '../../../domain/ledger/ledger.dart';
import '../../../domain/models/models.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/application/lock_controller.dart';
import '../../auth/application/session_controller.dart';
import '../../company/application/company_providers.dart';
import '../../dashboard/application/portfolio_providers.dart';
import '../data/local_notification_gateway.dart';

part 'notification_providers.g.dart';

/// The platform notification seam (tests override it with
/// [InMemoryNotificationGateway]).
@Riverpod(keepAlive: true)
LocalNotificationGateway localNotificationGateway(Ref ref) =>
    FlutterLocalNotificationGateway();

/// Quiet period before a data change re-plans the notifications. Snapshot
/// bursts (a batch landing, a sync from another device) collapse into one
/// run.
@Riverpod(keepAlive: true)
Duration notificationDebounce(Ref ref) => const Duration(seconds: 2);

/// The user's notification preferences (defaults until `user_settings`
/// loads or when the doc has none).
@Riverpod(keepAlive: true)
NotificationPrefs notificationPrefs(Ref ref) =>
    ref.watch(userSettingsProvider).value?.notifications ??
    const NotificationPrefs();

/// The go_router location a planned notification opens, tagged with its
/// company (`c=`) when the plan names one.
String notificationPayload(PlannedNotification n) {
  final base = switch (n.kind) {
    NotificationKind.digest => AppRoutes.dueToday,
    NotificationKind.overdue => AppRoutes.overdue,
    NotificationKind.installment => AppRoutes.recordPayment(n.contractId!),
  };
  final cid = n.companyId;
  return cid == null ? base : AppRoutes.withCompany(base, cid);
}

/// A notification deep link waiting to be opened. It is held while the app
/// is signed out, locked, picking a company or finishing a resume check,
/// and opened (once) by the root widget when [readyDeepLinkProvider] says
/// so.
@Riverpod(keepAlive: true)
class PendingDeepLink extends _$PendingDeepLink {
  @override
  String? build() => null;

  /// Keeps [location] when it is a known notification target.
  void offer(String? location) {
    if (location == null || !AppRoutes.isNotificationTarget(location)) return;
    state = location;
  }

  /// Returns the pending location and clears it.
  String? consume() {
    final s = state;
    state = null;
    return s;
  }
}

/// The pending deep link once it may be opened: unlocked, a company ready
/// and no auto-lock decision in flight. Null otherwise.
@Riverpod(keepAlive: true)
String? readyDeepLink(Ref ref) {
  final link = ref.watch(pendingDeepLinkProvider);
  if (link == null) return null;
  final stage = ref.watch(
    sessionControllerProvider.select((SessionState s) => s.stage),
  );
  if (stage != AuthStage.unlocked) return null;
  if (ref.watch(companyGateProvider) != CompanyGate.ready) return null;
  // Backgrounded, or the auto-lock decision is still running.
  if (ref.watch(lockControllerProvider) != null) return null;
  if (ref.watch(lockCheckInFlightProvider) > 0) return null;
  return link;
}

/// Wires notification taps to [PendingDeepLink]: initialises the plugin
/// and reads the payload that cold-started the app. Watched by the root
/// widget.
@Riverpod(keepAlive: true)
Future<void> notificationBootstrap(Ref ref) async {
  final gateway = ref.watch(localNotificationGatewayProvider);
  final links = ref.read(pendingDeepLinkProvider.notifier);
  try {
    await gateway.initialize(links.offer);
    links.offer(await gateway.launchPayload());
  } on Object catch (e) {
    developer.log('Notification init failed', name: 'notifications', error: e);
  }
}

/// Secure-storage flag: the Android 13 permission prompt was shown once.
const String notificationPermissionAskedKey = 'nl.notifications.asked';

/// Whether the OS lets this app post notifications (Settings shows a hint
/// when it does not). Re-read after a permission request.
@riverpod
Future<bool> notificationsAllowed(Ref ref) =>
    ref.watch(localNotificationGatewayProvider).areEnabled();

/// The Android 13+ `POST_NOTIFICATIONS` prompt.
@Riverpod(keepAlive: true)
NotificationPermission notificationPermission(Ref ref) =>
    NotificationPermission(ref);

class NotificationPermission {
  NotificationPermission(this._ref);

  final Ref _ref;
  bool _askedThisSession = false;

  /// Asks once per install, at first use (the first unlocked session with a
  /// company). A denial is respected; the app keeps working.
  Future<void> askOnce() async {
    if (_askedThisSession) return;
    _askedThisSession = true;
    final store = _ref.read(secureKeyValueStoreProvider);
    try {
      if (await store.read(notificationPermissionAskedKey) != null) return;
      await store.write(notificationPermissionAskedKey, '1');
      await _ref.read(localNotificationGatewayProvider).requestPermission();
      _ref.invalidate(notificationsAllowedProvider);
    } on Object catch (e) {
      developer.log(
        'Permission prompt failed',
        name: 'notifications',
        error: e,
      );
    }
  }

  /// Asks again (Settings, after the user turns a kind on). Returns whether
  /// notifications are allowed afterwards.
  Future<bool> request() async {
    try {
      final ok = await _ref
          .read(localNotificationGatewayProvider)
          .requestPermission();
      _ref.invalidate(notificationsAllowedProvider);
      return ok;
    } on Object catch (e) {
      developer.log(
        'Permission request failed',
        name: 'notifications',
        error: e,
      );
      return false;
    }
  }
}

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
@Riverpod(keepAlive: true)
class CollectionNotificationScheduler
    extends _$CollectionNotificationScheduler {
  Timer? _debounce;
  Future<void> _chain = Future<void>.value();
  bool _cleared = false;

  /// Company of the notifications currently scheduled / shown (null when
  /// none). A different active company cancels them at once.
  String? _plannedCid;

  @override
  List<PlannedNotification>? build() {
    void poke(Object? _, Object? _) => _schedule();
    ref
      ..listen<Object?>(portfolioProvider, poke)
      ..listen<Object?>(notificationPrefsProvider, poke)
      ..listen<AsyncValue<String?>>(activeCompanyIdProvider, (_, next) {
        _onCompanyChanged(next.value);
        _schedule();
      })
      ..listen<Object?>(activeCompanyNameProvider, poke)
      ..listen<Object?>(currentUidProvider, poke)
      ..listen<Object?>(accountDeletionInProgressProvider, poke)
      ..listen<AuthStage>(
        sessionControllerProvider.select((SessionState s) => s.stage),
        (_, _) {
          _maybeAskPermission();
          _schedule();
        },
      )
      ..listen<CompanyGate>(
        companyGateProvider,
        (_, _) => _maybeAskPermission(),
      )
      ..onDispose(() => _debounce?.cancel());
    _schedule();
    return null;
  }

  /// A company switch (or losing the company) cancels the previous
  /// company's pending alarms AND its notifications in the tray right away,
  /// without waiting for the new company's figures or the debounce, so an
  /// old reminder can never be tapped into the new company.
  void _onCompanyChanged(String? cid) {
    final planned = _plannedCid;
    if (planned == null || planned == cid) return;
    _plannedCid = null;
    _chain = _chain.then((_) => _cancelEverything()).catchError((Object e) {
      developer.log('Cancel on switch failed', name: 'notifications', error: e);
    });
  }

  Future<void> _cancelEverything() async {
    await ref.read(localNotificationGatewayProvider).cancelAll();
    _cleared = true;
    if (ref.mounted) state = const <PlannedNotification>[];
  }

  /// First use = the first unlocked session with a company.
  void _maybeAskPermission() {
    if (ref.read(sessionControllerProvider).stage == AuthStage.unlocked &&
        ref.read(companyGateProvider) == CompanyGate.ready) {
      unawaited(ref.read(notificationPermissionProvider).askOnce());
    }
  }

  void _schedule() {
    _debounce?.cancel();
    final wait = ref.read(notificationDebounceProvider);
    if (wait == Duration.zero) {
      // Tests: coalesce into one microtask instead of a timer.
      if (_microtaskQueued) return;
      _microtaskQueued = true;
      scheduleMicrotask(() {
        _microtaskQueued = false;
        _enqueueRun();
      });
      return;
    }
    _debounce = Timer(wait, _enqueueRun);
  }

  bool _microtaskQueued = false;

  void _enqueueRun() {
    _chain = _chain.then((_) => run()).catchError((Object e) {
      developer.log('Re-plan failed', name: 'notifications', error: e);
    });
  }

  /// Re-plans now (the debounce timer calls this).
  @visibleForTesting
  Future<void> run() async {
    if (!ref.mounted) return;
    final gateway = ref.read(localNotificationGatewayProvider);
    final uid = ref.read(currentUidProvider);
    final cid = ref.read(activeCompanyIdProvider).value;
    if (uid == null ||
        cid == null ||
        ref.read(accountDeletionInProgressProvider)) {
      _plannedCid = null;
      if (!_cleared) {
        _cleared = true;
        await gateway.cancelAll();
      }
      if (ref.mounted) state = const <PlannedNotification>[];
      return;
    }
    final metrics = ref.read(portfolioProvider).value;
    if (metrics == null) return; // still loading this company
    if (_plannedCid != null && _plannedCid != cid) {
      _plannedCid = null;
      await _cancelEverything();
    }
    final plan = _plan(metrics, cid);
    if (listEquals(plan, state)) return;
    await gateway.replaceAll(<ScheduledNotification>[
      for (final n in plan) ScheduledNotification(n, notificationPayload(n)),
    ]);
    _cleared = false;
    _plannedCid = cid;
    if (ref.mounted) state = plan;
  }

  List<PlannedNotification> _plan(PortfolioMetrics metrics, String cid) {
    final today = metrics.today;
    final now = ref.read(clockProvider).nowIst();
    final nowDate = CivilDate.fromDateTime(now);
    final int nowMinute;
    if (nowDate == today) {
      nowMinute = now.hour * 60 + now.minute;
    } else {
      // The projection is a day behind or ahead of the clock (just past
      // midnight, before the day ticker re-projects).
      nowMinute = nowDate.isAfter(today) ? 24 * 60 : 0;
    }
    return planCollectionNotifications(
      prefs: ref.read(notificationPrefsProvider),
      today: today,
      nowMinuteOfDay: nowMinute,
      rows: metrics.dueItemsBetween(
        today,
        today.addDays(notificationWindowDays - 1),
      ),
      overdue: metrics.overdueList,
      companyName: ref.read(activeCompanyNameProvider) ?? 'Nordic Ledger',
      companyId: cid,
    );
  }

  /// Cancels every notification (sign-out, account deletion).
  Future<void> cancelAll() async {
    _debounce?.cancel();
    _plannedCid = null;
    await ref.read(localNotificationGatewayProvider).cancelAll();
    _cleared = true;
    if (ref.mounted) state = const <PlannedNotification>[];
  }
}
