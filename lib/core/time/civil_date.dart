/// Pure-Dart civil date and clock interface (usable from `lib/domain/`).
///
/// Re-exported by `ist_clock.dart`; app code may import either.
library;

/// Source of "now". The ONLY way app code may learn the current time;
/// never call `DateTime.now()` in domain or UI code.
abstract interface class Clock {
  /// Current instant, with wall-clock fields (year, month, day, hour…) in
  /// IST (Asia/Kolkata).
  DateTime nowIst();
}

/// A calendar date with no time or zone (stored as `'yyyy-MM-dd'`, IST).
///
/// Pure value type; all arithmetic goes through UTC midnight, so there is
/// no DST drift.
final class CivilDate implements Comparable<CivilDate> {
  const CivilDate(this.year, this.month, this.day);

  factory CivilDate.fromDateTime(DateTime dateTime) =>
      CivilDate(dateTime.year, dateTime.month, dateTime.day);

  /// Today's civil date in IST.
  factory CivilDate.todayIst(Clock clock) =>
      CivilDate.fromDateTime(clock.nowIst());

  /// Parses `'yyyy-MM-dd'`. Throws [FormatException] on bad input or an
  /// impossible date such as `2023-02-30`.
  factory CivilDate.parse(String input) {
    final parsed = tryParse(input);
    if (parsed == null) {
      throw FormatException('Expected a yyyy-MM-dd civil date', input);
    }
    return parsed;
  }

  static final RegExp _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static CivilDate? tryParse(String input) {
    final match = _pattern.firstMatch(input);
    if (match == null) return null;
    final y = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final d = int.parse(match.group(3)!);
    if (m < 1 || m > 12 || d < 1 || d > daysInMonth(y, m)) return null;
    return CivilDate(y, m, d);
  }

  final int year;
  final int month;
  final int day;

  static int daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  static bool isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// 1 = Monday … 7 = Sunday.
  int get weekday => _utc.weekday;

  CivilDate addDays(int days) =>
      CivilDate.fromDateTime(_utc.add(Duration(days: days)));

  /// Adds [months], landing on [preferredDay] (default: this day) clamped to
  /// the target month's length. 31 Jan + 1 → 28 Feb (29 in a leap year);
  /// 28 Feb + 1 with preferredDay 31 → 31 Mar.
  CivilDate addMonthsClamped(int months, {int? preferredDay}) {
    final zeroBased = year * 12 + (month - 1) + months;
    final y = zeroBased ~/ 12;
    final m = zeroBased % 12 + 1;
    final wanted = preferredDay ?? day;
    final last = daysInMonth(y, m);
    return CivilDate(y, m, wanted > last ? last : wanted);
  }

  /// Signed whole days from this date to [other] (`other - this`).
  int daysBetween(CivilDate other) => other._utc.difference(_utc).inDays;

  bool isBefore(CivilDate other) => compareTo(other) < 0;
  bool isAfter(CivilDate other) => compareTo(other) > 0;

  @override
  int compareTo(CivilDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CivilDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// `'yyyy-MM-dd'` storage form.
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

const List<String> _monthsShort = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _weekdaysShort = <String>[
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
];

/// `'d MMM yyyy'` → "24 Oct 2023".
String formatCivilDate(CivilDate date) =>
    '${date.day} ${_monthsShort[date.month - 1]} ${date.year}';

/// `'EEE, d MMM'` → "Tue, 24 Oct".
String formatCivilDateWithWeekday(CivilDate date) =>
    '${_weekdaysShort[date.weekday - 1]}, ${date.day} '
    '${_monthsShort[date.month - 1]}';

/// `'d MMM'` → "8 Oct". Deterministic, locale-free (used in ledger labels).
String formatCivilDateDayMonth(CivilDate date) =>
    '${date.day} ${_monthsShort[date.month - 1]}';

/// Short English month name for 1–12 → "Jan" … "Dec".
String civilMonthShortName(int month) => _monthsShort[month - 1];
