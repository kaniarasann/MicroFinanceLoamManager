import 'package:flutter/material.dart';

import '../../../../core/phone/indian_phone.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../company/presentation/widgets/member_avatar.dart';
import '../../application/borrower_providers.dart';
import 'standing_pill.dart';

/// One borrower in the list: initials avatar, name, phone, active-loan
/// count, outstanding ₹ and a status pill. [selected] (tablet split view)
/// draws a navy 1px border on the pressed tint.
class BorrowerRow extends StatelessWidget {
  const BorrowerRow({
    required this.item,
    required this.onTap,
    this.selected = false,
    super.key,
  });

  final BorrowerListItem item;
  final VoidCallback onTap;
  final bool selected;

  static String loansLabel(int n) => switch (n) {
    0 => 'No active loans',
    1 => '1 active loan',
    _ => '$n active loans',
  };

  @override
  Widget build(BuildContext context) {
    final b = item.borrower;
    final s = item.stats;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.pressed : AppColors.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: AppSizes.borderWidth,
          ),
          borderRadius: AppRadii.lgAll,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          highlightColor: AppColors.pressed,
          splashColor: AppColors.track,
          child: Padding(
            padding: AppInsets.cardCompact,
            child: Row(
              children: <Widget>[
                MemberAvatar(name: b.name),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        b.name,
                        style: AppTextStyles.titleMd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        IndianPhone.format(b.phoneE164),
                        style: AppTextStyles.bodySmTabular,
                        maxLines: 1,
                      ),
                      Text(
                        loansLabel(s.activeCount),
                        style: AppTextStyles.bodySmTabular,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      if (s.activeCount > 0)
                        MoneyText(s.outstanding, textAlign: TextAlign.end),
                      const SizedBox(height: AppSpacing.xs),
                      StandingPill(
                        standing: s.standing,
                        daysOverdue: s.maxDaysOverdue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
