import '../../core/money/money.dart';
import '../../core/time/civil_date.dart';
import '../models/enums.dart';

/// Hard ceiling on base installments (keeps a create-contract batch under
/// Firestore's 500-op limit).
const int maxInstallmentCount = 366;

/// Weekday / month-day anchors for a schedule.
final class SchedulePrefs {
  const SchedulePrefs({this.weekday, this.monthDay});

  /// 1 = Mon … 7 = Sun. Used by [Frequency.weekly].
  final int? weekday;

  /// 1–31, clamped to the month length. Used by [Frequency.monthly].
  final int? monthDay;

  @override
  bool operator ==(Object other) =>
      other is SchedulePrefs &&
      other.weekday == weekday &&
      other.monthDay == monthDay;

  @override
  int get hashCode => Object.hash(weekday, monthDay);
}

/// One base installment to be written when a contract is created.
final class PlannedInstallment {
  const PlannedInstallment({
    required this.seq,
    required this.dueDate,
    required this.amount,
  });

  final int seq;
  final CivilDate dueDate;
  final Money amount;

  @override
  bool operator ==(Object other) =>
      other is PlannedInstallment &&
      other.seq == seq &&
      other.dueDate == dueDate &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(seq, dueDate, amount);

  @override
  String toString() => 'PlannedInstallment($seq, $dueDate, ${amount.paise})';
}

/// n = ⌈sanctioned / installment⌉. Requires both to be positive.
int installmentCount(Money sanctioned, Money installment) {
  if (sanctioned.paise <= 0 || installment.paise <= 0) {
    throw ArgumentError('sanctioned and installment must be positive');
  }
  return (sanctioned.paise + installment.paise - 1) ~/ installment.paise;
}

/// The first schedule date strictly after [after] for [frequency]:
///
/// - daily: `after + 1`;
/// - weekly: the next date (after [after]) on `prefs.weekday`; with no
///   preferred weekday, `after + 7`;
/// - monthly: the next date (after [after]) whose day is `prefs.monthDay`
///   clamped to that month's length (31 → 28/29 Feb → 31 Mar); with no
///   preferred day, [after]'s own day is the anchor.
///
/// When [after] is already on the anchor this is a plain +1 day / +7 days /
/// +1 month step, so it serves both the base schedule and the
/// auto-extension (whose last row may be a rescheduled, off-anchor date).
CivilDate nextDueDate(
  CivilDate after,
  Frequency frequency, [
  SchedulePrefs prefs = const SchedulePrefs(),
]) {
  switch (frequency) {
    case Frequency.daily:
      return after.addDays(1);
    case Frequency.weekly:
      final wanted = prefs.weekday;
      if (wanted == null) return after.addDays(7);
      var delta = (wanted - after.weekday) % 7;
      if (delta == 0) delta = 7;
      return after.addDays(delta);
    case Frequency.monthly:
      final anchor = prefs.monthDay ?? after.day;
      final thisMonth = after.addMonthsClamped(0, preferredDay: anchor);
      if (thisMonth.isAfter(after)) return thisMonth;
      return after.addMonthsClamped(1, preferredDay: anchor);
  }
}

/// The first schedule date on or after [from].
CivilDate firstDueOnOrAfter(
  CivilDate from,
  Frequency frequency, [
  SchedulePrefs prefs = const SchedulePrefs(),
]) => nextDueDate(from.addDays(-1), frequency, prefs);

/// Base schedule: ⌈sanctioned / installment⌉ rows of [installmentAmount],
/// the last taking the remainder (₹1,00,000 at ₹30,000 → 30k, 30k, 30k, 10k).
///
/// Dates start at the first anchor date ≥ [firstDueDate] and step with
/// [nextDueDate]. Throws [ArgumentError] on non-positive amounts or more
/// than [maxInstallmentCount] rows; call `validateContractTerms` first.
List<PlannedInstallment> generateSchedule({
  required Money sanctioned,
  required Money installmentAmount,
  required Frequency frequency,
  required CivilDate firstDueDate,
  int? preferredWeekday,
  int? preferredMonthDay,
}) {
  final n = installmentCount(sanctioned, installmentAmount);
  if (n > maxInstallmentCount) {
    throw ArgumentError.value(
      n,
      'installmentCount',
      'exceeds $maxInstallmentCount',
    );
  }
  // A missing anchor defaults to the first due date itself.
  final prefs = SchedulePrefs(
    weekday: preferredWeekday ?? firstDueDate.weekday,
    monthDay: preferredMonthDay ?? firstDueDate.day,
  );
  final last = sanctioned - installmentAmount * (n - 1);
  final rows = <PlannedInstallment>[];
  var date = firstDueOnOrAfter(firstDueDate, frequency, prefs);
  for (var i = 1; i <= n; i++) {
    if (i > 1) date = nextDueDate(date, frequency, prefs);
    rows.add(
      PlannedInstallment(
        seq: i,
        dueDate: date,
        amount: i == n ? last : installmentAmount,
      ),
    );
  }
  return rows;
}
