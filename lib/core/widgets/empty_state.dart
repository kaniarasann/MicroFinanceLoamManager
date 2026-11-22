import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Centered icon, title, message and optional action for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppInsets.emptyState,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: AppSizes.emptyStateBadge,
              height: AppSizes.emptyStateBadge,
              decoration: const BoxDecoration(
                color: AppColors.primarySubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: AppSizes.iconLg,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTextStyles.titleMd,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
