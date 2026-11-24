import 'package:flutter/material.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/share_bar.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../application/dashboard_filters.dart';

/// "Today's due": Σ due today, how many borrowers, and received today
/// against it with a sage progress bar.
class TodayDueCard extends StatelessWidget {
  const TodayDueCard({required this.todayDue, super.key});

  final TodayDue todayDue;

  @override
  Widget build(BuildContext context) {
    final t = todayDue;
    final borrowers = t.items.map((TodayDueItem i) => i.contractId).toSet();
    final n = borrowers.length;
    final received =
        '${formatInr(t.received)} / ${formatInr(t.amountDue)}'
        '${t.amountDue.isPositive ? ' (${wholePercent(t.progressBps)})' : ''}';
    return AppCard(
      key: const ValueKey<String>('today_due_card'),
      padding: AppCardPadding.spacious,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            "Today's due collections",
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: MoneyText(t.amountDue, style: AppTextStyles.currencyDisplay),
          ),
          Text(
            n == 0
                ? 'Nothing due today'
                : (n == 1 ? '1 loan due' : '$n loans due'),
            style: AppTextStyles.bodySmTabular,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpacing.sm,
            children: <Widget>[
              const Text('Received today', style: AppTextStyles.bodyMd),
              Text(
                received,
                key: const ValueKey<String>('today_received'),
                style: AppTextStyles.labelLgTabular.copyWith(
                  color: AppColors.collected,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: 'Received today $received',
            child: ExcludeSemantics(
              child: ShareBar(
                bps: t.progressBps,
                color: AppColors.collected,
                height: AppSizes.clearedBarHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
