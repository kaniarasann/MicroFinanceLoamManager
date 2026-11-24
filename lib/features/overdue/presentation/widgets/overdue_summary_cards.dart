import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../contracts/application/contract_draft.dart'
    show formatBpsPercent;
import '../../../dashboard/presentation/due_row_status.dart';

/// "Total overdue" (₹, N loans, highest delay) and "Collection risk"
/// (overdue as % of the active book), side by side.
class OverdueSummaryCards extends StatelessWidget {
  const OverdueSummaryCards({
    required this.summary,
    required this.riskBps,
    super.key,
  });

  final OverdueSummary summary;
  final int riskBps;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final n = s.loans.length;
    final total = AppCard(
      key: const ValueKey<String>('overdue_total_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                'Total overdue',
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              StatusPill(
                label: n == 1 ? '1 loan' : '$n loans',
                kind: n == 0 ? StatusKind.neutral : StatusKind.overdue,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: MoneyText(
              s.total,
              style: AppTextStyles.headlineXlTabular,
              color: s.total.isPositive
                  ? AppColors.overdue
                  : AppColors.textPrimary,
            ),
          ),
          Text(
            n == 0
                ? 'Nothing overdue'
                : 'Highest delay: ${daysLate(s.maxDaysOverdue)}',
            style: AppTextStyles.bodySmTabular,
          ),
        ],
      ),
    );
    final risk = AppCard(
      key: const ValueKey<String>('overdue_risk_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Collection risk',
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              formatBpsPercent(riskBps),
              style: AppTextStyles.headlineXlTabular,
            ),
          ),
          const Text(
            'of the active book is overdue',
            style: AppTextStyles.bodySm,
          ),
        ],
      ),
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: total),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: risk),
        ],
      ),
    );
  }
}
