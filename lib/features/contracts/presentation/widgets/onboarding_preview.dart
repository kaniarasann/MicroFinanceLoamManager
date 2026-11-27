import 'package:flutter/material.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/kpi_tile.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/ledger/ledger.dart';
import 'ledger_banner.dart';
import 'projected_schedule_preview.dart';

/// Step 4 "As of today": Collected / Outstanding / Overdue tiles, the
/// maturity and cycles line, the projected timeline (paid, partial,
/// overdue with days late, due today, upcoming, added) and the
/// auto-extension note. [projection] is the projection of the plan the
/// save will write, so it matches the contract detail after saving. Null
/// shows a hint until every field is valid.
class OnboardingPreview extends StatelessWidget {
  const OnboardingPreview({required this.projection, super.key});

  final ContractProjection? projection;

  @override
  Widget build(BuildContext context) {
    final p = projection;
    if (p == null) {
      return AppCard(
        key: const ValueKey<String>('onboarding_preview_empty'),
        child: Text(
          'The preview appears once the terms, dates and payments are valid.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    final cash = p.totalPaid - p.totalWaived;
    final n = p.overdueCount;
    final semantics =
        'As of today: collected ${formatInr(cash)}, outstanding '
        '${formatInr(p.outstanding)}, overdue ${formatInr(p.overdueAmount)} '
        'over $n ${n == 1 ? 'installment' : 'installments'}.';
    return Semantics(
      container: true,
      label: semantics,
      child: Column(
        key: const ValueKey<String>('onboarding_preview'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: KpiTile(
                    key: const ValueKey<String>('preview_collected'),
                    label: 'Collected',
                    value: cash,
                    valueKind: StatusKind.collected,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: KpiTile(
                    key: const ValueKey<String>('preview_outstanding'),
                    label: 'Outstanding',
                    value: p.outstanding,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          KpiTile(
            key: const ValueKey<String>('preview_overdue'),
            label: 'Overdue',
            value: p.overdueAmount,
            valueKind: p.hasOverdue ? StatusKind.overdue : null,
            caption: p.hasOverdue
                ? '$n ${n == 1 ? 'installment' : 'installments'} · '
                      'highest ${p.maxDaysOverdue} days late'
                : 'Nothing overdue',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Maturity ${formatCivilDate(p.maturityDate)} · '
            '${p.cyclesPaid}/${p.cyclesTotal} cycles paid',
            key: const ValueKey<String>('preview_maturity'),
            style: AppTextStyles.bodyMdTabular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (p.hasOverdue) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            const Row(
              children: <Widget>[
                Icon(
                  Icons.warning_amber_rounded,
                  size: AppSizes.iconSm,
                  color: AppColors.overdue,
                ),
                SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Overdue rows count in the Overdue tracker from today.',
                    style: AppTextStyles.bodySm,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ProjectedSchedulePreview(rows: p.rows),
          const SizedBox(height: AppSpacing.md),
          const LedgerBanner(
            key: ValueKey<String>('preview_extension_note'),
            text:
                'Unpaid past installments show as overdue and are added to '
                'the end of the schedule.',
            kind: StatusKind.info,
            icon: Icons.info_outline,
          ),
        ],
      ),
    );
  }
}
