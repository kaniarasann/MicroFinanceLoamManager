import 'package:flutter/material.dart';

import '../../../../core/phone/indian_phone.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../domain/models/models.dart';
import '../../data/members_repository.dart';
import 'member_avatar.dart';
import 'role_pill.dart';

/// Kebab-menu actions on a member row.
enum MemberAction { makeOwner, makeCollector, remove }

/// One member: initials, name (+ "You"), phone, role pill and, for owners,
/// a kebab menu with Make owner / Make collector / Remove. The last owner's
/// demote / remove items are disabled with [LastOwnerGuard.message].
class MemberTile extends StatelessWidget {
  const MemberTile({
    required this.member,
    required this.isSelf,
    required this.canManage,
    required this.isLastOwner,
    required this.onAction,
    this.busy = false,
    super.key,
  });

  final Member member;
  final bool isSelf;

  /// The viewer is an owner (collectors see the list read-only).
  final bool canManage;
  final bool isLastOwner;
  final ValueChanged<MemberAction> onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final phone = member.phoneE164;
    return AppCard(
      key: ValueKey<String>('member_${member.uid}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              MemberAvatar(name: member.displayName),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Wraps (name, "You", role pill) instead of overflowing
                    // on narrow windows with large text.
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          member.displayName,
                          style: AppTextStyles.titleMd,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isSelf) const _YouTag(),
                        RolePill(role: member.role),
                      ],
                    ),
                    if (phone != null && phone.isNotEmpty)
                      Text(
                        IndianPhone.format(phone),
                        style: AppTextStyles.bodyMdTabular.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (canManage)
                busy
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: SizedBox.square(
                          dimension: AppSizes.iconSm,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _MemberMenu(
                        member: member,
                        isLastOwner: isLastOwner,
                        onAction: onAction,
                      ),
            ],
          ),
          if (canManage && isLastOwner) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              key: ValueKey<String>('last_owner_note_${member.uid}'),
              children: <Widget>[
                const Icon(
                  Icons.lock_outline,
                  size: AppSizes.iconSm,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                const Expanded(
                  child: Text(
                    '${LastOwnerGuard.message}. Make someone else an owner '
                    'first.',
                    style: AppTextStyles.bodySm,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _YouTag extends StatelessWidget {
  const _YouTag();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.track,
        borderRadius: AppRadii.smAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs + AppSpacing.xxs,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          'You',
          style: AppTextStyles.labelMd.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _MemberMenu extends StatelessWidget {
  const _MemberMenu({
    required this.member,
    required this.isLastOwner,
    required this.onAction,
  });

  final Member member;
  final bool isLastOwner;
  final ValueChanged<MemberAction> onAction;

  @override
  Widget build(BuildContext context) {
    final isOwner = member.role == Role.owner;
    return PopupMenuButton<MemberAction>(
      key: ValueKey<String>('member_menu_${member.uid}'),
      tooltip: 'Member actions',
      icon: const Icon(Icons.more_vert),
      onSelected: onAction,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<MemberAction>>[
        if (!isOwner)
          const PopupMenuItem<MemberAction>(
            value: MemberAction.makeOwner,
            child: Text('Make owner'),
          ),
        if (isOwner)
          PopupMenuItem<MemberAction>(
            key: const ValueKey<String>('menu_make_collector'),
            value: MemberAction.makeCollector,
            enabled: !isLastOwner,
            child: const Text('Make collector'),
          ),
        PopupMenuItem<MemberAction>(
          key: const ValueKey<String>('menu_remove'),
          value: MemberAction.remove,
          enabled: !isLastOwner,
          child: Text(
            isLastOwner ? LastOwnerGuard.message : 'Remove',
            style: AppTextStyles.bodyMd.copyWith(
              color: isLastOwner ? AppColors.textTertiary : AppColors.overdue,
            ),
          ),
        ),
      ],
    );
  }
}
