import 'package:flutter/widgets.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/money/money.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../domain/models/enums.dart';
import '../../application/contract_draft.dart';

/// Holds the loan-terms inputs shared by the create-contract and rollover
/// screens (sanctioned, upfront, frequency, installment, collection day,
/// first due date) and builds the live [ContractDraft]. The screen listens
/// and rebuilds; [LoanAmountFields] and [LoanScheduleFields] edit it.
class LoanTermsController extends ChangeNotifier {
  LoanTermsController({
    Money? sanctioned,
    Money? installment,
    Frequency frequency = Frequency.weekly,
    int? weekday,
    int? monthDay,
  }) : _frequency = frequency,
       _weekday = weekday,
       _monthDay = monthDay {
    if (sanctioned != null) setSanctioned(sanctioned, notify: false);
    if (installment != null) {
      this.installment.text = formatInrPlain(installment);
      _installmentValue = installment;
    }
  }

  final TextEditingController sanctioned = TextEditingController();
  final TextEditingController upfrontFlat = TextEditingController();
  final TextEditingController upfrontPct = TextEditingController();
  final TextEditingController installment = TextEditingController();

  Money? _sanctionedValue;
  Money? _flatValue;
  int? _pctBps;
  Money? _installmentValue;
  UpfrontMode _mode = UpfrontMode.flat;
  Frequency _frequency;
  int? _weekday;
  int? _monthDay;
  CivilDate? _firstDuePicked;

  Money? get sanctionedValue => _sanctionedValue;
  Money? get flatValue => _flatValue;
  int? get pctBps => _pctBps;
  Money? get installmentValue => _installmentValue;
  UpfrontMode get mode => _mode;
  Frequency get frequency => _frequency;

  /// Sets the sanctioned field's text and value (quick chips, prefill).
  void setSanctioned(Money m, {bool notify = true}) {
    sanctioned.text = formatInrPlain(m);
    _sanctionedValue = m;
    if (notify) notifyListeners();
  }

  void sanctionedChanged(Money? m) => _set(() => _sanctionedValue = m);
  void flatChanged(Money? m) => _set(() => _flatValue = m);
  void pctChanged(String text) => _set(() => _pctBps = parsePercentBps(text));
  void installmentChanged(Money? m) => _set(() => _installmentValue = m);
  void modeChanged(UpfrontMode m) => _set(() => _mode = m);

  void frequencyChanged(Frequency f) => _set(() {
    _frequency = f;
    _firstDuePicked = null;
  });

  void weekdayChanged(int d) => _set(() {
    _weekday = d;
    _firstDuePicked = null;
  });

  void monthDayChanged(int d) => _set(() {
    _monthDay = d;
    _firstDuePicked = null;
  });

  void firstDuePicked(CivilDate d) => _set(() => _firstDuePicked = d);

  CivilDate? _disbursedOn;

  /// The picked "Disbursed on" (onboarding only); null = today.
  CivilDate? get disbursedOn => _disbursedOn;

  /// Onboarding an existing loan: the original disbursement date. The
  /// default first collection date and collection day then follow it. A
  /// picked first date is kept only while it is still within
  /// [d, d + 366].
  void disbursedOnChanged(CivilDate d) => _set(() {
    _disbursedOn = d;
    final first = _firstDuePicked;
    if (first != null && (first.isBefore(d) || first.isAfter(d.addDays(366)))) {
      _firstDuePicked = null;
    }
  });

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }

  /// The live draft, disbursed on [today] (or the picked [disbursedOn]);
  /// weekday / month day default to that day's.
  ContractDraft draft(CivilDate today) {
    final base = _disbursedOn ?? today;
    final weekday = _weekday ?? base.weekday;
    final monthDay = _monthDay ?? base.day;
    return ContractDraft(
      sanctioned: _sanctionedValue,
      upfrontMode: _mode,
      upfrontInput: _mode == UpfrontMode.flat ? _flatValue?.paise : _pctBps,
      installmentAmount: _installmentValue,
      frequency: _frequency,
      weekday: weekday,
      monthDay: monthDay,
      firstDueDate:
          _firstDuePicked ??
          defaultFirstDue(
            base,
            _frequency,
            weekday: weekday,
            monthDay: monthDay,
          ),
      disbursedOn: base,
    );
  }

  @override
  void dispose() {
    sanctioned.dispose();
    upfrontFlat.dispose();
    upfrontPct.dispose();
    installment.dispose();
    super.dispose();
  }
}
