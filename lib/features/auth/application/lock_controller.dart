import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/time/clock_provider.dart';
import 'auth_providers.dart';
import 'session_controller.dart';

part 'lock_controller.g.dart';

/// Number of auto-lock resume checks running (normally 0 or 1). Non-zero
/// means "the app may be about to lock": deep links wait.
@Riverpod(keepAlive: true)
class LockCheckInFlight extends _$LockCheckInFlight {
  @override
  int build() => 0;

  void begin() => state = state + 1;

  void end() {
    if (state > 0) state = state - 1;
  }
}

/// Auto-lock on background.
///
/// State is the moment the unlocked app went to the background (null while
/// in the foreground). On resume, if it was away for at least the user's
/// `autoLockMinutes` (device-local, default 1), the session locks.
@Riverpod(keepAlive: true)
class LockController extends _$LockController {
  @override
  DateTime? build() {
    final listener = AppLifecycleListener(onStateChange: _onLifecycleChange);
    ref.onDispose(listener.dispose);
    return null;
  }

  void _onLifecycleChange(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        onBackgrounded();
      case AppLifecycleState.resumed:
        unawaited(onResumed());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Records when an unlocked session left the foreground (first event wins:
  /// Android sends hidden then paused).
  void onBackgrounded() {
    if (state != null) return;
    if (ref.read(sessionControllerProvider).stage != AuthStage.unlocked) {
      return;
    }
    state = ref.read(clockProvider).nowIst();
  }

  /// Locks if the app was in the background for >= autoLockMinutes.
  ///
  /// The timestamp is cleared at once, so a new background event during the
  /// (async) check is recorded and judged on the next resume. While the
  /// check runs, [LockCheckInFlight] is set (a notification deep link waits
  /// for it).
  Future<void> onResumed() async {
    final since = state;
    state = null;
    if (since == null) return;
    final inFlight = ref.read(lockCheckInFlightProvider.notifier)..begin();
    try {
      await _checkAfterResume(since);
    } finally {
      inFlight.end();
    }
  }

  Future<void> _checkAfterResume(DateTime since) async {
    final session = ref.read(sessionControllerProvider);
    final uid = session.user?.uid;
    if (session.stage != AuthStage.unlocked || uid == null) return;
    var minutes = AppConfig.defaultAutoLockMinutes;
    try {
      minutes = await ref.read(mpinStoreProvider).autoLockMinutes(uid);
    } on Object catch (e) {
      developer.log('autoLockMinutes read failed', name: 'auth', error: e);
    }
    if (!ref.mounted) return;
    final away = ref.read(clockProvider).nowIst().difference(since);
    if (away >= Duration(minutes: minutes)) {
      ref.read(sessionControllerProvider.notifier).lock();
    }
  }
}
