import 'package:flutter/material.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/about_settings_group.dart';
import '../widgets/account_settings_group.dart';
import '../widgets/company_settings_group.dart';
import '../widgets/notification_settings_group.dart';
import '../widgets/profile_card.dart';
import '../widgets/security_settings_group.dart';
import '../widgets/sync_status_card.dart';

/// The Settings destination (Stitch "10. Settings"): profile, sync status,
/// company, collection notifications, security, about and account.
///
/// One column on phones; on expanded windows two columns (profile, company
/// and notifications | security, about and account).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = WindowSize.of(context);
    const gap = SizedBox(height: AppSpacing.md);
    final title = Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        header: true,
        child: const Text('Settings', style: AppTextStyles.headlineXl),
      ),
    );
    const left = <Widget>[
      ProfileCard(),
      gap,
      SyncStatusCard(),
      SizedBox(height: AppSpacing.lg),
      CompanySettingsGroup(),
      NotificationSettingsGroup(),
    ];
    const right = <Widget>[
      SecuritySettingsGroup(),
      AboutSettingsGroup(),
      AccountSettingsGroup(),
    ];

    return SingleChildScrollView(
      key: const ValueKey<String>('settings'),
      padding: AppInsets.pageBody,
      child: size.isExpanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                title,
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: left,
                      ),
                    ),
                    SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: right,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[title, ...left, ...right],
            ),
    );
  }
}
