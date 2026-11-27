import 'package:flutter/material.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/currency_field.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/segmented_toggle.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../../domain/models/enums.dart';
import '../../../payments/presentation/widgets/payment_mode_selector.dart';
import '../../application/onboarding_draft.dart';
import 'past_payment_sheet.dart';

/// Step 3 "Collected so far": the Opening total / Itemised payments
/// toggle; the opening-total amount, mode and spread helper; or the
/// itemised rows (newest first, running total, add / edit / delete,
/// "Fill from schedule"), each with its inline error. Switching modes
/// keeps both inputs; only the selected one is saved.
class PastPaymentsSection extends StatelessWidget {
  const PastPaymentsSection({
    required this.draft,
    required this.openingController,
    required this.showAllErrors,
    required this.onModeChanged,
    required this.onOpeningChanged,
    required this.onOpeningModeChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onFill,
    super.key,
  });

  final OnboardingDraft draft;
  final TextEditingController openingController;
  final bool showAllErrors;
  final ValueChanged<PastPaymentsMode> onModeChanged;
  final ValueChanged<Money?> onOpeningChanged;
  final ValueChanged<PaymentMode> onOpeningModeChanged;
  final VoidCallback onAdd;

  /// Index into [OnboardingDraft.rows].
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final VoidCallback onFill;

  static final TextStyle _label = AppTextStyles.labelMd.copyWith(
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final opening = draft.mode == PastPaymentsMode.openingTotal;
    return Column(
      key: const ValueKey<String>('past_payments_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SegmentedToggle<PastPaymentsMode>(
          key: const ValueKey<String>('past_payments_mode'),
          expand: true,
          segments: const <ToggleSegment<PastPaymentsMode>>[
            ToggleSegment<PastPaymentsMode>(
              value: PastPaymentsMode.openingTotal,
              label: 'Opening total',
            ),
            ToggleSegment<PastPaymentsMode>(
              value: PastPaymentsMode.itemised,
              label: 'Itemised payments',
            ),
          ],
          selected: draft.mode,
          onChanged: onModeChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        if (opening) ..._opening() else ..._itemised(),
      ],
    );
  }

  List<Widget> _opening() {
    final touched = showAllErrors || draft.openingTotal != null;
    return <Widget>[
      CurrencyField(
        key: const ValueKey<String>('opening_total_field'),
        controller: openingController,
        label: 'Already collected',
        helperText:
            draft.spreadHelper ??
            'Unknown? Enter ₹0 to start with nothing paid.',
        errorText: touched ? draft.errorFor(LedgerFields.openingTotal) : null,
        onChanged: onOpeningChanged,
      ),
      const SizedBox(height: AppSpacing.md),
      Text('Mode', style: _label),
      const SizedBox(height: AppSpacing.sm),
      PaymentModeSelector(
        selected: draft.openingMode,
        onChanged: onOpeningModeChanged,
      ),
    ];
  }

  List<Widget> _itemised() {
    final rows = draft.rows;
    final sanctioned = draft.terms.sanctioned ?? Money.zero;
    final totalError = draft.errorFor(LedgerFields.pastPayments);
    // Newest first; each entry keeps its index into draft.rows.
    final order = <int>[for (var i = 0; i < rows.length; i++) i]
      ..sort((int a, int b) {
        final byDate = rows[b].paidOn.compareTo(rows[a].paidOn);
        return byDate != 0 ? byDate : b.compareTo(a);
      });
    return <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${rows.length} ${rows.length == 1 ? 'payment' : 'payments'}',
              style: AppTextStyles.labelLgTabular,
            ),
          ),
          MoneyText(
            draft.itemisedTotal,
            key: const ValueKey<String>('itemised_total'),
            color: AppColors.collected,
          ),
        ],
      ),
      Text(
        'of ${formatInr(sanctioned)} sanctioned',
        style: AppTextStyles.bodySmTabular,
        textAlign: TextAlign.end,
      ),
      if (totalError != null && (showAllErrors || rows.isNotEmpty))
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            totalError,
            key: const ValueKey<String>('past_payments_error'),
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.overdue),
          ),
        ),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          OutlinedButton.icon(
            key: const ValueKey<String>('add_past_payment'),
            onPressed: rows.length >= maxPastPayments ? null : onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add payment'),
          ),
          OutlinedButton.icon(
            key: const ValueKey<String>('fill_from_schedule'),
            onPressed: draft.schedule == null ? null : onFill,
            icon: const Icon(Icons.playlist_add_check),
            label: const Text('Fill from schedule'),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      if (rows.isEmpty)
        Text(
          'No past payments yet. Add them one by one, or fill them from the '
          'schedule and edit.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
        )
      else
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.mdAll,
            border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: AppSizes.boundedListMaxHeight,
            ),
            child: ListView.separated(
              key: const ValueKey<String>('past_payments_list'),
              shrinkWrap: true,
              itemCount: order.length,
              separatorBuilder: (BuildContext _, int _) =>
                  const Divider(height: AppSizes.borderWidth),
              itemBuilder: (BuildContext _, int i) {
                final index = order[i];
                return _PaymentRow(
                  index: index,
                  payment: rows[index],
                  error: draft.rowError(index),
                  onEdit: () => onEdit(index),
                  onDelete: () => onDelete(index),
                );
              },
            ),
          ),
        ),
    ];
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.index,
    required this.payment,
    required this.error,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final PastPaymentInput payment;
  final String? error;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final e = error;
    return Material(
      key: ValueKey<String>('past_payment_$index'),
      color: e == null ? AppColors.transparent : AppColors.overdueTint,
      child: InkWell(
        onTap: onEdit,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: AppInsets.listRow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          pastPaymentMeta(payment),
                          style: AppTextStyles.bodyMdTabular,
                        ),
                        if (e != null)
                          Text(
                            e,
                            key: ValueKey<String>('past_payment_error_$index'),
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.overdue,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                MoneyText(payment.amount),
                IconButton(
                  key: ValueKey<String>('delete_past_payment_$index'),
                  tooltip: 'Remove payment',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
