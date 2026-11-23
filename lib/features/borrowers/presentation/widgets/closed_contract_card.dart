import 'package:flutter/material.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/models/models.dart';
import '../../../contracts/application/loan_label.dart';

/// A closed or rolled-over contract. A rolled-over one links to its
/// successor ("Rolled over → #NN").
class ClosedContractCard extends StatelessWidget {
  const ClosedContractCard({
    required this.contract,
    required this.onOpen,
    this.successor,
    this.onOpenSuccessor,
    super.key,
  });

  final Contract contract;
  final Contract? successor;
  final VoidCallback onOpen;
  final VoidCallback? onOpenSuccessor;

  @override
  Widget build(BuildContext context) {
    final c = contract;
    final rolled = c.status == ContractStatus.rolledOver;
    final next = successor;
    return AppCard(
      key: ValueKey<String>('closed_card_${c.id}'),
      onTap: onOpen,
      semanticLabel: loanLabel(c.loanNo),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  loanLabel(c.loanNo),
                  style: AppTextStyles.titleMdTabular,
                ),
              ),
              StatusPill(
                label: rolled ? 'Rolled over' : 'Closed',
                kind: rolled ? StatusKind.info : StatusKind.neutral,
                icon: rolled ? Icons.autorenew : Icons.check,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Sanctioned ${formatInr(c.sanctioned)} · '
            'Paid ${formatInr(c.totalPaid)}',
            style: AppTextStyles.bodyMdTabular,
          ),
          Text(
            '${frequencyLabel(c.frequency)} · disbursed '
            '${formatCivilDate(c.disbursedOn)}',
            style: AppTextStyles.bodySmTabular,
          ),
          if (rolled && c.rolledOverToContractId != null)
            TextButton(
              key: ValueKey<String>('rolled_link_${c.id}'),
              onPressed: onOpenSuccessor,
              child: Text(
                next == null
                    ? 'Rolled over → new loan'
                    : 'Rolled over → ${loanNumber(next.loanNo)}',
              ),
            ),
        ],
      ),
    );
  }
}
