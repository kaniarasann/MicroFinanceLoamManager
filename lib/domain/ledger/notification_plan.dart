import '../../core/money/inr_format.dart';
import '../../core/money/money.dart';
import '../../core/time/civil_date.dart';
import '../models/user_settings.dart';
import 'portfolio_metrics.dart';

/// How many days ahead (today included) local notifications are scheduled.
/// Android caps pending alarms per app, so the plan never goes further.
const int notificationWindowDays = 14;

/// Upper bound on per-installment reminders in one plan. Together with at
/// most 2 × [notificationWindowDays] digests and nudges this stays well
/// under Android's 500-alarm limit. Reminders past the cap are dropped (the
/// daily digest still covers those rows).
const int maxInstallmentReminders = 300;

/// The three kinds of collection notification.
enum NotificationKind {
  /// "5 collections due today · ₹42,500" → Dashboard, Due Today.
  digest,

  /// "Suresh Verma · Loan #04 · ₹3,500 due today" → Record Payment.
  installment,

  /// "3 overdue · ₹25,500 · highest 5 days" → Overdue tracker.
  overdue,
}

/// A wall-clock time of day in IST.
final class DigestTime {
  const DigestTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24, 'hour'),
      assert(minute >= 0 && minute < 60, 'minute');

  /// 08:00, the default digest time.
  static const DigestTime fallback = DigestTime(8, 0);

  static final RegExp _pattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  /// Parses `'HH:mm'` (24 h). Returns [fallback] for anything else.
  factory DigestTime.parse(String? value) {
    final m = _pattern.firstMatch(value ?? '');
    if (m == null) return fallback;
    return DigestTime(int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  final int hour;
  final int minute;

  /// Minutes since midnight.
  int get minuteOfDay => hour * 60 + minute;

  /// `'HH:mm'`, the stored form.
  String get stored =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// "8:00 AM" / "6:30 PM".
  String get display {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour < 12 ? 'AM' : 'PM';
    return '$h12:${minute.toString().padLeft(2, '0')} $suffix';
  }

  @override
  bool operator ==(Object other) =>
      other is DigestTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => stored;
}

/// One local notification to schedule, at [date] [time] IST.
final class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.kind,
    required this.date,
    required this.time,
    required this.title,
    required this.body,
    this.contractId,
    this.companyId,
  });

  /// Stable within a plan: digests 100+day, nudges 200+day, reminders
  /// 1000+n. The scheduler cancels everything before re-scheduling.
  final int id;
  final NotificationKind kind;
  final CivilDate date;
  final DigestTime time;
  final String title;
  final String body;

  /// [NotificationKind.installment] only: the loan to collect on.
  final String? contractId;

  /// The company the plan was made for (deep links carry it, so a tapped
  /// notification never opens inside another company).
  final String? companyId;

  @override
  bool operator ==(Object other) =>
      other is PlannedNotification &&
      other.id == id &&
      other.kind == kind &&
      other.date == date &&
      other.time == time &&
      other.title == title &&
      other.body == body &&
      other.contractId == contractId &&
      other.companyId == companyId;

  @override
  int get hashCode =>
      Object.hash(id, kind, date, time, title, body, contractId, companyId);

  @override
  String toString() =>
      'PlannedNotification($id ${kind.name} $date $time "$title" "$body")';
}

/// Base ids per kind (see [PlannedNotification.id]).
const int digestIdBase = 100;
const int overdueIdBase = 200;
const int installmentIdBase = 1000;

