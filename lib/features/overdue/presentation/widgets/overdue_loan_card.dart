import 'package:flutter/material.dart';

import '../../../../core/phone/indian_phone.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../contracts/application/loan_label.dart';
import '../../../dashboard/presentation/due_row_status.dart';
import 'overdue_actions.dart';

/// One overdue loan: borrower, loan and frequency, "N days late" (critical
/// terracotta, recent amber), the oldest scheduled date, phone, overdue ₹,
/// and Call / WhatsApp / Record ₹X.
class OverdueLoanCard extends StatelessWidget {
  const OverdueLoanCard({
    required this.loan,
    required this.onOpen,
    this.selected = false,
    super.key,
  });

  final OverdueLoan loan;
  final VoidCallback onOpen;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l = loan;
    final critical = l.severity == OverdueSeverity.critical;
    final id = l.contractId;
    final card = AppCard(
      key: ValueKey<String>('overdue_loan_$id'),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l.borrowerName,
                      style: AppTextStyles.titleMd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${loanLabel(l.loanNo)} · ${frequencyLabel(l.frequency)}',
                      style: AppTextStyles.bodySmTabular,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: StatusPill(
                  label: daysLate(l.daysOverdue),
                  kind: critical ? StatusKind.overdue : StatusKind.upcoming,
                  icon: Icons.schedule,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.pressed,
              borderRadius: AppRadii.mdAll,
            ),
            child: Padding(
              padding: AppInsets.cardCompact,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Scheduled ${formatCivilDate(l.oldestDueDate)}'
                        '${l.installmentCount > 1 ? ' · ${l.installmentCount} installments' : ''}',
                        style: AppTextStyles.bodySmTabular,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        IndianPhone.format(l.borrowerPhoneE164),
                        style: AppTextStyles.bodyMdTabular,
                      ),
                    ],
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        'Overdue',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      MoneyText(
                        l.amount,
                        style: AppTextStyles.headlineSmTabular,
                        color: critical
                            ? AppColors.overdue
                            : AppColors.textPrimary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OverdueActions(loan: l),
        ],
      ),
    );
    if (!selected) return card;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary),
        borderRadius: AppRadii.lgAll,
      ),
      child: card,
    );
  }
}
