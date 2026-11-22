import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'company_avatar.dart' show companyInitials;

/// Round initials avatar for a member or invitee row.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    required this.name,
    this.size = AppSizes.avatarMd,
    super.key,
  });

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.primarySubtle,
          shape: BoxShape.circle,
        ),
        child: Text(
          companyInitials(name),
          style: AppTextStyles.labelLg.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}
