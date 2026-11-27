import 'package:flutter/material.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/ledger/ledger.dart';

/// The label and kind of one projected row's status pill. Colour is
/// always paired with a label.
(String, StatusKind, IconData?) projectedRowPill(ProjectedRow r) {
  if (r.isExtension && r.status != RowStatus.paid) {
    return ('Added', StatusKind.info, Icons.add);
  }
  return switch (r.status) {
    RowStatus.paid => ('Paid', StatusKind.collected, Icons.check),
    RowStatus.overdue => (
      r.isPartial
          ? 'Partially paid · ${r.daysOverdue}d late'
          : 'Overdue · ${r.daysOverdue} ${r.daysOverdue == 1 ? 'day' : 'days'} late',
      StatusKind.overdue,
      Icons.error_outline,
    ),
    RowStatus.dueToday => (
      r.isPartial ? 'Partially paid · due today' : 'Due today',
      StatusKind.upcoming,
      Icons.schedule,
    ),
    RowStatus.upcoming || RowStatus.planned => (
      r.isPartial ? 'Partially paid' : 'Upcoming',
      r.isPartial ? StatusKind.upcoming : StatusKind.neutral,
      null,
    ),
    RowStatus.rescheduled => ('Moved', StatusKind.neutral, Icons.redo),
  };
}

/// "As of today" timeline of a [ContractProjection]: one line per row
/// (seq, due date, paid of due, status pill), lazily built inside a
/// bounded height, so a 366-row daily loan stays cheap.
class ProjectedSchedulePreview extends StatelessWidget {
  const ProjectedSchedulePreview({required this.rows, super.key});

  final List<ProjectedRow> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey<String>('projected_schedule'),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.mdAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: AppSizes.boundedListMaxHeight,
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: AppInsets.cardCompact,
          itemCount: rows.length,
          separatorBuilder: (BuildContext _, int _) => const Divider(),
          itemBuilder: (BuildContext _, int i) => _Row(row: rows[i]),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});

  final ProjectedRow row;

  @override
  Widget build(BuildContext context) {
    final (label, kind, icon) = projectedRowPill(row);
    final r = row;
    return Padding(
      key: ValueKey<String>('projected_row_${r.seq}'),
      padding: AppInsets.listRow,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: AppSizes.avatarMd,
            child: Text(
              r.isExtension ? '+${r.seq}' : '${r.seq}',
              style: AppTextStyles.labelLgTabular,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${formatCivilDateWithWeekday(r.dueDate)} ${r.dueDate.year}',
                  style: AppTextStyles.bodyMdTabular,
                ),
                const SizedBox(height: AppSpacing.xxs),
                StatusPill(label: label, kind: kind, icon: icon),
                if (r.isPartial)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(
                      'Paid ${formatInr(r.paid)} of ${formatInr(r.due)}',
                      style: AppTextStyles.bodySmTabular,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          MoneyText(r.due),
        ],
      ),
    );
  }
}
