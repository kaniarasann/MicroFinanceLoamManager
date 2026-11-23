import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/enums.dart';

const List<String> _weekdays = <String>[
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
];

/// Preferred collection day: weekday chips (weekly), a day-of-month picker
/// 1–31 (monthly), or a note (daily).
class CollectionDayPicker extends StatelessWidget {
  const CollectionDayPicker({
    required this.frequency,
    required this.weekday,
    required this.monthDay,
    required this.onWeekday,
    required this.onMonthDay,
    this.errorText,
    super.key,
  });

  final Frequency frequency;
  final int? weekday;
  final int? monthDay;
  final ValueChanged<int> onWeekday;
  final ValueChanged<int> onMonthDay;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final label = AppTextStyles.labelMd.copyWith(
      color: AppColors.textSecondary,
    );
    final error = errorText;
    final errorLine = error == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              error,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.overdue),
            ),
          );
    switch (frequency) {
      case Frequency.daily:
        return Text(
          'Collected every day, Sundays included.',
          key: const ValueKey<String>('daily_note'),
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
        );
      case Frequency.weekly:
        return Column(
          key: const ValueKey<String>('weekday_picker'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Preferred weekday', style: label),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (var i = 1; i <= 7; i++)
                  ChoiceChip(
                    key: ValueKey<String>('weekday_$i'),
                    label: Text(_weekdays[i - 1]),
                    selected: weekday == i,
                    onSelected: (bool _) => onWeekday(i),
                  ),
              ],
            ),
            ?errorLine,
          ],
        );
      case Frequency.monthly:
        return DropdownButtonFormField<int>(
          key: const ValueKey<String>('month_day_picker'),
          initialValue: monthDay,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Collection day of month',
            helperText: 'Days 29–31 move to the last day of shorter months.',
            errorText: errorText,
          ),
          items: <DropdownMenuItem<int>>[
            for (var d = 1; d <= 31; d++)
              DropdownMenuItem<int>(
                value: d,
                child: Text('Day $d', style: AppTextStyles.bodyLgTabular),
              ),
          ],
          onChanged: (int? d) {
            if (d != null) onMonthDay(d);
          },
        );
    }
  }
}
