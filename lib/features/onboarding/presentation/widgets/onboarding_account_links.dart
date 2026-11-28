import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';

/// Privacy · Terms · Delete account, at the end of the onboarding screens.
/// A signed-in user without a company must still be able to delete their
/// account (Google Play account-deletion policy).
class OnboardingAccountLinks extends StatelessWidget {
  const OnboardingAccountLinks({super.key});

  @override
  Widget build(BuildContext context) {
    Widget link(String key, String label, String route, {Color? color}) =>
        TextButton(
          key: ValueKey<String>(key),
          style: TextButton.styleFrom(
            foregroundColor: color,
            textStyle: AppTextStyles.labelMd,
          ),
          onPressed: () => unawaited(context.push<void>(route)),
          child: Text(label),
        );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.xs,
        children: <Widget>[
          link('onboarding_privacy', 'Privacy', AppRoutes.privacy),
          link('onboarding_terms', 'Terms', AppRoutes.terms),
          link(
            'onboarding_delete_account',
            'Delete account',
            AppRoutes.deleteAccount,
            color: AppColors.overdue,
          ),
        ],
      ),
    );
  }
}
