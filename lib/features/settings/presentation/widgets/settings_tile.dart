import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// One Settings row: an icon badge, a title with optional subtitle and a
/// trailing widget (chevron by default when tappable). At least 56dp tall;
/// wraps at large text scales instead of overflowing.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron = true,
    this.titleStyle,
    this.tabularSubtitle = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Terracotta title and badge (delete account).
  final bool destructive;

  /// Chevron after [trailing] when [onTap] is set.
  final bool showChevron;

  /// Overrides the title style (e.g. tabular figures).
  final TextStyle? titleStyle;

  /// Subtitle with tabular figures (versions, counts).
  final bool tabularSubtitle;

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? AppColors.overdue : AppColors.primary;
    final bg = destructive ? AppColors.overdueTint : AppColors.primarySubtle;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.inputHeight),
      child: Padding(
        padding: AppInsets.listRow,
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: Container(
                width: AppSizes.avatarMd,
                height: AppSizes.avatarMd,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: AppRadii.mdAll,
                ),
                child: Icon(icon, color: fg, size: AppSizes.iconMd),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style:
                        titleStyle ??
                        AppTextStyles.titleMd.copyWith(
                          color: destructive
                              ? AppColors.overdue
                              : AppColors.textPrimary,
                        ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style:
                          (tabularSubtitle
                                  ? AppTextStyles.bodyMdTabular
                                  : AppTextStyles.bodyMd)
                              .copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
            if (onTap != null && showChevron) ...<Widget>[
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right,
                color: destructive
                    ? AppColors.overdue
                    : AppColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      highlightColor: AppColors.pressed,
      splashColor: AppColors.track,
      child: content,
    );
  }
}
