import '../../../core/money/money.dart';
import '../../../core/time/civil_date.dart';
import '../../../domain/ledger/ledger.dart';
import '../../../domain/models/enums.dart';

/// The create-contract form's current values and everything derived from
/// them live (upfront, net cash handover, effective %, cycles, schedule
/// preview, validation). Pure; the screen rebuilds it on every edit.
final class ContractDraft {
  const ContractDraft({
    required this.frequency,
    required this.firstDueDate,
    required this.disbursedOn,
    this.sanctioned,
    this.upfrontMode = UpfrontMode.flat,
    this.upfrontInput,
    this.installmentAmount,
    this.weekday,
    this.monthDay,
  });

  final Money? sanctioned;
  final UpfrontMode upfrontMode;

  /// Paise (flat) or basis points (percent); null while empty.
  final int? upfrontInput;
  final Money? installmentAmount;
  final Frequency frequency;
  final int? weekday;
  final int? monthDay;
  final CivilDate firstDueDate;
  final CivilDate disbursedOn;

  Money get _sanctioned => sanctioned ?? Money.zero;

  Money get upfront => sanctioned == null
      ? Money.zero
      : computeUpfront(_sanctioned, upfrontMode, upfrontInput ?? 0);

  Money get netDisbursed => computeNetDisbursed(_sanctioned, upfront);

  /// Upfront as basis points of sanctioned.
  int get effectiveBps => effectiveBpsOf(upfront, _sanctioned);

  /// ⌈sanctioned / installment⌉ when both are positive.
  int? get cycles {
    final s = sanctioned;
    final i = installmentAmount;
    if (s == null || i == null || !s.isPositive || !i.isPositive) return null;
    return installmentCount(s, i);
  }

  List<ValidationError> get errors => validateContractTerms(
    sanctioned: _sanctioned,
    upfrontMode: upfrontMode,
    upfrontInput: upfrontInput ?? 0,
    installmentAmount: installmentAmount ?? Money.zero,
    frequency: frequency,
    preferredWeekday: frequency == Frequency.weekly ? weekday : null,
    preferredMonthDay: frequency == Frequency.monthly ? monthDay : null,
    firstDueDate: firstDueDate,
    disbursedOn: disbursedOn,
  );

  /// First error message for [field], if any.
  String? errorFor(String field) {
    for (final e in errors) {
      if (e.field == field) return e.message;
    }
    return null;
  }

  /// The base schedule, or null while the terms are invalid.
  List<PlannedInstallment>? get schedule {
    if (errors.isNotEmpty) return null;
    return generateSchedule(
      sanctioned: _sanctioned,
      installmentAmount: installmentAmount!,
      frequency: frequency,
      firstDueDate: firstDueDate,
      preferredWeekday: frequency == Frequency.weekly ? weekday : null,
      preferredMonthDay: frequency == Frequency.monthly ? monthDay : null,
    );
  }
}

/// [effectiveBps] re-exported under a name that does not clash with the
/// getter.
int effectiveBpsOf(Money upfront, Money sanctioned) =>
    effectiveBps(upfront, sanctioned);

/// The default first collection date: the next matching day after [today]
/// (daily: tomorrow; weekly: the next [weekday]; monthly: the next
/// [monthDay], clamped).
CivilDate defaultFirstDue(
  CivilDate today,
  Frequency frequency, {
  int? weekday,
  int? monthDay,
}) => nextDueDate(
  today,
  frequency,
  SchedulePrefs(weekday: weekday, monthDay: monthDay),
);

final RegExp _percentPattern = RegExp(r'^(\d{1,3})(?:\.(\d{0,2}))?$');

/// "7" → 700, "7.5" → 750, "12.25" → 1225 basis points. Null for empty or
/// malformed input or more than two decimals. Range is checked by
/// `validateContractTerms`.
int? parsePercentBps(String input) {
  final m = _percentPattern.firstMatch(input.trim());
  if (m == null) return null;
  final whole = int.parse(m.group(1)!);
  final frac = (m.group(2) ?? '').padRight(2, '0');
  return whole * 100 + int.parse(frac);
}

/// Basis points with one decimal, rounded half up: 700 → "7.0%",
/// 750 → "7.5%", 725 → "7.3%".
String formatBpsPercent(int bps) {
  final tenths = (bps + 5) ~/ 10;
  return '${tenths ~/ 10}.${tenths % 10}%';
}
