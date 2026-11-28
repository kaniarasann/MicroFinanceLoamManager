import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../domain/ledger/notification_plan.dart';

/// One notification handed to the platform: the plan entry plus the go_router
/// location it opens.
final class ScheduledNotification {
  const ScheduledNotification(this.plan, this.payload);

  final PlannedNotification plan;
  final String payload;
}

/// Seam over `flutter_local_notifications` so the scheduler can be tested
/// with an in-memory fake.
abstract interface class LocalNotificationGateway {
  /// Sets up the plugin; [onTap] receives the payload of a notification the
  /// user taps while the app is running (foreground or background).
  Future<void> initialize(void Function(String payload) onTap);

  /// Payload of the notification that cold-started the app, if any.
  Future<String?> launchPayload();

  /// Asks for Android 13+ `POST_NOTIFICATIONS`. True when granted (or not
  /// needed on this OS version).
  Future<bool> requestPermission();

  /// Whether the user allows this app's notifications.
  Future<bool> areEnabled();

  /// Cancels every pending notification, then schedules [items].
  Future<void> replaceAll(List<ScheduledNotification> items);

  Future<void> cancelAll();
}

/// Android channels, one per kind, so the user can mute a kind in system
/// settings too.
abstract final class NotificationChannels {
  static const AndroidNotificationDetails digest = AndroidNotificationDetails(
    'collections_digest',
    'Daily collection digest',
    channelDescription: "Morning summary of today's collections",
    category: AndroidNotificationCategory.reminder,
    icon: _icon,
  );

  static const AndroidNotificationDetails installment =
      AndroidNotificationDetails(
        'collections_installment',
        'Installment reminders',
        channelDescription: 'A reminder for each installment due today',
        category: AndroidNotificationCategory.reminder,
        icon: _icon,
      );

  static const AndroidNotificationDetails overdue = AndroidNotificationDetails(
    'collections_overdue',
    'Overdue nudges',
    channelDescription: 'A daily nudge while installments are overdue',
    category: AndroidNotificationCategory.reminder,
    icon: _icon,
  );

  static const String _icon = 'ic_stat_ledger';

  static AndroidNotificationDetails of(NotificationKind kind) => switch (kind) {
    NotificationKind.digest => digest,
    NotificationKind.installment => installment,
    NotificationKind.overdue => overdue,
  };
}

/// [LocalNotificationGateway] over `flutter_local_notifications`.
///
/// Times are IST (Asia/Kolkata) whatever the device zone is. Scheduling is
/// inexact (`inexactAllowWhileIdle`): no SCHEDULE_EXACT_ALARM permission,
/// which Play restricts. The plugin's boot receiver restores the alarms
/// after a reboot.
final class FlutterLocalNotificationGateway
    implements LocalNotificationGateway {
  FlutterLocalNotificationGateway([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _init;

  static tz.Location get _ist {
    try {
      return tz.getLocation('Asia/Kolkata');
    } on Object {
      tz_data.initializeTimeZones();
      return tz.getLocation('Asia/Kolkata');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> initialize(void Function(String payload) onTap) {
    if (!_supported) return Future<void>.value();
    return _init ??= _plugin
        .initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_ledger'),
          ),
          onDidReceiveNotificationResponse: (NotificationResponse r) {
            final payload = r.payload;
            if (payload != null && payload.isNotEmpty) onTap(payload);
          },
        )
        .then<void>((_) {});
  }

  @override
  Future<String?> launchPayload() async {
    if (!_supported) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> areEnabled() async {
    if (!_supported) return false;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<void> replaceAll(List<ScheduledNotification> items) async {
    if (!_supported) return;
    // Pending alarms only: notifications already in the tray stay.
    await _plugin.cancelAllPendingNotifications();
    final ist = _ist;
    final now = tz.TZDateTime.now(ist);
    for (final item in items) {
      final p = item.plan;
      final at = tz.TZDateTime(
        ist,
        p.date.year,
        p.date.month,
        p.date.day,
        p.time.hour,
        p.time.minute,
      );
      if (!at.isAfter(now)) continue;
      try {
        await _plugin.zonedSchedule(
          id: p.id,
          scheduledDate: at,
          notificationDetails: NotificationDetails(
            android: NotificationChannels.of(p.kind),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: p.title,
          body: p.body,
          payload: item.payload,
        );
      } on Object catch (e) {
        developer.log(
          'zonedSchedule failed for ${p.id}',
          name: 'notifications',
          error: e,
        );
      }
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!_supported) return;
    await _plugin.cancelAll();
  }
}

/// In-memory [LocalNotificationGateway] for tests and previews.
final class InMemoryNotificationGateway implements LocalNotificationGateway {
  InMemoryNotificationGateway({this.permissionGranted = true});

  bool permissionGranted;
  String? pendingLaunchPayload;
  void Function(String payload)? onTap;
  List<ScheduledNotification> scheduled = <ScheduledNotification>[];
  int replaceCalls = 0;
  int cancelCalls = 0;
  int permissionRequests = 0;

  @override
  Future<void> initialize(void Function(String payload) onTap) async {
    this.onTap = onTap;
  }

  /// Simulates the user tapping a notification while the app runs.
  void tap(String payload) => onTap?.call(payload);

  @override
  Future<String?> launchPayload() async {
    final p = pendingLaunchPayload;
    pendingLaunchPayload = null;
    return p;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<bool> areEnabled() async => permissionGranted;

  @override
  Future<void> replaceAll(List<ScheduledNotification> items) async {
    replaceCalls++;
    scheduled = List<ScheduledNotification>.of(items);
  }

  @override
  Future<void> cancelAll() async {
    cancelCalls++;
    scheduled = <ScheduledNotification>[];
  }
}

/// Fires [action] and logs (never throws) on failure.
void logUnawaited(Future<void> action, String what) => unawaited(
  action.then<void>(
    (_) {},
    onError: (Object e) =>
        developer.log('$what failed', name: 'notifications', error: e),
  ),
);
