import 'package:flutter/material.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/ledger/ledger.dart';
import '../due_row_status.dart';

/// Terracotta alert: "Missed / overdue payments", N loans · ₹X · highest
/// delay, with "View tracker". Shown only while something is overdue.
class OverdueAlertCard extends StatelessWidget {
  const OverdueAlertCard({
    required this.metrics,
    required this.onOpen,
    super.key,
  });

  final PortfolioMetrics metrics;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final loans = metrics.overdueLoanCount;
    final detail =
        '${loans == 1 ? '1 loan' : '$loans loans'} · '
        '${formatInr(metrics.totalOverdue)} overdue · '
        'highest ${daysLate(metrics.maxDaysOverdue)}';
    return Material(
      key: const ValueKey<String>('overdue_alert'),
      color: AppColors.overdueTint,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.overdueBorder),
        borderRadius: AppRadii.lgAll,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: AppInsets.cardCompact,
          child: Row(
            children: <Widget>[
              Container(
                width: AppSizes.alertBadge,
                height: AppSizes.alertBadge,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: AppColors.overdue,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Missed / overdue payments',
                      style: AppTextStyles.titleMd.copyWith(
                        color: AppColors.overdue,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(detail, style: AppTextStyles.bodyMdTabular),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'View tracker →',
                      style: AppTextStyles.labelLg.copyWith(
                        color: AppColors.overdue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
