import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/application/session_controller.dart';

/// "Signed in as {name} · {email}" with a Switch action (signs out so the
/// user can pick another Google account).
class AccountChip extends ConsumerWidget {
  const AccountChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(
      sessionControllerProvider.select((SessionState s) => s.user),
    );
    final name = user?.displayName?.trim();
    final email = user?.email ?? '';
    final title = (name == null || name.isEmpty) ? email : name;
    final initial = title.isEmpty ? '?' : title.substring(0, 1).toUpperCase();

    return Container(
      key: const ValueKey<String>('account_chip'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.fullAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: AppSizes.avatarSm,
            height: AppSizes.avatarSm,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: AppTextStyles.labelLg.copyWith(color: AppColors.onPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Signed in as',
                  style: AppTextStyles.bodySm,
                  maxLines: 1,
                ),
                Text(
                  email.isEmpty || email == title ? title : '$title · $email',
                  style: AppTextStyles.labelLg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey<String>('account_switch'),
            onPressed: () => unawaited(
              ref.read(sessionControllerProvider.notifier).signOut(),
            ),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
  }
}
