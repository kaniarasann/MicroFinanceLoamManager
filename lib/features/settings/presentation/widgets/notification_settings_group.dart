import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/ledger/notification_plan.dart';
import '../../../../domain/models/models.dart';
import '../../../notifications/application/notification_providers.dart';
import '../../application/settings_providers.dart';
import 'settings_group.dart';
import 'settings_switch_tile.dart';
import 'settings_tile.dart';

/// Collection notifications: daily digest (+ time), per-installment
/// reminders, overdue nudges. All are local notifications on this phone,
/// for the app user; borrowers are never messaged automatically.
class NotificationSettingsGroup extends ConsumerWidget {
  const NotificationSettingsGroup({super.key});

  static const String footnote =
      'Reminders are notifications on this phone, for you. Borrowers are '
      'never messaged automatically.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    final allowed = ref.watch(notificationsAllowedProvider).value ?? true;
    final time = DigestTime.parse(prefs.digestTime);

    Future<void> save(NotificationPrefs next) async {
      try {
        await ref.read(settingsActionsProvider).setNotificationPrefs(next);
      } on AppFailure catch (f) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(f.userMessage)));
      }
    }

    Future<void> pickTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
        helpText: 'Digest time (IST)',
      );
      if (picked == null) return;
      await save(
        prefs.copyWith(
          digestTime: DigestTime(picked.hour, picked.minute).stored,
        ),
      );
    }

    return SettingsGroup(
      title: 'Collection notifications',
      footer: footnote,
      children: <Widget>[
        if (!allowed)
          SettingsTile(
            key: const ValueKey<String>('notifications_blocked'),
            icon: Icons.notifications_off_outlined,
            title: 'Notifications are off',
            subtitle: 'Allow them to get collection reminders on this phone.',
            showChevron: false,
            trailing: TextButton(
              key: const ValueKey<String>('notifications_allow'),
              onPressed: () =>
                  unawaited(ref.read(notificationPermissionProvider).request()),
              child: const Text('Allow'),
            ),
          ),
        SettingsSwitchTile(
          key: const ValueKey<String>('notif_digest'),
          title: 'Daily collection digest',
          subtitle: "A morning summary of today's collections",
          value: prefs.digestEnabled,
          onChanged: (bool v) =>
              unawaited(save(prefs.copyWith(digestEnabled: v))),
          extra: _TimeChip(time: time, onTap: () => unawaited(pickTime())),
        ),
        SettingsSwitchTile(
          key: const ValueKey<String>('notif_installment'),
          title: 'Per-installment reminders',
          subtitle:
              'A reminder on this phone for each installment due, at the '
              'digest time',
          value: prefs.perInstallmentEnabled,
          onChanged: (bool v) =>
              unawaited(save(prefs.copyWith(perInstallmentEnabled: v))),
        ),
        SettingsSwitchTile(
          key: const ValueKey<String>('notif_overdue'),
          title: 'Overdue nudges',
          subtitle:
              'A daily reminder at the digest time while loans are '
              'overdue',
          value: prefs.overdueNudgeEnabled,
          onChanged: (bool v) =>
              unawaited(save(prefs.copyWith(overdueNudgeEnabled: v))),
        ),
      ],
    );
  }
}

/// "8:00 AM" chip that opens the time picker. Applies to every kind.
class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.time, required this.onTap});

  final DigestTime time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Notification time ${time.display}, change',
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey<String>('notif_time'),
        onTap: onTap,
        borderRadius: AppRadii.fullAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: Container(
              padding: AppInsets.pill,
              decoration: const BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: AppRadii.fullAll,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.schedule,
                    size: AppSizes.iconSm,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    time.display,
                    style: AppTextStyles.labelMdStrongTabular.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
