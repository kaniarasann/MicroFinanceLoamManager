import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

import '../../../core/money/inr_format.dart';
import '../../../core/money/money.dart';
import '../../../core/time/civil_date.dart';
import '../../../domain/ledger/ledger.dart';
import '../../../domain/models/models.dart';
import '../data/contract_repository.dart';
import 'contract_draft.dart';

/// How "Collected so far" is entered on the onboarding screen.
enum PastPaymentsMode { openingTotal, itemised }

/// The onboarding form's current values and everything derived from them:
/// the payments that would be saved (only the selected mode, never both),
/// validation, the spread helper line and the live "As of today" preview.
///
/// The preview is built by the same [planOnboarding] the repository runs
/// on save, then [projectContract] (the projection the contract detail
/// uses), so it matches the saved loan to the paisa. Pure; the screen
/// rebuilds it on every edit.
final class OnboardingDraft {
  OnboardingDraft({
    required this.terms,
    required this.today,
    this.mode = PastPaymentsMode.openingTotal,
    this.openingTotal,
    this.openingMode = PaymentMode.cash,
    this.rows = const <PastPaymentInput>[],
    this.previousRef,
    this.cachedNextLoanNo = 0,
  });

  /// Loan terms with the original `disbursedOn` / `firstDueDate`.
  final ContractDraft terms;

  /// IST today (stored as `onboardedOn`).
  final CivilDate today;
  final PastPaymentsMode mode;

  /// "Already collected" (opening-total mode); null while empty.
  final Money? openingTotal;
  final PaymentMode openingMode;

  /// Itemised rows, in the order they were added (row errors use this
  /// index: `pastPayments.i`).
  final List<PastPaymentInput> rows;
  final String? previousRef;
  final int cachedNextLoanNo;

  CivilDate get disbursedOn => terms.disbursedOn;

  /// The base schedule, or null while the terms are invalid.
  late final List<PlannedInstallment>? schedule = terms.schedule;

  /// The opening total spread over the installments due before today, or
  /// empty while the terms are invalid.
  late final List<PastPaymentInput> spread = () {
    final s = schedule;
    final total = openingTotal;
    if (s == null || total == null) return const <PastPaymentInput>[];
    return spreadOpeningTotal(
      schedule: s,
      total: total,
      mode: openingMode,
      disbursedOn: disbursedOn,
      today: today,
    );
  }();

  /// What the save sends: the spread in opening-total mode, the itemised
  /// rows otherwise. Never both.
  List<PastPaymentInput> get pastPayments =>
      mode == PastPaymentsMode.openingTotal ? spread : rows;

  /// Σ of [pastPayments].
  Money get collected => pastPaymentsTotal(pastPayments);

  /// Σ of the itemised rows (the running total).
  Money get itemisedTotal => pastPaymentsTotal(rows);

  late final List<ValidationError> errors = validateOnboarding(
    termErrors: terms.errors,
    sanctioned: terms.sanctioned ?? Money.zero,
    disbursedOn: disbursedOn,
    firstDueDate: terms.firstDueDate,
    today: today,
    payments: pastPayments,
    previousRef: previousRef,
  );

  /// First error message for [field], if any.
  String? errorFor(String field) {
    for (final e in errors) {
      if (e.field == field) return e.message;
    }
    return null;
  }

  /// The error of itemised row [index] (itemised mode only).
  String? rowError(int index) => mode == PastPaymentsMode.itemised
      ? errorFor(LedgerFields.pastPayment(index))
      : null;

  /// Installments the opening total covers (before the advance row).
  int get spreadInstallments =>
      // The spread is one payment per covered row, plus one trailing
      // advance payment exactly when the total exceeds those dues.
      spread.length - (spreadAdvance.isPositive ? 1 : 0);

  /// The part of the opening total beyond every installment due before
  /// today (₹0 when it covers less).
  Money get spreadAdvance {
    final s = schedule;
    final total = openingTotal;
    if (s == null || total == null || !total.isPositive) return Money.zero;
    final due = Money.sum(<Money>[
      for (final r in s)
        if (r.dueDate.isBefore(today)) r.amount,
    ]);
    return total > due ? total - due : Money.zero;
  }

  /// Whether an installment falls due today (it stays open for collection).
  bool get hasRowDueToday =>
      schedule?.any((PlannedInstallment r) => r.dueDate == today) ?? false;

  /// The opening-total helper line, e.g. "Spread across 7 installments due
  /// before today · ₹5,000 advance".
  String? get spreadHelper {
    final s = schedule;
    final total = openingTotal;
    if (s == null || total == null || !total.isPositive) return null;
    final n = spreadInstallments;
    final advance = spreadAdvance;
    final base = n == 0
        ? 'No installment is due before today. It is dated on the '
              'disbursement date'
        : 'Spread across $n ${n == 1 ? 'installment' : 'installments'} '
              'due before today';
    final adv = advance.isPositive ? ' · ${formatInr(advance)} advance' : '';
    final open = hasRowDueToday ? ". Today's installment stays open" : '';
    return '$base$adv$open.';
  }

  /// The plan the save would write (placeholder ids), or null while any
  /// field is invalid.
  late final OnboardingPlan? plan = () {
    if (errors.isNotEmpty) return null;
    return planOnboarding(
      terms: _DraftTerms(this),
      pastPayments: pastPayments,
      today: today,
      previousRef: previousRef,
      contractId: 'preview',
      borrowerId: 'preview',
      borrowerName: '',
      borrowerPhoneE164: '',
      now: DateTime.utc(today.year, today.month, today.day),
      uuid: _PreviewUuid(),
    );
  }();

  /// The "As of today" projection of [plan] (what the contract detail will
  /// show after saving), or null while any field is invalid.
  late final ContractProjection? preview = () {
    final p = plan;
    if (p == null) return null;
    return projectContract(
      contract: p.contract,
      installments: p.installments,
      transactions: p.transactions,
      today: today,
    );
  }();
}

/// [OnboardingDraft]'s terms as the repository's [LoanTermsInput].
final class _DraftTerms implements LoanTermsInput {
  _DraftTerms(this._d);

  final OnboardingDraft _d;

  ContractDraft get _t => _d.terms;

  @override
  Money get sanctioned => _t.sanctioned ?? Money.zero;
  @override
  UpfrontMode get upfrontMode => _t.upfrontMode;
  @override
  int get upfrontInput => _t.upfrontInput ?? 0;
  @override
  Money get installmentAmount => _t.installmentAmount ?? Money.zero;
  @override
  Frequency get frequency => _t.frequency;
  @override
  int? get preferredWeekday => _t.weekday;
  @override
  int? get preferredMonthDay => _t.monthDay;
  @override
  CivilDate get firstDueDate => _t.firstDueDate;
  @override
  CivilDate get disbursedOn => _t.disbursedOn;
  @override
  int get cachedNextLoanNo => _d.cachedNextLoanNo;
  @override
  LedgerActor get actor =>
      const LedgerActor(uid: 'preview', name: '', deviceId: '');
  @override
  String? get guarantor => null;
  @override
  String? get notes => null;
  @override
  String? get purpose => null;
}

/// Cheap, deterministic ids for the in-memory preview plan (never
/// written).
final class _PreviewUuid extends Uuid {
  _PreviewUuid();

  int _n = 0;

  @override
  // The deprecated `options` parameter is part of the overridden signature.
  // ignore: deprecated_member_use
  String v4({Map<String, dynamic>? options, V4Options? config}) =>
      'preview-${_n++}';
}
