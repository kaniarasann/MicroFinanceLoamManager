import 'package:flutter/material.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/share_bar.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../application/dashboard_filters.dart';

/// "Receivable breakdown": the sanctioned receivable and three separate,
/// labelled rows (never a stacked bar, because amber and terracotta are
/// too close to sit side by side unlabelled): Collected this month,
/// Upcoming next 30 days and Overdue (with a warning icon).
class ReceivableBreakdownCard extends StatelessWidget {
  const ReceivableBreakdownCard({
    required this.receivable,
    required this.breakdown,
    required this.onViewOverdue,
    super.key,
  });

  final Money receivable;
  final ReceivableBreakdown breakdown;
  final VoidCallback onViewOverdue;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const ValueKey<String>('receivable_breakdown'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: const Text(
              'Receivable breakdown',
              style: AppTextStyles.headlineSm,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          MoneyText(receivable, style: AppTextStyles.headlineLgTabular),
          const Text('Sanctioned receivable', style: AppTextStyles.bodySm),
          const SizedBox(height: AppSpacing.md),
          _ShareRow(
            key: const ValueKey<String>('share_collected'),
            label: 'Collected this month',
            share: breakdown.collectedThisMonth,
            color: AppColors.collected,
          ),
          const SizedBox(height: AppSpacing.md),
          _ShareRow(
            key: const ValueKey<String>('share_upcoming'),
            label: 'Upcoming next 30 days',
            share: breakdown.upcoming30,
            color: AppColors.upcoming,
          ),
          const SizedBox(height: AppSpacing.md),
          _ShareRow(
            key: const ValueKey<String>('share_overdue'),
            label: 'Overdue',
            share: breakdown.overdue,
            color: AppColors.overdue,
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey<String>('breakdown_view_overdue'),
              onPressed: onViewOverdue,
              child: const Text('View overdue tracker →'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.label,
    required this.share,
    required this.color,
    this.icon,
    super.key,
  });

  final String label;
  final ReceivableShare share;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final pct = wholePercent(share.bps);
    return Semantics(
      label: '$label ${formatShare(share)}',
      container: true,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (icon != null)
                  Icon(icon, size: AppSizes.iconSm, color: color)
                else
                  Container(
                    width: AppSizes.statusDot,
                    height: AppSizes.statusDot,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyMd,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                MoneyText(share.amount),
                const SizedBox(width: AppSpacing.sm),
                Text(pct, style: AppTextStyles.bodySmTabular),
              ],
            ),
            const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
            ShareBar(bps: share.bps, color: color),
          ],
        ),
      ),
    );
  }
}

/// "₹12,000, 8% of receivable".
String formatShare(ReceivableShare s) =>
    '${formatInr(s.amount)}, ${wholePercent(s.bps)} of receivable';
