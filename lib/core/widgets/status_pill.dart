import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Semantic status for pills, KPI values and icons.
enum StatusKind {
  collected,
  upcoming,
  overdue,
  neutral,
  info;

  Color get foreground => switch (this) {
    StatusKind.collected => AppColors.collected,
    StatusKind.upcoming => AppColors.upcoming,
    StatusKind.overdue => AppColors.overdue,
    StatusKind.neutral => AppColors.textSecondary,
    StatusKind.info => AppColors.primary,
  };

  Color get tint => switch (this) {
    StatusKind.collected => AppColors.collectedTint,
    StatusKind.upcoming => AppColors.upcomingTint,
    StatusKind.overdue => AppColors.overdueTint,
    StatusKind.neutral => AppColors.track,
    StatusKind.info => AppColors.primarySubtle,
  };
}

/// Full-radius status pill: tint background, status-coloured label, and a
/// leading dot or [icon]. Colour is never the only signal (label required).
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.kind,
    this.icon,
    super.key,
  });

  final String label;
  final StatusKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = kind.foreground;
    final leading = icon == null
        ? Container(
            key: const ValueKey<String>('status_pill_dot'),
            width: AppSizes.statusDot,
            height: AppSizes.statusDot,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          )
        : Icon(icon, size: AppSizes.iconSm, color: fg);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.pillHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kind.tint,
          borderRadius: AppRadii.fullAll,
        ),
        child: Padding(
          padding: AppInsets.pill,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              leading,
              const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMdStrongTabular.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
