import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/time/today_provider.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/list_detail_layout.dart';
import '../../../../core/widgets/segmented_toggle.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../dashboard/application/portfolio_providers.dart';
import '../widgets/calendar_legend.dart';
import '../widgets/day_agenda.dart';
import '../widgets/month_grid.dart';

/// Month grid or month list.
enum CalendarMode { month, list }

/// Months ahead of today the calendar can show.
const int calendarMonthsAhead = 12;

/// The Calendar destination: month navigation, a Month / List toggle, the
/// month grid with status dots and legend totals, and the selected day's
/// collections (Record / Call). Expanded windows split grid | day list.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  /// First day of the shown month; null until the first build.
  CivilDate? _month;
  CivilDate? _selected;
  CalendarMode _mode = CalendarMode.month;

  static CivilDate _firstOf(CivilDate d) => CivilDate(d.year, d.month, 1);

  void _shift(int months, CivilDate today) {
    final next = _month!.addMonthsClamped(months, preferredDay: 1);
    setState(() {
      _month = next;
      _selected = _firstOf(today) == next ? today : next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final month = _month ??= _firstOf(today);
    final selected = _selected ??= today;
    final metricsAsync = ref.watch(portfolioProvider);
    final metrics = metricsAsync.value;
    if (metrics == null) {
      return metricsAsync.hasError
          ? const EmptyState(
              key: ValueKey<String>('calendar_error'),
              icon: Icons.cloud_off_outlined,
              title: "Couldn't load the calendar",
            )
          : const Center(child: CircularProgressIndicator());
    }

    final days =
        ref.watch(calendarMonthProvider(month.year, month.month)) ??
        const <CalendarDay>[];
    final totals = CalendarTotals.of(days);
    final minMonth = chartWindowStart(today);
    final maxMonth = _firstOf(
      today,
    ).addMonthsClamped(calendarMonthsAhead, preferredDay: 1);
    final split = WindowSize.of(context).isExpanded;

    final header = _MonthHeader(
      month: month,
      mode: _mode,
      canBack: month.isAfter(minMonth),
      canForward: month.isBefore(maxMonth),
      onBack: () => _shift(-1, today),
      onForward: () => _shift(1, today),
      onMode: (CalendarMode m) => setState(() => _mode = m),
    );

    final dayAgenda = DayAgenda(
      date: selected,
      today: today,
      items:
          ref.watch(dueItemsProvider(selected, selected)) ??
          const <DueRowItem>[],
    );

    final List<Widget> main;
    if (_mode == CalendarMode.month) {
      main = <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              MonthGrid(
                days: days,
                today: today,
                selected: selected,
                onSelect: (CivilDate d) => setState(() => _selected = d),
              ),
              const SizedBox(height: AppSpacing.md),
              CalendarLegend(totals: totals),
            ],
          ),
        ),
      ];
    } else {
      final last = CivilDate(
        month.year,
        month.month,
        CivilDate.daysInMonth(month.year, month.month),
      );
      final items =
          ref.watch(dueItemsProvider(month, last)) ?? const <DueRowItem>[];
      final byDay = <CivilDate, List<DueRowItem>>{};
      for (final i in items) {
        (byDay[i.dueDate] ??= <DueRowItem>[]).add(i);
      }
      main = <Widget>[
        CalendarLegend(totals: totals),
        const SizedBox(height: AppSpacing.md),
        if (byDay.isEmpty)
          const EmptyState(
            key: ValueKey<String>('calendar_list_empty'),
            icon: Icons.event_available_outlined,
            title: 'No collections this month',
          )
        else
          for (final entry in byDay.entries) ...<Widget>[
            DayAgenda(
              date: entry.key,
              today: today,
              items: entry.value,
              onHeaderTap: split
                  ? () => setState(() => _selected = entry.key)
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ];
    }

    if (split) {
      return ListDetailLayout(
        list: ListView(
          key: const ValueKey<String>('calendar_main'),
          padding: AppInsets.pageBody,
          children: <Widget>[header, ...main],
        ),
        detail: ListView(
          key: const ValueKey<String>('calendar_detail'),
          padding: AppInsets.pageBody.copyWith(left: AppSpacing.lg),
          children: <Widget>[dayAgenda],
        ),
        emptyDetail: const SizedBox.shrink(),
      );
    }
    return ListView(
      key: const ValueKey<String>('calendar_main'),
      padding: AppInsets.pageBody,
      children: <Widget>[
        header,
        ...main,
        if (_mode == CalendarMode.month) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          dayAgenda,
        ],
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.mode,
    required this.canBack,
    required this.canForward,
    required this.onBack,
    required this.onForward,
    required this.onMode,
  });

  final CivilDate month;
  final CalendarMode mode;
  final bool canBack;
  final bool canForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final ValueChanged<CalendarMode> onMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                key: const ValueKey<String>('cal_prev'),
                tooltip: 'Previous month',
                onPressed: canBack ? onBack : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Flexible(
                child: Semantics(
                  header: true,
                  liveRegion: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${civilMonthName(month.month)} ${month.year}',
                      key: const ValueKey<String>('cal_title'),
                      style: AppTextStyles.headlineSmTabular,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey<String>('cal_next'),
                tooltip: 'Next month',
                onPressed: canForward ? onForward : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          SegmentedToggle<CalendarMode>(
            key: const ValueKey<String>('cal_mode'),
            segments: const <ToggleSegment<CalendarMode>>[
              ToggleSegment<CalendarMode>(
                value: CalendarMode.month,
                label: 'Month',
              ),
              ToggleSegment<CalendarMode>(
                value: CalendarMode.list,
                label: 'List',
              ),
            ],
            selected: mode,
            onChanged: onMode,
          ),
        ],
      ),
    );
  }
}
