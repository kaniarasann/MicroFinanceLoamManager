import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/phone/indian_phone.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/application/session_controller.dart';
import '../../../company/application/company_providers.dart';
import '../../../company/presentation/widgets/member_avatar.dart';
import '../../../company/presentation/widgets/role_pill.dart';

/// Settings profile: initials avatar, name + role pill, phone (from the
/// member doc) and the Google account email.
class ProfileCard extends ConsumerWidget {
  const ProfileCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(
      sessionControllerProvider.select((SessionState s) => s.user),
    );
    final member = ref.watch(currentMemberProvider);
    final role = ref.watch(currentRoleProvider);
    final name = (member?.displayName.trim().isNotEmpty ?? false)
        ? member!.displayName
        : (user?.displayName ?? 'You');
    final phone = member?.phoneE164;
    final email = user?.email;

    return AppCard(
      key: const ValueKey<String>('settings_profile'),
      child: Row(
        children: <Widget>[
          MemberAvatar(name: name, size: AppSizes.avatarLg),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(name, style: AppTextStyles.headlineSm),
                    if (role != null) RolePill(role: role),
                  ],
                ),
                if (phone != null && phone.isNotEmpty)
                  Text(
                    IndianPhone.format(phone),
                    key: const ValueKey<String>('settings_phone'),
                    style: AppTextStyles.bodyMdTabular.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (email != null && email.isNotEmpty)
                  Text(
                    email,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
