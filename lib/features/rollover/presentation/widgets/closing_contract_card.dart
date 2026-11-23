import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../contracts/application/loan_label.dart';

/// The loan being closed: Sanctioned / Paid / Outstanding and the
/// "will close as Rolled over" note.
class ClosingContractCard extends StatelessWidget {
  const ClosingContractCard({required this.projection, super.key});

  final ContractProjection projection;

  @override
  Widget build(BuildContext context) {
    final p = projection;
    final c = p.contract;
    final label = AppTextStyles.labelMd.copyWith(
      color: AppColors.textSecondary,
    );
    Widget tile(String text, Money value, String key, {Color? color}) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(text, style: label, maxLines: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: MoneyText(
                  value,
                  key: ValueKey<String>(key),
                  color: color,
                ),
              ),
            ],
          ),
        );
    return AppCard(
      key: const ValueKey<String>('closing_contract_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Closing contract', style: label),
          Text(
            '${c.borrowerName} · ${loanLabel(c.loanNo)}',
            style: AppTextStyles.titleMd,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              tile('Sanctioned', c.sanctioned, 'closing_sanctioned'),
              tile(
                'Paid',
                Money.min(p.totalPaid - p.totalWaived, c.sanctioned),
                'closing_paid',
              ),
              tile(
                'Outstanding',
                p.outstanding,
                'closing_outstanding',
                color: AppColors.overdue,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${loanLabel(c.loanNo)} will close as Rolled over. '
            'Full history is kept.',
            key: const ValueKey<String>('closing_note'),
            style: AppTextStyles.bodySmTabular,
          ),
        ],
      ),
    );
  }
}
