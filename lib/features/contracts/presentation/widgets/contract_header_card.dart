import 'package:flutter/material.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../../domain/models/enums.dart';
import '../../application/loan_label.dart';

/// Contract detail header: borrower, Loan #, purpose, status pill, the
/// Sanctioned / Disbursed / Upfront fee tiles and the principal-cleared
/// bar with cycles.
class ContractHeaderCard extends StatelessWidget {
  const ContractHeaderCard({required this.projection, super.key});

  final ContractProjection projection;

  static (String, StatusKind) statusOf(ContractStatus s) => switch (s) {
    ContractStatus.active => ('Active', StatusKind.collected),
    ContractStatus.closed => ('Closed', StatusKind.neutral),
    ContractStatus.rolledOver => ('Rolled over', StatusKind.info),
    ContractStatus.cancelled => ('Cancelled', StatusKind.neutral),
  };

  @override
  Widget build(BuildContext context) {
    final p = projection;
    final c = p.contract;
    final (label, kind) = statusOf(c.status);
    final cleared = Money.min(p.totalPaid, c.sanctioned);
    final purpose = c.purpose;
    return AppCard(
      padding: AppCardPadding.spacious,
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
                    Text(c.borrowerName, style: AppTextStyles.headlineSm),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      <String>[
                        loanLabel(c.loanNo),
                        frequencyLabel(c.frequency),
                        if (purpose != null && purpose.isNotEmpty) purpose,
                      ].join(' · '),
                      style: AppTextStyles.bodyMdTabular.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(
                key: const ValueKey<String>('contract_status'),
                label: label,
                kind: kind,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              _Tile(label: 'Sanctioned', value: c.sanctioned),
              _Tile(label: 'Disbursed', value: c.netDisbursed),
              _Tile(label: 'Upfront fee', value: c.upfront),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Disbursed ${formatCivilDate(c.disbursedOn)}',
            style: AppTextStyles.bodySmTabular,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Principal cleared',
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            label: '${p.clearedBps ~/ 100}% cleared',
            child: ClipRRect(
              borderRadius: AppRadii.fullAll,
              child: LinearProgressIndicator(
                value: p.clearedBps / bpsScale,
                minHeight: AppSizes.clearedBarHeight,
                color: AppColors.collected,
                backgroundColor: AppColors.track,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${formatInr(cleared)} / ${formatInr(c.sanctioned)} · '
            '${p.cyclesPaid}/${p.cyclesTotal} cycles',
            key: const ValueKey<String>('cleared_line'),
            style: AppTextStyles.bodyMdTabular,
          ),
          if (p.totalWaived.isPositive)
            Text(
              'Waived ${formatInr(p.totalWaived)}',
              key: const ValueKey<String>('waived_line'),
              style: AppTextStyles.bodySmTabular,
            ),
          Text(
            'Maturity ${formatCivilDate(p.maturityDate)}',
            style: AppTextStyles.bodySmTabular,
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});

  final String label;
  final Money value;

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
          child: MoneyText(value),
        ),
      ],
    ),
  );
}
