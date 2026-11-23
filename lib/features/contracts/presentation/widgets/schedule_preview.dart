import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../domain/ledger/ledger.dart';

/// First [visible] rows of a planned schedule, then
/// "+N more · Maturity d MMM yyyy".
class SchedulePreview extends StatelessWidget {
  const SchedulePreview({required this.schedule, this.visible = 3, super.key});

  final List<PlannedInstallment> schedule;
  final int visible;

  @override
  Widget build(BuildContext context) {
    final shown = schedule.take(visible).toList();
    final more = schedule.length - shown.length;
    return DecoratedBox(
      key: const ValueKey<String>('schedule_preview'),
      decoration: const BoxDecoration(
        color: AppColors.pressed,
        borderRadius: AppRadii.mdAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: AppInsets.cardCompact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Schedule preview',
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            for (final row in shown)
              Padding(
                key: ValueKey<String>('preview_row_${row.seq}'),
                padding: AppInsets.listRow,
                child: Row(
                  children: <Widget>[
                    Text('${row.seq}', style: AppTextStyles.labelLgTabular),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        '${formatCivilDateWithWeekday(row.dueDate)} '
                        '${row.dueDate.year}',
                        style: AppTextStyles.bodyMdTabular,
                      ),
                    ),
                    MoneyText(row.amount),
                  ],
                ),
              ),
            if (more > 0)
              Text(
                '+$more more · Maturity '
                '${formatCivilDate(schedule.last.dueDate)}',
                key: const ValueKey<String>('preview_more'),
                style: AppTextStyles.bodySmTabular,
              )
            else if (schedule.isNotEmpty)
              Text(
                'Maturity ${formatCivilDate(schedule.last.dueDate)}',
                key: const ValueKey<String>('preview_more'),
                style: AppTextStyles.bodySmTabular,
              ),
          ],
        ),
      ),
    );
  }
}
