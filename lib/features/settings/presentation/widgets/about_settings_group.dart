import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/settings_providers.dart';
import 'settings_group.dart';
import 'settings_tile.dart';

/// About: privacy policy, terms of service and the app version.
class AboutSettingsGroup extends ConsumerWidget {
  const AboutSettingsGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).value ?? '';
    return SettingsGroup(
      title: 'About',
      children: <Widget>[
        SettingsTile(
          key: const ValueKey<String>('settings_privacy'),
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy policy',
          onTap: () => unawaited(context.push<void>(AppRoutes.privacy)),
        ),
        SettingsTile(
          key: const ValueKey<String>('settings_terms'),
          icon: Icons.gavel_outlined,
          title: 'Terms of service',
          onTap: () => unawaited(context.push<void>(AppRoutes.terms)),
        ),
        SettingsTile(
          key: const ValueKey<String>('settings_version'),
          icon: Icons.info_outline,
          title: 'Nordic Ledger',
          subtitle: version.isEmpty ? null : 'Version $version',
          tabularSubtitle: true,
          titleStyle: AppTextStyles.titleMd,
        ),
      ],
    );
  }
}
