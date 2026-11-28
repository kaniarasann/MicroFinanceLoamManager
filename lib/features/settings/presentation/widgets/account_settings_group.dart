import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../application/settings_providers.dart';
import 'settings_group.dart';
import 'settings_tile.dart';

/// Account: sign out (with confirmation) and delete account (terracotta).
class AccountSettingsGroup extends ConsumerWidget {
  const AccountSettingsGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> signOut() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext d) => AlertDialog(
          key: const ValueKey<String>('sign_out_dialog'),
          title: const Text('Sign out?'),
          content: const Text(
            'Reminders on this phone stop until you sign in again. Your MPIN '
            'stays on this phone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey<String>('sign_out_confirm'),
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
      if (ok ?? false) await ref.read(settingsActionsProvider).signOut();
    }

    return SettingsGroup(
      title: 'Account',
      children: <Widget>[
        SettingsTile(
          key: const ValueKey<String>('settings_sign_out'),
          icon: Icons.logout,
          title: 'Sign out',
          onTap: () => unawaited(signOut()),
        ),
        SettingsTile(
          key: const ValueKey<String>('settings_delete_account'),
          icon: Icons.delete_outline,
          title: 'Delete account & data',
          subtitle: 'A sole owner must make another member an owner first',
          destructive: true,
          onTap: () => unawaited(context.push<void>(AppRoutes.deleteAccount)),
        ),
      ],
    );
  }
}
