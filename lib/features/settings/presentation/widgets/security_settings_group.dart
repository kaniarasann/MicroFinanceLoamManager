import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/adaptive_sheet.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../auth/application/session_controller.dart';
import '../../application/settings_providers.dart';
import 'settings_group.dart';
import 'settings_switch_tile.dart';
import 'settings_tile.dart';

/// Security: change MPIN, biometric unlock, auto-lock delay. All
/// device-local (secure storage), never in Firestore.
class SecuritySettingsGroup extends ConsumerWidget {
  const SecuritySettingsGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biometric = ref.watch(
      sessionControllerProvider.select((SessionState s) => s.biometricEnabled),
    );
    final available = ref.watch(biometricAvailableProvider).value ?? false;
    final minutes =
        ref.watch(autoLockMinutesProvider).value ??
        AppConfig.defaultAutoLockMinutes;

    Future<void> toggleBiometric(bool on) async {
      final now = await ref
          .read(sessionControllerProvider.notifier)
          .setBiometricEnabled(enabled: on);
      if (!context.mounted || now == on) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Fingerprint wasn't confirmed. Biometric unlock is off.",
          ),
        ),
      );
    }

    return SettingsGroup(
      title: 'Security',
      children: <Widget>[
        SettingsTile(
          key: const ValueKey<String>('settings_change_mpin'),
          icon: Icons.pin_outlined,
          title: 'Change MPIN',
          subtitle: '4-digit PIN that unlocks the app on this phone',
          onTap: () => unawaited(context.push<void>(AppRoutes.changeMpin)),
        ),
        SettingsSwitchTile(
          key: const ValueKey<String>('settings_biometric'),
          icon: Icons.fingerprint,
          title: 'Biometric unlock',
          subtitle: available
              ? 'Unlock with your fingerprint or face'
              : 'Not set up on this phone',
          value: biometric && available,
          onChanged: available
              ? (bool v) => unawaited(toggleBiometric(v))
              : null,
        ),
        SettingsTile(
          key: const ValueKey<String>('settings_autolock'),
          icon: Icons.timer_outlined,
          title: 'Auto-lock',
          subtitle: 'Ask for the MPIN after the app has been in the background',
          trailing: StatusPill(
            label: autoLockLabel(minutes),
            kind: StatusKind.info,
          ),
          onTap: () => unawaited(_pickAutoLock(context, ref, minutes)),
        ),
      ],
    );
  }

  static Future<void> _pickAutoLock(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final picked = await showAdaptiveSheet<int>(
      context,
      (BuildContext sheet) => RadioGroup<int>(
        groupValue: current,
        onChanged: (int? v) => Navigator.of(sheet).pop(v),
        child: Column(
          key: const ValueKey<String>('autolock_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Auto-lock', style: AppTextStyles.headlineSm),
            const SizedBox(height: AppSpacing.sm),
            for (final m in autoLockChoices)
              RadioListTile<int>(
                key: ValueKey<String>('autolock_$m'),
                contentPadding: EdgeInsets.zero,
                value: m,
                title: Text(
                  autoLockLabel(m),
                  style: AppTextStyles.bodyLgTabular,
                ),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    await ref.read(settingsActionsProvider).setAutoLockMinutes(picked);
  }
}
