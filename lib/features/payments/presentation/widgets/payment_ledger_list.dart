import 'package:flutter/material.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/ledger/tx_order.dart';
import '../../../../domain/models/models.dart';
import '../../../contracts/application/loan_label.dart';

/// The contract's money ledger, newest first: payments (reversed ones
/// struck through with "Reversed" and the reason), rollover settlement and
/// disbursement, plus early-closure waivers ("Waived ₹W · reason",
/// neutral, not cash). Owners get a "Reverse" action on live payments and
/// waivers.
class PaymentLedgerList extends StatelessWidget {
  const PaymentLedgerList({
    required this.transactions,
    required this.canReverse,
    required this.onReverse,
    super.key,
  });

  final List<LedgerTransaction> transactions;

  /// Owner only (the rules enforce it too).
  final bool canReverse;
  final ValueChanged<LedgerTransaction> onReverse;

  @override
  Widget build(BuildContext context) {
    final reversals = <String, LedgerTransaction>{
      for (final t in transactions)
        if (t.type == TxType.reversal && t.reversesTxId != null)
          t.reversesTxId!: t,
    };
    final shown =
        transactions
            .where(
              (LedgerTransaction t) =>
                  t.type == TxType.payment ||
                  t.type == TxType.rolloverSettlement ||
                  t.type == TxType.waiver ||
                  t.type == TxType.disbursement,
            )
            .toList()
          // Newest first: the waiver of a close shows above its cash payment.
          ..sort(
            (LedgerTransaction a, LedgerTransaction b) =>
                compareTxChronological(b, a),
          );
    return Column(
      key: const ValueKey<String>('payment_ledger'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: AppInsets.sectionHeader,
          child: Text('Ledger', style: AppTextStyles.headlineSm),
        ),
        if (shown.isEmpty)
          Text(
            'No payments yet.',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        for (final t in shown) ...<Widget>[
          _row(t, reversals[t.id]),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _row(LedgerTransaction t, LedgerTransaction? reversal) {
    final reversed = reversal != null;
    final isWaiver = t.type == TxType.waiver;
    final reason = t.note;
    final title = switch (t.type) {
      TxType.payment => onboardingPaymentLabel(t) ?? 'Payment',
      TxType.rolloverSettlement => 'Rollover settlement',
      TxType.disbursement => 'Disbursed',
      TxType.waiver => <String>[
        'Waived ${formatInr(t.amount)}',
        if (reason != null && reason.isNotEmpty) reason,
      ].join(' · '),
      TxType.reversal || TxType.reschedule => '',
    };
    final mode = t.mode;
    final reference = t.reference;
    final meta = <String>[
      formatCivilDate(t.paidOn),
      if (mode != null) paymentModeLabel(mode),
      if (reference != null && reference.isNotEmpty) reference,
      if (t.recordedByName.isNotEmpty) t.recordedByName,
    ].join(' · ');
    const muted = AppColors.textSecondary;
    return AppCard(
      key: ValueKey<String>('ledger_tx_${t.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      key: isWaiver
                          ? ValueKey<String>('ledger_waiver_${t.id}')
                          : null,
                      style: isWaiver
                          ? AppTextStyles.titleMdTabular.copyWith(
                              color: AppColors.textSecondary,
                              decoration: reversed
                                  ? TextDecoration.lineThrough
                                  : null,
                            )
                          : AppTextStyles.titleMd,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(meta, style: AppTextStyles.bodySmTabular),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              MoneyText(
                t.amount,
                key: ValueKey<String>('ledger_amount_${t.id}'),
                color: reversed
                    ? muted
                    : t.type == TxType.payment
                    ? AppColors.collected
                    : isWaiver
                    ? muted
                    : null,
                style: reversed
                    ? AppTextStyles.currencyItem.copyWith(
                        decoration: TextDecoration.lineThrough,
                      )
                    : null,
              ),
            ],
          ),
          if (reversed) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                StatusPill(
                  key: ValueKey<String>('reversed_${t.id}'),
                  label: 'Reversed',
                  kind: StatusKind.neutral,
                  icon: Icons.undo,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    reversal.note ?? '',
                    style: AppTextStyles.bodySm,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ] else if (canReverse && (t.type == TxType.payment || isWaiver))
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                key: ValueKey<String>('reverse_${t.id}'),
                onPressed: () => onReverse(t),
                icon: const Icon(Icons.undo, size: AppSizes.iconSm),
                label: const Text('Reverse'),
                style: TextButton.styleFrom(foregroundColor: AppColors.overdue),
              ),
            ),
        ],
      ),
    );
  }
}
