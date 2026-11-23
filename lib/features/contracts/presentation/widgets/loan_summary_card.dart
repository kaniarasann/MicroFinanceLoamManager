import 'package:flutter/material.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_text.dart';

/// Sanctioned − Less upfront (terracotta) = Net cash handover, with the
/// "repays the full sanctioned" note.
class LoanSummaryCard extends StatelessWidget {
  const LoanSummaryCard({
    required this.sanctioned,
    required this.upfront,
    required this.net,
    super.key,
  });

  final Money sanctioned;
  final Money upfront;
  final Money net;

  @override
  Widget build(BuildContext context) {
    final label = AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary);
    return AppCard(
      key: const ValueKey<String>('loan_summary'),
      padding: AppCardPadding.spacious,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Sanctioned principal', style: label)),
              MoneyText(
                sanctioned,
                key: const ValueKey<String>('sum_sanctioned'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(child: Text('Less upfront interest', style: label)),
              Text(
                minusSign,
                style: AppTextStyles.currencyItem.copyWith(
                  color: AppColors.overdue,
                ),
              ),
              MoneyText(
                upfront,
                key: const ValueKey<String>('sum_upfront'),
                color: AppColors.overdue,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Net cash handover',
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: MoneyText(
              net,
              key: const ValueKey<String>('sum_net'),
              style: AppTextStyles.currencyDisplay,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.primarySubtle,
              borderRadius: AppRadii.baseAll,
            ),
            child: Padding(
              padding: AppInsets.banner,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.info_outline,
                    size: AppSizes.iconSm,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Borrower repays the full sanctioned '
                      '${formatInr(sanctioned)} across the scheduled cycles. '
                      'No further interest is added.',
                      style: AppTextStyles.bodySmTabular.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
