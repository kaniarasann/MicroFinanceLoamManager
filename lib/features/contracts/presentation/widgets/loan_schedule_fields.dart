import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/widgets/currency_field.dart';
import '../../../../core/widgets/segmented_toggle.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../../domain/models/enums.dart';
import '../../application/contract_draft.dart';
import 'collection_day_picker.dart';
import 'date_field.dart';
import 'loan_terms_controller.dart';
import 'schedule_preview.dart';

/// Frequency, installment (→ cycles), collection weekday / month day,
/// first collection date, the maturity line and the schedule preview.
/// Shared by create contract and rollover.
class LoanScheduleFields extends StatelessWidget {
  const LoanScheduleFields({
    required this.terms,
    required this.draft,
    required this.today,
    required this.showAllErrors,
    this.firstDueMin,
    this.firstDueMax,
    this.showSchedulePreview = true,
    this.firstDueErrorText,
    super.key,
  });

  final LoanTermsController terms;
  final ContractDraft draft;
  final CivilDate today;
  final bool showAllErrors;

  /// Limits of the "First collection date" picker; default today …
  /// today + 366 (new loan, rollover). Onboarding passes disbursedOn …
  /// disbursedOn + 366.
  final CivilDate? firstDueMin;
  final CivilDate? firstDueMax;

  /// The planned-schedule preview card (onboarding shows its own "As of
  /// today" preview instead).
  final bool showSchedulePreview;

  /// Overrides the first-date error (onboarding validates more windows).
  final String? firstDueErrorText;

  String? _show(String field, {required bool touched}) =>
      showAllErrors || touched ? draft.errorFor(field) : null;

  @override
  Widget build(BuildContext context) {
    final schedule = draft.schedule;
    final frequency = terms.frequency;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Frequency',
          style: AppTextStyles.labelMd.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedToggle<Frequency>(
          key: const ValueKey<String>('frequency_toggle'),
          expand: true,
          segments: const <ToggleSegment<Frequency>>[
            ToggleSegment<Frequency>(value: Frequency.daily, label: 'Daily'),
            ToggleSegment<Frequency>(value: Frequency.weekly, label: 'Weekly'),
            ToggleSegment<Frequency>(
              value: Frequency.monthly,
              label: 'Monthly',
            ),
          ],
          selected: frequency,
          onChanged: terms.frequencyChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        CurrencyField(
          key: const ValueKey<String>('installment_field'),
          controller: terms.installment,
          label: 'Installment amount',
          helperText: draft.cycles == null ? null : '${draft.cycles} cycles',
          errorText:
              _show(
                LedgerFields.installmentAmount,
                touched: terms.installmentValue != null,
              ) ??
              _show(
                LedgerFields.installmentCount,
                touched: terms.installmentValue != null,
              ),
          onChanged: terms.installmentChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        CollectionDayPicker(
          frequency: frequency,
          weekday: draft.weekday,
          monthDay: draft.monthDay,
          errorText: frequency == Frequency.weekly
              ? _show(LedgerFields.preferredWeekday, touched: true)
              : _show(LedgerFields.preferredMonthDay, touched: true),
          onWeekday: terms.weekdayChanged,
          onMonthDay: terms.monthDayChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        DateField(
          fieldKey: const ValueKey<String>('first_due_field'),
          label: 'First collection date',
          value: schedule?.first.dueDate ?? draft.firstDueDate,
          first: firstDueMin ?? today,
          last: firstDueMax ?? today.addDays(366),
          errorText:
              firstDueErrorText ??
              _show(LedgerFields.firstDueDate, touched: true),
          onChanged: terms.firstDuePicked,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          schedule == null
              ? 'Maturity date appears once the amounts are valid.'
              : 'Maturity ${formatCivilDate(schedule.last.dueDate)}',
          key: const ValueKey<String>('maturity_line'),
          style: AppTextStyles.bodyMdTabular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (schedule != null && showSchedulePreview) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          SchedulePreview(schedule: schedule),
        ],
      ],
    );
  }
}
