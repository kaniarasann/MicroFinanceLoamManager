import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Inline terracotta error line with an icon (colour is never the only
/// signal). Announced to screen readers.
class InlineError extends StatelessWidget {
  const InlineError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.error_outline,
            size: AppSizes.iconSm,
            color: AppColors.overdue,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              message,
              key: const ValueKey<String>('inline_error'),
              style: AppTextStyles.bodyMdTabular.copyWith(
                color: AppColors.overdue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
