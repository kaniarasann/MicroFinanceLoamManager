import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/currency_field.dart';
import '../../../../core/widgets/segmented_toggle.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../../domain/models/enums.dart';
import '../../application/contract_draft.dart';
import 'loan_terms_controller.dart';

/// Sanctioned quick-pick chips (rupees).
const List<(String, int)> _quickAmounts = <(String, int)>[
  ('₹25k', 25000),
  ('₹50k', 50000),
  ('₹1L', 100000),
  ('₹2L', 200000),
];

/// Sanctioned amount (+ quick chips), deduction method Flat ₹ / %,
/// upfront input and the "x% effective" line. Shared by create contract
/// and rollover.
class LoanAmountFields extends StatelessWidget {
  const LoanAmountFields({
    required this.terms,
    required this.draft,
    required this.showAllErrors,
    this.sanctionedLabel = 'Sanctioned amount',
    this.upfrontHelperText,
    super.key,
  });

  final LoanTermsController terms;
  final ContractDraft draft;

  /// After a submit attempt every error shows, touched or not.
  final bool showAllErrors;
  final String sanctionedLabel;

  /// Helper under the upfront input (onboarding: "Unknown? Enter ₹0").
  final String? upfrontHelperText;

  String? _show(String field, {required bool touched}) =>
      showAllErrors || touched ? draft.errorFor(field) : null;

  @override
  Widget build(BuildContext context) {
    final label = AppTextStyles.labelMd.copyWith(
      color: AppColors.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CurrencyField(
          key: const ValueKey<String>('sanctioned_field'),
          controller: terms.sanctioned,
          label: sanctionedLabel,
          errorText: _show(
            LedgerFields.sanctioned,
            touched: terms.sanctionedValue != null,
          ),
          onChanged: terms.sanctionedChanged,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final (text, rupees) in _quickAmounts)
              ActionChip(
                key: ValueKey<String>('quick_$rupees'),
                label: Text(text, style: AppTextStyles.labelMdTabular),
                onPressed: () => terms.setSanctioned(Money.fromRupees(rupees)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Deduction method', style: label),
        const SizedBox(height: AppSpacing.sm),
        SegmentedToggle<UpfrontMode>(
          key: const ValueKey<String>('upfront_mode'),
          expand: true,
          segments: const <ToggleSegment<UpfrontMode>>[
            ToggleSegment<UpfrontMode>(
              value: UpfrontMode.flat,
              label: 'Flat ₹',
            ),
            ToggleSegment<UpfrontMode>(
              value: UpfrontMode.percent,
              label: 'Percentage %',
            ),
          ],
          selected: terms.mode,
          onChanged: terms.modeChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        if (terms.mode == UpfrontMode.flat)
          CurrencyField(
            key: const ValueKey<String>('upfront_flat_field'),
            controller: terms.upfrontFlat,
            label: 'Upfront interest',
            helperText: upfrontHelperText,
            errorText: _show(
              LedgerFields.upfrontInput,
              touched: terms.flatValue != null,
            ),
            onChanged: terms.flatChanged,
          )
        else
          TextField(
            key: const ValueKey<String>('upfront_pct_field'),
            controller: terms.upfrontPct,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d{0,3}(\.\d{0,2})?'),
              ),
            ],
            style: AppTextStyles.titleMdTabular,
            onChanged: terms.pctChanged,
            decoration: InputDecoration(
              labelText: 'Upfront interest',
              hintText: '0',
              suffixText: '%',
              helperText: upfrontHelperText,
              errorText: _show(
                LedgerFields.upfrontInput,
                touched: terms.pctBps != null,
              ),
              constraints: const BoxConstraints(
                minHeight: AppSizes.inputHeight,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${formatBpsPercent(draft.effectiveBps)} effective',
          key: const ValueKey<String>('effective_pct'),
          style: AppTextStyles.labelLgTabular.copyWith(
            color: AppColors.collected,
          ),
        ),
      ],
    );
  }
}
