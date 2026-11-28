import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A Settings row with a switch. The whole row toggles; [extra] (e.g. the
/// digest time chip) sits under the subtitle.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.extra,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;

  /// Null disables the row.
  final ValueChanged<bool>? onChanged;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final textColor = enabled ? AppColors.textPrimary : AppColors.textTertiary;
    return InkWell(
      onTap: enabled ? () => onChanged!(!value) : null,
      highlightColor: AppColors.pressed,
      splashColor: AppColors.track,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.inputHeight),
        child: Padding(
          padding: AppInsets.listRow,
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                ExcludeSemantics(
                  child: Container(
                    width: AppSizes.avatarMd,
                    height: AppSizes.avatarMd,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: AppRadii.mdAll,
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.primary,
                      size: AppSizes.iconMd,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppTextStyles.titleMd.copyWith(color: textColor),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    if (extra != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      extra!,
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Semantics(
                label: title,
                child: Switch(value: value, onChanged: onChanged),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
