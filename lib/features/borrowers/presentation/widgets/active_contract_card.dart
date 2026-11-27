import 'package:flutter/material.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../contracts/application/loan_label.dart';
import 'standing_pill.dart';

/// One active contract on the borrower profile: Loan #, frequency chip, due
/// badge, disbursed date, Sanctioned / Paid / Remaining, the cleared % bar,
/// next due, cycles and "Record ₹X". Tapping opens the contract.
class ActiveContractCard extends StatelessWidget {
  const ActiveContractCard({
    required this.projection,
    required this.onOpen,
    required this.onRecord,
    super.key,
  });

  final ContractProjection projection;
  final VoidCallback onOpen;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final p = projection;
    final c = p.contract;
    final next = p.nextDue;
    final pct = p.clearedBps ~/ 100;
    final onboarded = onboardedLabel(c);
    final ref = c.isOnboarded ? c.previousRef : null;
    return AppCard(
      key: ValueKey<String>('contract_card_${c.id}'),
      onTap: onOpen,
      semanticLabel: loanLabel(c.loanNo),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(loanLabel(c.loanNo), style: AppTextStyles.titleMdTabular),
              StatusPill(
                label: frequencyLabel(c.frequency),
                kind: StatusKind.info,
                icon: Icons.repeat,
              ),
              StandingPill(
                standing: contractStanding(p),
                daysOverdue: p.maxDaysOverdue,
              ),
              if (onboarded != null)
                StatusPill(
                  key: ValueKey<String>('onboarded_${c.id}'),
                  label: onboarded,
                  kind: StatusKind.info,
                  icon: Icons.history,
                ),
            ],
          ),
          if (ref != null && ref.isNotEmpty)
            Text('Ref $ref', style: AppTextStyles.bodySmTabular),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Disbursed ${formatCivilDate(c.disbursedOn)}',
            style: AppTextStyles.bodySmTabular,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              _Figure(label: 'Sanctioned', value: c.sanctioned),
              _Figure(
                label: 'Paid',
                value: p.totalPaid - p.totalWaived,
                color: AppColors.collected,
              ),
              _Figure(label: 'Remaining', value: p.outstanding),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label: '$pct% cleared',
            child: ClipRRect(
              borderRadius: AppRadii.fullAll,
              child: LinearProgressIndicator(
                value: p.clearedBps / 10000,
                minHeight: AppSizes.clearedBarHeight,
                color: AppColors.collected,
                backgroundColor: AppColors.track,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '$pct% cleared',
                  style: AppTextStyles.bodySmTabular,
                ),
              ),
              Text(
                '${p.cyclesPaid}/${p.cyclesTotal} cycles',
                style: AppTextStyles.bodySmTabular,
              ),
            ],
          ),
          if (next != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Next ${formatInr(next.remaining)} · '
              '${formatCivilDateWithWeekday(next.dueDate)}',
              style: AppTextStyles.bodyMdTabular,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: ValueKey<String>('record_${c.id}'),
              onPressed: onRecord,
              child: Text('Record ${formatInr(next.remaining)}'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});

  final String label;
  final Money value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.labelMd.copyWith(color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: MoneyText(value, color: color),
        ),
      ],
    ),
  );
}
