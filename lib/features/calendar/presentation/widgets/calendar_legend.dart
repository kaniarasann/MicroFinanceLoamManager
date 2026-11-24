import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../domain/ledger/ledger.dart';

/// Month legend: Collected / Pending / Overdue, each a labelled tinted
/// chip with its dot colour and the month's total (full ₹ form).
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({required this.totals, super.key});

  final CalendarTotals totals;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const ValueKey<String>('calendar_legend'),
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        _Chip(
          key: const ValueKey<String>('legend_collected'),
          label: 'Collected',
          amount: totals.settled,
          color: AppColors.collected,
          tint: AppColors.collectedTint,
        ),
        _Chip(
          key: const ValueKey<String>('legend_pending'),
          label: 'Pending',
          amount: totals.pending,
          color: AppColors.upcoming,
          tint: AppColors.upcomingTint,
        ),
        _Chip(
          key: const ValueKey<String>('legend_overdue'),
          label: 'Overdue',
          amount: totals.overdue,
          color: AppColors.overdue,
          tint: AppColors.overdueTint,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.amount,
    required this.color,
    required this.tint,
    super.key,
  });

  final String label;
  final Money amount;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.pillHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(color: tint, borderRadius: AppRadii.fullAll),
        child: Padding(
          padding: AppInsets.pill,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: AppSizes.statusDot,
                height: AppSizes.statusDot,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
              Text(
                '$label ',
                style: AppTextStyles.labelMdStrong.copyWith(color: color),
              ),
              Flexible(
                child: MoneyText(
                  amount,
                  style: AppTextStyles.labelMdStrong,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
