import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/phone/indian_phone.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../contracts/application/loan_label.dart';
import '../../../dashboard/presentation/due_row_status.dart';
import 'overdue_actions.dart';

/// Tablet detail pane of the overdue tracker: the selected loan's overdue
/// installments, the contact / record actions and a link to the full
/// schedule.
class OverdueDetailPane extends StatelessWidget {
  const OverdueDetailPane({required this.loan, required this.rows, super.key});

  final OverdueLoan loan;

  /// The loan's overdue rows (oldest first).
  final List<OverdueItem> rows;

  @override
  Widget build(BuildContext context) {
    final l = loan;
    return ListView(
      key: ValueKey<String>('overdue_detail_${l.contractId}'),
      padding: AppInsets.pageBody.copyWith(left: AppSpacing.lg),
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(l.borrowerName, style: AppTextStyles.headlineLg),
        ),
        Text(
          '${loanLabel(l.loanNo)} · ${frequencyLabel(l.frequency)} · '
          '${IndianPhone.format(l.borrowerPhoneE164)}',
          style: AppTextStyles.bodyMdTabular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Overdue',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              MoneyText(
                l.amount,
                style: AppTextStyles.headlineSmTabular,
                color: AppColors.overdue,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OverdueActions(loan: l),
        const SectionHeader(title: 'Missed installments'),
        for (final r in rows)
          Padding(
            padding: AppInsets.listRow,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Inst. ${r.seq} · ${formatCivilDate(r.dueDate)}',
                    style: AppTextStyles.bodyMdTabular,
                  ),
                ),
                StatusPill(
                  label: daysLate(r.daysOverdue),
                  kind: r.severity == OverdueSeverity.critical
                      ? StatusKind.overdue
                      : StatusKind.upcoming,
                ),
                const SizedBox(width: AppSpacing.sm),
                MoneyText(r.amount),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          key: const ValueKey<String>('overdue_open_schedule'),
          onPressed: () =>
              unawaited(context.push<void>(AppRoutes.contract(l.contractId))),
          icon: const Icon(Icons.event_note_outlined),
          label: const Text('Open loan schedule'),
        ),
      ],
    );
  }
}
