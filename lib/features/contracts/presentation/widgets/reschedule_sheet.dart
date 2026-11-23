import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/money/inr_format.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/time/today_provider.dart';
import '../../../../core/widgets/adaptive_sheet.dart';
import '../../../../core/widgets/currency_field.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../application/contract_providers.dart';
import '../../data/contract_repository.dart';
import 'date_field.dart';

/// Opens the manual reschedule form for one overdue row (bottom sheet on
/// phones, dialog on wider windows). Owners and collectors. Resolves to
/// true when saved.
Future<bool?> showRescheduleSheet(
  BuildContext context, {
  required ContractView view,
  required ProjectedRow row,
}) => showAdaptiveSheet<bool>(
  context,
  (BuildContext _) => RescheduleSheet(view: view, row: row),
);

/// Amount (default = the row's unpaid remainder, at most that), new due
/// date (today or later) and an optional note → one reschedule batch.
class RescheduleSheet extends ConsumerStatefulWidget {
  const RescheduleSheet({required this.view, required this.row, super.key});

  final ContractView view;
  final ProjectedRow row;

  @override
  ConsumerState<RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends ConsumerState<RescheduleSheet> {
  late Money? _amount = widget.row.remaining;
  CivilDate? _date;
  final TextEditingController _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  CivilDate _defaultDate(CivilDate today) {
    final c = widget.view.contract;
    return nextDueDate(
      today,
      c.frequency,
      SchedulePrefs(weekday: c.preferredWeekday, monthDay: c.preferredMonthDay),
    );
  }

  List<ValidationError> _errors(CivilDate today) => validateReschedule(
    amount: _amount ?? Money.zero,
    remaining: widget.row.remaining,
    newDueDate: _date ?? _defaultDate(today),
    today: today,
  );

  Future<void> _save(CivilDate today) async {
    if (_errors(today).isNotEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final r = await ref
          .read(contractActionsProvider)
          .reschedule(
            view: widget.view,
            row: widget.row,
            amount: _amount!,
            newDueDate: _date ?? _defaultDate(today),
            note: _note.text,
          );
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            r.outcome == WriteOutcome.queued
                ? 'Saved · will sync'
                : 'Installment rescheduled',
          ),
        ),
      );
      if (mounted) navigator.pop(true);
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.userMessage);
    } on Object {
      if (mounted) {
        setState(() => _error = const UnknownFailure(null).userMessage);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final errors = _errors(today);
    String? errorFor(String f) =>
        errors.where((ValidationError e) => e.field == f).firstOrNull?.message;
    final row = widget.row;
    return Column(
      key: const ValueKey<String>('reschedule_sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Reschedule installment ${row.seq}',
          style: AppTextStyles.headlineSm,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Unpaid ${formatInr(row.remaining)} · due '
          '${formatCivilDate(row.dueDate)}. The moved amount is left out of '
          'the automatic extension.',
          style: AppTextStyles.bodyMdTabular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        CurrencyField(
          key: const ValueKey<String>('reschedule_amount'),
          label: 'Amount to move',
          initialValue: row.remaining,
          errorText: errorFor(LedgerFields.amount),
          onChanged: (Money? m) => setState(() => _amount = m),
        ),
        const SizedBox(height: AppSpacing.md),
        DateField(
          fieldKey: const ValueKey<String>('reschedule_date'),
          label: 'New due date',
          value: _date ?? _defaultDate(today),
          first: today,
          last: today.addDays(366),
          errorText: errorFor(LedgerFields.newDueDate),
          onChanged: (CivilDate d) => setState(() => _date = d),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey<String>('reschedule_note'),
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            counterText: '',
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            _error!,
            key: const ValueKey<String>('reschedule_error'),
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.overdue),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const ValueKey<String>('reschedule_save'),
          onPressed: _busy || errors.isNotEmpty
              ? null
              : () => unawaited(_save(today)),
          child: _busy
              ? const SizedBox.square(
                  dimension: AppSizes.iconSm,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : const Text('Move installment'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
