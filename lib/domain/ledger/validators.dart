import '../../core/money/inr_format.dart';
import '../../core/money/money.dart';
import '../../core/time/civil_date.dart';
import '../models/enums.dart';
import 'schedule_generator.dart';
import 'upfront.dart';

/// A field-level validation failure. [field] is the contract field name the
/// UI binds to (e.g. `sanctioned`, `upfrontInput`).
final class ValidationError {
  const ValidationError(this.field, this.message);

  final String field;
  final String message;

  @override
  bool operator ==(Object other) =>
      other is ValidationError &&
      other.field == field &&
      other.message == message;

  @override
  int get hashCode => Object.hash(field, message);

  @override
  String toString() => 'ValidationError($field: $message)';
}

/// Field names reported by the validators.
abstract final class LedgerFields {
  static const String sanctioned = 'sanctioned';
  static const String upfrontInput = 'upfrontInput';
  static const String installmentAmount = 'installmentAmount';
  static const String preferredWeekday = 'preferredWeekday';
  static const String preferredMonthDay = 'preferredMonthDay';
  static const String installmentCount = 'installmentCount';
  static const String firstDueDate = 'firstDueDate';
  static const String amount = 'amount';
}

/// Validates new-contract terms. Returns every failure (empty = valid).
List<ValidationError> validateContractTerms({
  required Money sanctioned,
  required UpfrontMode upfrontMode,
  required int upfrontInput,
  required Money installmentAmount,
  required Frequency frequency,
  int? preferredWeekday,
  int? preferredMonthDay,
  required CivilDate firstDueDate,
  required CivilDate disbursedOn,
}) {
  final errors = <ValidationError>[];
  final sanctionedOk = sanctioned.isPositive;
  if (!sanctionedOk) {
    errors.add(
      const ValidationError(
        LedgerFields.sanctioned,
        'Sanctioned amount must be more than ₹0.',
      ),
    );
  }

  switch (upfrontMode) {
    case UpfrontMode.flat:
      if (upfrontInput < 0) {
        errors.add(
          const ValidationError(
            LedgerFields.upfrontInput,
            'Upfront interest cannot be negative.',
          ),
        );
      } else if (sanctionedOk && upfrontInput >= sanctioned.paise) {
        errors.add(
          const ValidationError(
            LedgerFields.upfrontInput,
            'Upfront interest must be less than the sanctioned amount.',
          ),
        );
      }
    case UpfrontMode.percent:
      if (upfrontInput < 0 || upfrontInput > bpsScale) {
        errors.add(
          const ValidationError(
            LedgerFields.upfrontInput,
            'Upfront percentage must be between 0% and 100%.',
          ),
        );
      } else if (sanctionedOk &&
          computeUpfront(sanctioned, upfrontMode, upfrontInput) >= sanctioned) {
        errors.add(
          const ValidationError(
            LedgerFields.upfrontInput,
            'Upfront interest must be less than the sanctioned amount.',
          ),
        );
      }
  }

  final installmentOk = installmentAmount.isPositive;
  if (!installmentOk) {
    errors.add(
      const ValidationError(
        LedgerFields.installmentAmount,
        'Installment amount must be more than ₹0.',
      ),
    );
  } else if (sanctionedOk && installmentAmount > sanctioned) {
    errors.add(
      const ValidationError(
        LedgerFields.installmentAmount,
        'Installment amount cannot exceed the sanctioned amount.',
      ),
    );
  }

  switch (frequency) {
    case Frequency.daily:
      break;
    case Frequency.weekly:
      if (preferredWeekday == null ||
          preferredWeekday < 1 ||
          preferredWeekday > 7) {
        errors.add(
          const ValidationError(
            LedgerFields.preferredWeekday,
            'Choose a collection weekday.',
          ),
        );
      }
    case Frequency.monthly:
      if (preferredMonthDay == null ||
          preferredMonthDay < 1 ||
          preferredMonthDay > 31) {
        errors.add(
          const ValidationError(
            LedgerFields.preferredMonthDay,
            'Choose a collection day between 1 and 31.',
          ),
        );
      }
  }

  if (sanctionedOk && installmentOk) {
    final n = installmentCount(sanctioned, installmentAmount);
    if (n > maxInstallmentCount) {
      errors.add(
        ValidationError(
          LedgerFields.installmentCount,
          'This makes $n installments; the maximum is $maxInstallmentCount. '
          'Increase the installment amount.',
        ),
      );
    }
  }

  if (firstDueDate.isBefore(disbursedOn)) {
    errors.add(
      const ValidationError(
        LedgerFields.firstDueDate,
        'First due date cannot be before the disbursement date.',
      ),
    );
  }
  return errors;
}

/// A payment must be more than ₹0 and at most the [outstanding] balance.
List<ValidationError> validatePaymentAmount(Money amount, Money outstanding) {
  if (!amount.isPositive) {
    return const <ValidationError>[
      ValidationError(LedgerFields.amount, 'Amount must be more than ₹0.'),
    ];
  }
  if (amount > outstanding) {
    return <ValidationError>[
      ValidationError(
        LedgerFields.amount,
        'Amount cannot exceed the outstanding ${formatInr(outstanding)}.',
      ),
    ];
  }
  return const <ValidationError>[];
}
