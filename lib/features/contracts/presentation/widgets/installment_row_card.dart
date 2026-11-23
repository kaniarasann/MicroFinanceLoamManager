import 'package:flutter/material.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../../domain/models/enums.dart';
import '../../application/contract_providers.dart';
import '../../application/loan_label.dart';
import 'dashed_border_card.dart';

/// One timeline row of the contract schedule: paid, partial, overdue, due
/// today, upcoming, planned, rescheduled (moved away), or a computed
/// auto-extension ("Installment N · Added", dashed). The last row carries
/// the "Maturity" pill.
class InstallmentRowCard extends StatelessWidget {
  const InstallmentRowCard({
    required this.row,
    required this.view,
    this.isLast = false,
    this.onCollect,
    this.onReschedule,
    super.key,
  });

  final ProjectedRow row;
  final ContractView view;
  final bool isLast;
  final VoidCallback? onCollect;
  final VoidCallback? onReschedule;

  @override
  Widget build(BuildContext context) {
    final content = _Content(
      row: row,
      view: view,
      isLast: isLast,
      onCollect: onCollect,
      onReschedule: onReschedule,
    );
    if (row.isExtension) return DashedBorderCard(child: content);
    if (row.status == RowStatus.overdue) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.lgAll,
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.overdueBorder),
          ),
        ),
        child: ClipRRect(
          borderRadius: AppRadii.lgAll,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const ColoredBox(
                  key: ValueKey<String>('overdue_rail'),
                  color: AppColors.overdue,
                  child: SizedBox(width: AppSizes.timelineRail),
                ),
                Expanded(
                  child: Padding(
                    padding: AppInsets.cardCompact,
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return AppCard(child: content);
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.row,
    required this.view,
    required this.isLast,
    required this.onCollect,
    required this.onReschedule,
  });

  final ProjectedRow row;
  final ContractView view;
  final bool isLast;
  final VoidCallback? onCollect;
  final VoidCallback? onReschedule;

  String get _title {
    if (row.isExtension) return 'Installment ${row.seq} · Added';
    if (row.kind == InstallmentKind.rescheduled) {
      return 'Installment ${row.seq} · Moved';
    }
    return 'Installment ${row.seq}';
  }

  (IconData, Color) get _icon => switch (row.status) {
    RowStatus.paid => (Icons.check_circle, AppColors.collected),
    RowStatus.overdue => (Icons.error_outline, AppColors.overdue),
    RowStatus.dueToday => (Icons.schedule, AppColors.upcoming),
    RowStatus.upcoming => (Icons.event, AppColors.upcoming),
    RowStatus.planned =>
      row.isExtension
          ? (Icons.add_circle_outline, AppColors.textSecondary)
          : (Icons.event_outlined, AppColors.textTertiary),
    RowStatus.rescheduled => (Icons.redo, AppColors.textSecondary),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor) = _icon;
    final away = row.isRescheduledAway;
    final amountStyle = away
        ? AppTextStyles.currencyItem.copyWith(
            decoration: TextDecoration.lineThrough,
            color: AppColors.textTertiary,
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: AppSizes.iconMd, color: iconColor),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_title, style: AppTextStyles.titleMdTabular),
                  Text(
                    formatCivilDateWithWeekday(row.dueDate),
                    style: AppTextStyles.bodySmTabular,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            MoneyText(away ? row.scheduledAmount : row.due, style: amountStyle),
          ],
        ),
        ..._details(),
        if (row.status == RowStatus.overdue &&
            (onCollect != null || onReschedule != null)) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              if (onCollect != null)
                FilledButton(
                  key: ValueKey<String>('collect_${row.seq}'),
                  onPressed: onCollect,
                  child: Text('Collect ${formatInr(row.remaining)}'),
                ),
              if (onReschedule != null)
                OutlinedButton(
                  key: ValueKey<String>('reschedule_${row.seq}'),
                  onPressed: onReschedule,
                  child: const Text('Reschedule'),
                ),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _details() {
    final pills = <Widget>[];
    final lines = <String>[];
    final today = view.projection.today;
    switch (row.status) {
      case RowStatus.paid:
        pills.add(
          const StatusPill(
            label: 'Paid',
            kind: StatusKind.collected,
            icon: Icons.check,
          ),
        );
        final s = row.installmentId == null
            ? null
            : view.settlements[row.installmentId];
        if (s?.mode != null) {
          pills.add(
            StatusPill(
              label: paymentModeLabel(s!.mode!),
              kind: StatusKind.info,
            ),
          );
        }
        if (s != null) lines.add('Cleared ${formatCivilDate(s.clearedOn)}');
      case RowStatus.overdue:
        lines.add('Overdue by ${_days(row.daysOverdue)}');
      case RowStatus.dueToday:
        pills.add(
          const StatusPill(label: 'Due today', kind: StatusKind.upcoming),
        );
      case RowStatus.upcoming:
        final n = today.daysBetween(row.dueDate);
        pills.add(
          StatusPill(
            label: n == 1 ? 'Due tomorrow' : 'Due in $n days',
            kind: StatusKind.upcoming,
          ),
        );
      case RowStatus.planned:
        pills.add(const StatusPill(label: 'Planned', kind: StatusKind.neutral));
      case RowStatus.rescheduled:
        lines.add(_movedTo(row.installmentId) ?? 'Rescheduled');
    }
    if (row.isPartial) {
      pills.insert(
        0,
        StatusPill(
          label: 'Partial · ${formatInr(row.remaining)} short',
          kind: StatusKind.upcoming,
        ),
      );
      lines.add('Paid ${formatInr(row.paid)} of ${formatInr(row.due)}');
    }
    if (!row.isRescheduledAway && row.rescheduledOut.isPositive) {
      final to = _movedTo(row.installmentId);
      lines.add('${formatInr(row.rescheduledOut)} ${_lower(to ?? 'moved')}');
    }
    if (row.kind == InstallmentKind.rescheduled) {
      final from = view.seqOf(row.rescheduledFromId);
      if (from != null) lines.add('Moved from Inst. $from');
    }
    final source = row.sourceLabel;
    if (row.isExtension && source != null) {
      lines.add('${source[0].toUpperCase()}${source.substring(1)}');
    }
    if (isLast) {
      pills.add(
        const StatusPill(
          key: ValueKey<String>('maturity_pill'),
          label: 'Maturity',
          kind: StatusKind.info,
          icon: Icons.flag_outlined,
        ),
      );
    }
    return <Widget>[
      if (pills.isNotEmpty) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: pills,
        ),
      ],
      for (final line in lines) ...<Widget>[
        const SizedBox(height: AppSpacing.xs),
        Text(
          line,
          style: row.status == RowStatus.overdue && line.startsWith('Overdue')
              ? AppTextStyles.bodyMdTabular.copyWith(color: AppColors.overdue)
              : AppTextStyles.bodyMdTabular.copyWith(
                  color: AppColors.textSecondary,
                ),
        ),
      ],
    ];
  }

  String? _movedTo(String? id) {
    if (id == null) return null;
    final dates = view.movedTo(id);
    if (dates.isEmpty) return null;
    return 'Moved to ${dates.map(formatCivilDate).join(', ')}';
  }

  static String _lower(String s) => '${s[0].toLowerCase()}${s.substring(1)}';

  static String _days(int n) => n == 1 ? '1 day' : '$n days';
}
