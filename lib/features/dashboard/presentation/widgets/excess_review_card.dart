import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../../domain/models/enums.dart';
import '../../../contracts/application/loan_label.dart';

/// "Excess to review": loans whose recorded collections exceed what was
/// owed (a duplicate offline payment, or one that arrived after a close or
/// rollover). Each row opens the loan, where an owner reverses the
/// duplicate.
class ExcessReviewCard extends StatelessWidget {
  const ExcessReviewCard({
    required this.items,
    required this.isOwner,
    super.key,
  });

  final List<ExcessItem> items;

  /// Owners reverse duplicates themselves; collectors are asked to hand it
  /// to an owner (reversal is owner-only).
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final total = Money.sum(items.map((ExcessItem i) => i.excess));
    return AppCard(
      key: const ValueKey<String>('excess_review'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.rule_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text('Excess to review', style: AppTextStyles.titleMd),
              ),
              MoneyText(total),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${items.length == 1 ? '1 loan has' : '${items.length} loans have'}'
            ' more collected than was owed. '
            '${isOwner ? 'Open the loan to review and reverse the duplicate payment.' : 'Ask an owner to review and reverse the duplicate payment.'}',
            style: AppTextStyles.bodySmTabular,
          ),
          for (final i in items)
            InkWell(
              key: ValueKey<String>('excess_${i.contractId}'),
              borderRadius: AppRadii.baseAll,
              onTap: () => unawaited(
                context.push<void>(AppRoutes.contract(i.contractId)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.minTouchTarget,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${i.borrowerName} · ${loanLabel(i.loanNo)} · '
                        '${_statusLabel(i.status)}',
                        style: AppTextStyles.bodyMdTabular,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    MoneyText(i.excess, color: AppColors.primary),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _statusLabel(ContractStatus s) => switch (s) {
    ContractStatus.active => 'Active',
    ContractStatus.closed => 'Closed',
    ContractStatus.rolledOver => 'Rolled over',
    ContractStatus.cancelled => 'Cancelled',
  };
}
