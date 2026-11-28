import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A labelled Settings section: a sentence-case label over one bordered card
/// whose rows are separated by 1px dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    required this.title,
    required this.children,
    this.footer,
    super.key,
  });

  final String title;
  final List<Widget> children;

  /// Optional note under the card.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(height: AppSizes.borderWidth));
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppTextStyles.labelMdStrong.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          Material(
            color: AppColors.surface,
            shape: const RoundedRectangleBorder(
              side: BorderSide(color: AppColors.border),
              borderRadius: AppRadii.lgAll,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                top: AppSpacing.sm,
              ),
              child: Text(
                footer!,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
