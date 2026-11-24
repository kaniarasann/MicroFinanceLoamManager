import 'package:flutter/material.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../domain/ledger/ledger.dart';

/// Monday-first month grid. Each day shows its number and up to three
/// status dots: sage (collected), amber (pending), terracotta (overdue).
/// The selected day is a navy circle; today is outlined. Each cell is a
/// 48dp touch target with a spoken summary.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    required this.days,
    required this.today,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  /// One entry per day of the month (from `calendarBuckets`).
  final List<CalendarDay> days;
  final CivilDate today;
  final CivilDate? selected;
  final ValueChanged<CivilDate> onSelect;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final lead = days.first.date.weekday - 1;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (final d in days)
        _DayCell(
          day: d,
          isToday: d.date == today,
          isSelected: d.date == selected,
          onTap: () => onSelect(d.date),
        ),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }
    return Column(
      key: const ValueKey<String>('month_grid'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(
          child: Row(
            children: <Widget>[
              for (var w = 1; w <= 7; w++)
                Expanded(
                  child: Center(
                    child: Text(
                      civilWeekdayShortName(w),
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var r = 0; r < cells.length; r += 7)
          Row(
            children: <Widget>[
              for (var c = r; c < r + 7; c++) Expanded(child: cells[c]),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final CalendarDay day;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = day;
    final dots = <Color>[
      if (d.hasCollectedDot) AppColors.collected,
      if (d.hasPendingDot) AppColors.upcoming,
      if (d.hasOverdueDot) AppColors.overdue,
    ];
    return Semantics(
      button: true,
      selected: isSelected,
      label: _spoken(d, isToday),
      child: ExcludeSemantics(
        child: InkWell(
          key: ValueKey<String>('cal_day_${d.date}'),
          borderRadius: AppRadii.baseAll,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.calendarCell + AppSpacing.sm,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: AppSizes.calendarDayBadge,
                  height: AppSizes.calendarDayBadge,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : null,
                    shape: BoxShape.circle,
                    border: isToday && !isSelected
                        ? Border.all(color: AppColors.primary)
                        : null,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${d.date.day}',
                      style: AppTextStyles.labelLgTabular.copyWith(
                        color: isSelected
                            ? AppColors.onPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: AppSizes.statusDot,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (var i = 0; i < dots.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: AppSpacing.xxs),
                        Container(
                          width: AppSizes.statusDot,
                          height: AppSizes.statusDot,
                          decoration: BoxDecoration(
                            color: dots[i],
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _spoken(CalendarDay d, bool isToday) {
    final parts = <String>[
      '${formatCivilDateWithWeekday(d.date)}${isToday ? ', today' : ''}',
      if (d.settled.isPositive) 'collected ${formatInr(d.settled)}',
      if (d.pendingCount > 0) '${d.pendingCount} pending',
      if (d.overdueCount > 0) '${d.overdueCount} overdue',
    ];
    if (parts.length == 1) parts.add('nothing scheduled');
    return parts.join(', ');
  }
}
