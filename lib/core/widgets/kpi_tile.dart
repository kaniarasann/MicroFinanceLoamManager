import 'package:flutter/material.dart';

import '../money/money.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import 'money_text.dart';
import 'status_pill.dart';

/// Dashboard KPI: label, large tabular amount, optional caption.
class KpiTile extends StatelessWidget {
  const KpiTile({
    required this.label,
    required this.value,
    this.caption,
    this.valueKind,
    this.onTap,
    super.key,
  });

  final String label;
  final Money value;
  final String? caption;

  /// Colours the value (e.g. collected / overdue). Null = textPrimary.
  final StatusKind? valueKind;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: MoneyText(
              value,
              style: AppTextStyles.headlineLgTabular,
              color: valueKind?.foreground ?? AppColors.textPrimary,
            ),
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              caption!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmTabular,
            ),
          ],
        ],
      ),
    );
  }
}
