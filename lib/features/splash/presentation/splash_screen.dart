import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';

/// In-app splash, shown while the session stage is `loading` (auth state,
/// MPIN lookup and the Firestore cache initialise).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const BrandMark(size: AppSizes.brandTileLg),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Nordic Ledger',
                  style: AppTextStyles.headlineXl,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Calm, accurate lending books',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                const SizedBox(
                  width: AppSizes.splashProgressWidth,
                  child: ClipRRect(
                    borderRadius: AppRadii.fullAll,
                    child: LinearProgressIndicator(
                      minHeight: AppSizes.progressBarHeight,
                      color: AppColors.collected,
                      backgroundColor: AppColors.track,
                      semanticsLabel: 'Syncing your ledger',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Syncing your ledger…',
                  style: AppTextStyles.bodySm,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
