import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// "Your MPIN stays on this device", optionally followed by Privacy / Terms
/// links.
class DeviceOnlyNote extends StatelessWidget {
  const DeviceOnlyNote({this.showLinks = false, super.key});

  final bool showLinks;

  @override
  Widget build(BuildContext context) {
    const muted = AppTextStyles.bodySm;
    // TODO(sprint-8): open the Privacy Policy and Terms pages.
    Widget link(String label) => TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        textStyle: AppTextStyles.labelMd,
      ),
      child: Text(label),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        const Icon(
          Icons.lock_outline,
          size: AppSizes.iconSm,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.xs),
        const Text('Your MPIN stays on this device', style: muted),
        if (showLinks) ...<Widget>[
          const Text(' · ', style: muted),
          link('Privacy'),
          const Text('·', style: muted),
          link('Terms'),
        ],
      ],
    );
  }
}
