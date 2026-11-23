import 'package:flutter/material.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../contracts/application/loan_label.dart';
import '../../../contracts/presentation/widgets/ledger_banner.dart';

/// New sanctioned − upfront − old outstanding = Net cash handover. Shows
/// the invalid state when the new loan does not cover the old balance and
/// the upfront interest.
class RolloverSettlementCard extends StatelessWidget {
  const RolloverSettlementCard({
    required this.newSanctioned,
    required this.upfront,
    required this.oldOutstanding,
    required this.oldLoanNo,
    this.error,
    super.key,
  });

  final Money newSanctioned;
  final Money upfront;
  final Money oldOutstanding;
  final int oldLoanNo;

  /// The quote's error, when the rollover is not valid.
  final String? error;

  Money get netCash => newSanctioned - upfront - oldOutstanding;

  String get _invalidText {
    const head = 'New loan must cover the old balance and upfront interest.';
    final detail = error;
    return detail == null ? head : '$head $detail';
  }

  @override
  Widget build(BuildContext context) {
    final label = AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary);
    final net = netCash;
    final invalid = net.isNegative;
    Widget minusRow(String text, Money value, String key) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(text, style: label)),
          Text(
            minusSign,
            style: AppTextStyles.currencyItem.copyWith(
              color: AppColors.overdue,
            ),
          ),
          MoneyText(
            value,
            key: ValueKey<String>(key),
            color: AppColors.overdue,
          ),
        ],
      ),
    );
    return AppCard(
      key: const ValueKey<String>('settlement_card'),
      padding: AppCardPadding.spacious,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('New sanctioned', style: label)),
              MoneyText(
                newSanctioned,
                key: const ValueKey<String>('settle_sanctioned'),
              ),
            ],
          ),
          minusRow('Upfront interest', upfront, 'settle_upfront'),
          minusRow(
            'Settles ${loanLabel(oldLoanNo)} outstanding',
            oldOutstanding,
            'settle_old',
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Net cash handover',
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: MoneyText(
              net,
              key: const ValueKey<String>('settle_net'),
              style: AppTextStyles.currencyDisplay,
              color: invalid ? AppColors.overdue : null,
            ),
          ),
          if (invalid || error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            LedgerBanner(
              key: const ValueKey<String>('settle_invalid'),
              text: invalid ? _invalidText : error!,
              kind: StatusKind.overdue,
              icon: Icons.warning_amber_rounded,
            ),
          ],
        ],
      ),
    );
  }
}
