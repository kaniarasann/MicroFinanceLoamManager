import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/enums.dart';
import '../../../contracts/application/loan_label.dart';

/// Three selectable cards: UPI / Cash / Bank. The selected card has a navy
/// border on the selected tint and a check icon (colour is never the only
/// signal).
class PaymentModeSelector extends StatelessWidget {
  const PaymentModeSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final PaymentMode selected;
  final ValueChanged<PaymentMode> onChanged;

  static IconData _icon(PaymentMode m) => switch (m) {
    PaymentMode.upi => Icons.qr_code_2,
    PaymentMode.cash => Icons.payments_outlined,
    PaymentMode.bank => Icons.account_balance_outlined,
  };

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      for (final m in PaymentMode.values) ...<Widget>[
        if (m != PaymentMode.values.first) const SizedBox(width: AppSpacing.sm),
        Expanded(child: _card(m)),
      ],
    ],
  );

  Widget _card(PaymentMode m) {
    final on = m == selected;
    return Semantics(
      selected: on,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: on ? AppColors.primarySubtle : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdAll,
          side: BorderSide(
            color: on ? AppColors.primary : AppColors.border,
            width: AppSizes.borderWidth,
          ),
        ),
        child: InkWell(
          key: ValueKey<String>('mode_${m.name}'),
          customBorder: const RoundedRectangleBorder(
            borderRadius: AppRadii.mdAll,
          ),
          onTap: () => onChanged(m),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.inputHeight),
            child: Padding(
              padding: AppInsets.listRow,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    on ? Icons.check_circle : _icon(m),
                    size: AppSizes.iconMd,
                    color: on ? AppColors.primary : AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    paymentModeLabel(m),
                    style: AppTextStyles.labelLg.copyWith(
                      color: on ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
