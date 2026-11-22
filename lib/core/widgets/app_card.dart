import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppCardPadding { compact, spacious }

/// White card, 1px border, radius 16, no elevation. With [onTap] it shows
/// the `pressed` tint while held.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = AppCardPadding.compact,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final AppCardPadding padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final insets = switch (padding) {
      AppCardPadding.compact => AppInsets.cardCompact,
      AppCardPadding.spacious => AppInsets.cardSpacious,
    };
    final content = Padding(padding: insets, child: child);
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: Material(
        color: AppColors.surface,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.border),
          borderRadius: AppRadii.lgAll,
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                highlightColor: AppColors.pressed,
                splashColor: AppColors.track,
                child: content,
              ),
      ),
    );
  }
}
