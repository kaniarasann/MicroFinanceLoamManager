import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/status_pill.dart';

/// A tinted full-width banner with an icon and text: overdue (terracotta
/// tint), excess (amber tint) or an info note (primarySubtle).
class LedgerBanner extends StatelessWidget {
  const LedgerBanner({
    required this.text,
    required this.kind,
    required this.icon,
    super.key,
  });

  final String text;
  final StatusKind kind;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fg = kind == StatusKind.info
        ? AppColors.textPrimary
        : kind.foreground;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kind.tint,
        borderRadius: AppRadii.mdAll,
        border: kind == StatusKind.overdue
            ? const Border.fromBorderSide(
                BorderSide(color: AppColors.overdueBorder),
              )
            : null,
      ),
      child: Padding(
        padding: AppInsets.cardCompact,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: AppSizes.iconMd, color: kind.foreground),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.bodyMdTabular.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
