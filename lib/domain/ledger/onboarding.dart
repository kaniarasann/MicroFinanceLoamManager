import '../../core/money/inr_format.dart';
import '../../core/money/money.dart';
import '../../core/time/civil_date.dart';
import '../models/enums.dart';
import 'schedule_generator.dart';
import 'validators.dart';

/// Onboarding an existing, in-progress loan (Section 2, "Addendum
/// 2026-11-24"): date windows, validation, the opening-total spread and
/// "Fill from schedule". Pure Dart; the write path lives in the contracts
/// data layer.

/// How far back "Disbursed on" may go (about 3 years).
const int maxOnboardBackdateDays = 1096;

/// "First collection date" is at most this many days after disbursement.
const int maxFirstDueAfterDisbursalDays = 366;

/// Most past payments one onboarding may write (keeps it to ≤ 4 batches).
const int maxPastPayments = 1100;

/// Longest previous (paper / old-system) loan reference.
const int maxPreviousRefLength = 40;

/// `note` of the payments an opening total is spread into.
const String openingBalanceNote = 'Opening balance';

/// One past payment to write at onboarding: an itemised row, or one row of
/// an opening-total spread ([openingBalance] true).
final class PastPaymentInput {
  const PastPaymentInput({
    required this.paidOn,
    required this.amount,
    required this.mode,
    this.reference,
    this.openingBalance = false,
  });

  final CivilDate paidOn;
  final Money amount;

  /// Required; `null` only while a row is being edited, and then it fails
  /// [validateOnboarding]. An onboarding payment without a mode would be
  /// miscounted as a waiver once reversed.
  final PaymentMode? mode;
  final String? reference;
  final bool openingBalance;

  PastPaymentInput copyWith({
    CivilDate? paidOn,
    Money? amount,
    PaymentMode? mode,
    String? reference,
  }) => PastPaymentInput(
    paidOn: paidOn ?? this.paidOn,
    amount: amount ?? this.amount,
    mode: mode ?? this.mode,
    reference: reference ?? this.reference,
    openingBalance: openingBalance,
  );

  @override
  bool operator ==(Object other) =>
      other is PastPaymentInput &&
      other.paidOn == paidOn &&
      other.amount == amount &&
      other.mode == mode &&
      other.reference == reference &&
      other.openingBalance == openingBalance;

  @override
  int get hashCode =>
      Object.hash(paidOn, amount, mode, reference, openingBalance);

  @override
  String toString() =>
      'PastPaymentInput($paidOn, ${amount.paise}, ${mode?.name}'
      '${openingBalance ? ', opening' : ''})';
}

/// Earliest "Disbursed on" allowed when onboarding on [today].
CivilDate earliestOnboardDisbursal(CivilDate today) =>
    today.addDays(-maxOnboardBackdateDays);

/// Latest "First collection date" for a loan disbursed on [disbursedOn].
CivilDate latestOnboardFirstDue(CivilDate disbursedOn) =>
    disbursedOn.addDays(maxFirstDueAfterDisbursalDays);

/// Σ of the payment amounts.
Money pastPaymentsTotal(Iterable<PastPaymentInput> payments) =>
    Money.sum(payments.map((PastPaymentInput p) => p.amount));

/// Validates an onboarding on top of the new-loan [termErrors] (from
/// `validateCommandTerms`). Returns every failure; empty = valid.
///
/// - `disbursedOn` in [today − [maxOnboardBackdateDays], today];
/// - `firstDueDate` in [disbursedOn, disbursedOn + 366];
/// - at most [maxPastPayments] payments, each > ₹0, with a mode and
///   `paidOn` in [disbursedOn, today] (one error per row, field
///   `LedgerFields.pastPayment(i)`);
/// - Σ payments < sanctioned. Σ == sanctioned is "already fully repaid".
///   The total errors are on `openingTotal` when every payment comes from
///   an opening-total spread, else on `pastPayments`;
/// - `previousRef` at most [maxPreviousRefLength] characters.
List<ValidationError> validateOnboarding({
  required List<ValidationError> termErrors,
  required Money sanctioned,
  required CivilDate disbursedOn,
  required CivilDate firstDueDate,
  required CivilDate today,
  required List<PastPaymentInput> payments,
  String? previousRef,
}) {
  final errors = <ValidationError>[...termErrors];

  if (disbursedOn.isAfter(today)) {
    errors.add(
      const ValidationError(
        LedgerFields.disbursedOn,
        'Disbursed on cannot be in the future.',
      ),
    );
  } else if (disbursedOn.isBefore(earliestOnboardDisbursal(today))) {
    errors.add(
      const ValidationError(
        LedgerFields.disbursedOn,
        'Disbursed on can be at most 3 years ago.',
      ),
    );
  }

  final firstDueReported = termErrors.any(
    (ValidationError e) => e.field == LedgerFields.firstDueDate,
  );
  if (!firstDueReported) {
    if (firstDueDate.isBefore(disbursedOn)) {
      errors.add(
        const ValidationError(
          LedgerFields.firstDueDate,
          'First due date cannot be before the disbursement date.',
        ),
      );
    } else if (firstDueDate.isAfter(latestOnboardFirstDue(disbursedOn))) {
      errors.add(
        const ValidationError(
          LedgerFields.firstDueDate,
          'First collection date must be within 366 days of the '
          'disbursement date.',
        ),
      );
    }
  }

  if (payments.length > maxPastPayments) {
    errors.add(
      const ValidationError(
        LedgerFields.pastPayments,
        'At most 1,100 past payments can be entered.',
      ),
    );
  }
  for (var i = 0; i < payments.length; i++) {
    final message = _rowError(payments[i], disbursedOn, today);
    if (message != null) {
      errors.add(ValidationError(LedgerFields.pastPayment(i), message));
    }
  }

  if (sanctioned.isPositive) {
    final total = pastPaymentsTotal(payments);
    final totalField =
        payments.isNotEmpty &&
            payments.every((PastPaymentInput p) => p.openingBalance)
        ? LedgerFields.openingTotal
        : LedgerFields.pastPayments;
    if (total == sanctioned) {
      errors.add(
        ValidationError(
          totalField,
          'This loan is already fully repaid. Only loans with a balance '
          'can be onboarded.',
        ),
      );
    } else if (total > sanctioned) {
      errors.add(
        ValidationError(
          totalField,
          'Collected so far cannot be more than the sanctioned '
          '${formatInr(sanctioned)}.',
        ),
      );
    }
  }

  final ref = previousRef?.trim();
  if (ref != null && ref.length > maxPreviousRefLength) {
    errors.add(
      const ValidationError(
        LedgerFields.previousRef,
        'Previous reference can be at most 40 characters.',
      ),
    );
  }
  return errors;
}

