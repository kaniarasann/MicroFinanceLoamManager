import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../contracts/application/loan_label.dart';
import '../contact_actions.dart';
import '../due_row_status.dart';

/// One schedule row (Due today list, calendar day list): borrower, loan,
/// frequency and installment n/N (extension rows: "Added · missed on
/// {date} (Inst. n)"), the open amount and a status pill. Open rows get
/// Record (to `/contracts/{id}/pay`) and Call; settled rows and rows of
/// closed / rolled-over loans get neither. Tapping the card opens the loan.
class DueRowCard extends ConsumerWidget {
  const DueRowCard({required this.item, super.key});

  final DueRowItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = dueRowStatus(item);
    final id = '${item.contractId}_${item.seq}';
    final amount = item.isPaid ? item.amount : item.remaining;
    final instLabel = item.isExtension
        ? (item.sourceLabel == null ? 'Added' : 'Added · ${item.sourceLabel}')
        : 'Inst. ${item.seq}/${item.cyclesTotal}';
    return AppCard(
      key: ValueKey<String>('due_row_$id'),
      onTap: () =>
          unawaited(context.push<void>(AppRoutes.contract(item.contractId))),
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
                      item.borrowerName,
                      style: AppTextStyles.titleMd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${loanLabel(item.loanNo)} · '
                      '${frequencyLabel(item.frequency)} · $instLabel',
                      style: AppTextStyles.bodySmTabular,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              MoneyText(
                amount,
                color: item.isPaid
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusPill(
              label: status.label,
              kind: status.kind,
              icon: status.icon,
            ),
          ),
          if (!item.isPaid) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    key: ValueKey<String>('due_record_$id'),
                    onPressed: () => unawaited(
                      context.push<void>(
                        AppRoutes.recordPayment(item.contractId),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Record'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton(
                  key: ValueKey<String>('due_call_$id'),
                  onPressed: () => unawaited(
                    callBorrower(context, ref, item.borrowerPhoneE164),
                  ),
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  child: Icon(
                    Icons.call_outlined,
                    semanticLabel: 'Call ${item.borrowerName}',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
