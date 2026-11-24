import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../application/dashboard_filters.dart';
import 'due_row_card.dart';

/// "Due today" with All / Pending / Collected chips and a card per row.
class DueTodayList extends StatefulWidget {
  const DueTodayList({required this.items, this.onViewSchedule, super.key});

  final List<TodayDueItem> items;

  /// "View schedule" (opens the calendar tab); hidden when null.
  final VoidCallback? onViewSchedule;

  @override
  State<DueTodayList> createState() => _DueTodayListState();
}

class _DueTodayListState extends State<DueTodayList> {
  DueTodayFilter _filter = DueTodayFilter.all;

  @override
  Widget build(BuildContext context) {
    final all = widget.items;
    final pending = all.where((TodayDueItem i) => !i.isPaid).length;
    final shown = filterDueToday(all, _filter);
    final counts = <DueTodayFilter, int>{
      DueTodayFilter.all: all.length,
      DueTodayFilter.pending: pending,
      DueTodayFilter.collected: all.length - pending,
    };
    const labels = <DueTodayFilter, String>{
      DueTodayFilter.all: 'All',
      DueTodayFilter.pending: 'Pending',
      DueTodayFilter.collected: 'Collected',
    };
    return Column(
      key: const ValueKey<String>('due_today_list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: 'Due today',
          actionLabel: widget.onViewSchedule == null ? null : 'View schedule',
          onAction: widget.onViewSchedule,
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final f in DueTodayFilter.values)
              ChoiceChip(
                key: ValueKey<String>('due_filter_${f.name}'),
                label: Text(
                  '${labels[f]} (${counts[f]})',
                  style: AppTextStyles.labelMdTabular,
                ),
                selected: _filter == f,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (bool _) => setState(() => _filter = f),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (shown.isEmpty)
          Padding(
            padding: AppInsets.listRow,
            child: Text(
              all.isEmpty
                  ? 'No collections are due today.'
                  : (_filter == DueTodayFilter.pending
                        ? 'Everything due today is collected.'
                        : 'Nothing collected yet today.'),
              key: const ValueKey<String>('due_today_empty'),
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          for (final item in shown) ...<Widget>[
            DueRowCard(item: item),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}