String? _rowError(PastPaymentInput p, CivilDate disbursedOn, CivilDate today) {
  if (!p.amount.isPositive) return 'Each payment must be more than ₹0.';
  if (p.mode == null) return 'Choose a payment mode.';
  if (p.paidOn.isBefore(disbursedOn)) {
    return 'A payment cannot be dated before the disbursement date.';
  }
  if (p.paidOn.isAfter(today)) return 'A payment cannot be in the future.';
  return null;
}

/// Base rows due on or before [upTo], oldest first (by due date, then seq).
List<PlannedInstallment> _dueUpTo(
  List<PlannedInstallment> schedule,
  CivilDate upTo,
) =>
    schedule.where((PlannedInstallment r) => !r.dueDate.isAfter(upTo)).toList()
      ..sort((PlannedInstallment a, PlannedInstallment b) {
        final byDate = a.dueDate.compareTo(b.dueDate);
        return byDate != 0 ? byDate : a.seq.compareTo(b.seq);
      });

/// Spreads an opening total over the base [schedule] rows due on or before
/// [today], oldest first: each covered row gets one payment of
/// `min(left, row amount)` dated on its due date, until [total] is used.
/// Anything left after the last row due by today (an advance) is one more
/// payment dated on `max(disbursedOn, that row's due date)`, or on
/// [disbursedOn] when no row is due yet, so it never lands on today unless
/// a row is due today. Every payment has [mode] and `openingBalance`.
/// A [total] ≤ ₹0 gives no payments.
///
/// FIFO allocation ignores dates, so the projection over these payments
/// equals the projection over one payment of [total].
List<PastPaymentInput> spreadOpeningTotal({
  required List<PlannedInstallment> schedule,
  required Money total,
  required PaymentMode mode,
  required CivilDate disbursedOn,
  required CivilDate today,
}) {
  if (!total.isPositive) return const <PastPaymentInput>[];
  final out = <PastPaymentInput>[];
  var left = total;
  CivilDate? lastDue;
  for (final row in _dueUpTo(schedule, today)) {
    if (!left.isPositive) break;
    final amount = Money.min(left, row.amount);
    out.add(
      PastPaymentInput(
        paidOn: row.dueDate,
        amount: amount,
        mode: mode,
        openingBalance: true,
      ),
    );
    left -= amount;
    lastDue = row.dueDate;
  }
  if (left.isPositive) {
    final due = lastDue;
    out.add(
      PastPaymentInput(
        paidOn: due != null && due.isAfter(disbursedOn) ? due : disbursedOn,
        amount: left,
        mode: mode,
        openingBalance: true,
      ),
    );
  }
  return out;
}

/// "Fill from schedule": one itemised payment per base row due on or
/// before [upTo], at its due date and full amount, oldest first.
List<PastPaymentInput> fillFromSchedule({
  required List<PlannedInstallment> schedule,
  required CivilDate upTo,
  required PaymentMode mode,
}) => <PastPaymentInput>[
  for (final row in _dueUpTo(schedule, upTo))
    PastPaymentInput(paidOn: row.dueDate, amount: row.amount, mode: mode),
];

/// How many balanced items (payments or reversals) go into each batch of
/// a chunked ledger write: the first batch has room for [firstRoom] items
/// next to its fixed docs, every later batch for [laterRoom]. Always at
/// least one batch (the first may hold 0 items).
///
/// Onboarding: `firstRoom = 450 − (contract + N installments +
/// disbursement + company)`, `laterRoom = 449` (+ 1 contract increment).
List<int> balancedChunkSizes({
  required int items,
  required int firstRoom,
  required int laterRoom,
}) {
  if (items < 0) throw ArgumentError.value(items, 'items', 'is negative');
  if (firstRoom < 0) {
    throw ArgumentError.value(firstRoom, 'firstRoom', 'is negative');
  }
  if (laterRoom < 1) {
    throw ArgumentError.value(laterRoom, 'laterRoom', 'must be ≥ 1');
  }
  final first = items < firstRoom ? items : firstRoom;
  final sizes = <int>[first];
  var left = items - first;
  while (left > 0) {
    final n = left < laterRoom ? left : laterRoom;
    sizes.add(n);
    left -= n;
  }
  return sizes;
}