/// Builds the local-notification plan for the active company.
///
/// Pure: the caller passes the projected rows, so the plan never reads a
/// clock or the database.
///
/// - [rows]: schedule rows due in `today .. today + windowDays - 1`
///   (`PortfolioMetrics.dueItemsBetween`). History rows, auto-extension rows
///   (they re-plan money that is already overdue) and fully paid rows never
///   notify.
/// - [overdue]: today's overdue rows (`PortfolioMetrics.overdueList`).
/// - [companyId]: carried on every entry (deep links name their company).
///   Ids are per plan, not per company: the scheduler cancels every pending
///   and delivered notification when the active company changes.
/// - [nowMinuteOfDay]: the IST time now. Today's slot is planned only while
///   the digest time is still ahead.
///
/// Every notification fires at the digest time. For a future day the plan
/// assumes no further payments: a row still open becomes overdue the day
/// after it is due, and today's overdue rows age by one day per day. Any
/// payment, reversal, reschedule, rollover or sync re-runs the plan.
List<PlannedNotification> planCollectionNotifications({
  required NotificationPrefs prefs,
  required CivilDate today,
  required int nowMinuteOfDay,
  required List<DueRowItem> rows,
  required List<OverdueItem> overdue,
  required String companyName,
  String? companyId,
  int windowDays = notificationWindowDays,
  int maxReminders = maxInstallmentReminders,
}) {
  final time = DigestTime.parse(prefs.digestTime);
  final last = today.addDays(windowDays - 1);
  final open = <DueRowItem>[
    for (final r in rows)
      if (!r.isHistory &&
          !r.isExtension &&
          !r.isPaid &&
          !r.dueDate.isBefore(today) &&
          !r.dueDate.isAfter(last))
        r,
  ];

  final out = <PlannedNotification>[];
  var reminders = 0;
  for (var d = 0; d < windowDays; d++) {
    if (d == 0 && nowMinuteOfDay >= time.minuteOfDay) continue;
    final date = today.addDays(d);
    final dueThatDay = <DueRowItem>[
      for (final r in open)
        if (r.dueDate == date) r,
    ];

    if (prefs.digestEnabled && dueThatDay.isNotEmpty) {
      final total = Money.sum(dueThatDay.map((DueRowItem r) => r.remaining));
      out.add(
        PlannedNotification(
          id: digestIdBase + d,
          kind: NotificationKind.digest,
          date: date,
          time: time,
          title: companyName,
          companyId: companyId,
          body:
              '${_count(dueThatDay.length, 'collection')} due today · '
              '${formatInr(total)}',
        ),
      );
    }

    if (prefs.perInstallmentEnabled) {
      for (final r in dueThatDay) {
        if (reminders >= maxReminders) break;
        out.add(
          PlannedNotification(
            id: installmentIdBase + reminders,
            kind: NotificationKind.installment,
            date: date,
            time: time,
            title: companyName,
            companyId: companyId,
            body:
                '${r.borrowerName} · Loan ${_loanNo(r.loanNo)} · '
                '${formatInr(r.remaining)} due today',
            contractId: r.contractId,
          ),
        );
        reminders++;
      }
    }

    if (prefs.overdueNudgeEnabled) {
      var count = 0;
      var amount = 0;
      var maxDays = 0;
      for (final o in overdue) {
        count++;
        amount += o.amount.paise;
        final days = o.daysOverdue + d;
        if (days > maxDays) maxDays = days;
      }
      for (final r in open) {
        if (!r.dueDate.isBefore(date)) continue;
        count++;
        amount += r.remaining.paise;
        final days = r.dueDate.daysBetween(date);
        if (days > maxDays) maxDays = days;
      }
      if (count > 0) {
        out.add(
          PlannedNotification(
            id: overdueIdBase + d,
            kind: NotificationKind.overdue,
            date: date,
            time: time,
            title: companyName,
            companyId: companyId,
            body:
                '$count overdue · ${formatInr(Money(amount))} · '
                'highest ${_count(maxDays, 'day')}',
          ),
        );
      }
    }
  }
  return List<PlannedNotification>.unmodifiable(out);
}

/// "#04".
String _loanNo(int n) => '#${n.toString().padLeft(2, '0')}';

String _count(int n, String noun) => n == 1 ? '1 $noun' : '$n ${noun}s';
