import 'package:flutter/material.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../../domain/models/models.dart';
import '../../../contracts/application/loan_label.dart';

/// One ledger line: type, loan, date, mode chip, signed amount and the
/// contract balance after it ("Bal ₹X").
class LedgerEntryTile extends StatelessWidget {
  const LedgerEntryTile({required this.entry, super.key});

  final LedgerEntry entry;

  static String typeLabel(TxType t) => switch (t) {
    TxType.disbursement => 'Disbursed',
    TxType.payment => 'Payment',
    TxType.rolloverSettlement => 'Rollover settlement',
    TxType.reversal => 'Reversal',
    TxType.reschedule => 'Reschedule',
    TxType.waiver => 'Waived',
  };

  static String sign(TxType t) => switch (t) {
    TxType.payment || TxType.rolloverSettlement => '+',
    TxType.reversal => '−',
    TxType.disbursement || TxType.reschedule || TxType.waiver => '',
  };

  static Color color(TxType t) => switch (t) {
    TxType.payment || TxType.rolloverSettlement => AppColors.collected,
    TxType.reversal => AppColors.overdue,
    TxType.disbursement || TxType.reschedule => AppColors.textPrimary,
    // Not cash: neutral, never the sage 'collected' colour.
    TxType.waiver => AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final tx = entry.tx;
    final mode = tx.mode;
    final balance = entry.balanceAfter;
    return Padding(
      key: ValueKey<String>('ledger_${tx.id}'),
      padding: AppInsets.listRow,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${onboardingPaymentLabel(tx) ?? typeLabel(tx.type)} · '
                  '${loanLabel(tx.loanNo)}',
                  style: AppTextStyles.titleMdTabular,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      formatCivilDate(tx.paidOn),
                      style: AppTextStyles.bodySmTabular,
                    ),
                    if (mode != null)
                      StatusPill(
                        label: paymentModeLabel(mode),
                        kind: StatusKind.neutral,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${sign(tx.type)}${formatInr(tx.amount)}',
                style: AppTextStyles.currencyItem.copyWith(
                  color: color(tx.type),
                ),
              ),
              if (balance != null)
                Text(
                  'Bal ${formatInr(balance)}',
                  style: AppTextStyles.bodySmTabular,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
