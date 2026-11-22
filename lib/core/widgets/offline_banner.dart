import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Amber-tint strip shown while offline. Text stays textPrimary for
/// contrast; the amber icon carries the status colour.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    this.message = 'Offline · changes will sync',
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: ColoredBox(
        color: AppColors.upcomingTint,
        child: Padding(
          padding: AppInsets.banner,
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.cloud_off_outlined,
                size: AppSizes.iconSm,
                color: AppColors.upcoming,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(message, style: AppTextStyles.labelMdStrong),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
