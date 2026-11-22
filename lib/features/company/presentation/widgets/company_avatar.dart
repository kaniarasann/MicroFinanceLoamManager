import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Up to two initials of [name]: "Sri Lakshmi Finance" → "SL".
String companyInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  final first = words.first.substring(0, 1);
  final second = words.length > 1 ? words[1].substring(0, 1) : '';
  return (first + second).toUpperCase();
}

/// Rounded navy-tint tile with the company's initials.
class CompanyAvatar extends StatelessWidget {
  const CompanyAvatar({
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
          borderRadius: AppRadii.mdAll,
        ),
        child: Text(
          companyInitials(name),
          style: AppTextStyles.labelLg.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}
