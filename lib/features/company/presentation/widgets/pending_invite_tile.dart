import 'package:flutter/material.dart';

import '../../../../core/phone/indian_phone.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../domain/models/models.dart';
import 'member_avatar.dart';
import 'role_pill.dart';

/// "Code K7Q2MD · expires in 6 days" / "expires today" / "expired".
String inviteExpiryLabel(Invite invite, DateTime now) {
  final left = invite.expiresAt.difference(now);
  if (left > Duration.zero) {
    final days = (left.inMinutes / Duration.minutesPerDay).ceil();
    final when = left < const Duration(days: 1)
        ? 'expires today'
        : 'expires in $days ${days == 1 ? 'day' : 'days'}';
    return 'Code ${invite.id} · $when';
  }
  return 'Code ${invite.id} · expired';
}

/// One pending invite: initials, name, phone, role pill, code + expiry,
/// Resend and a terracotta Revoke.
class PendingInviteTile extends StatelessWidget {
  const PendingInviteTile({
    required this.invite,
    required this.now,
    required this.onResend,
    required this.onRevoke,
    this.busy = false,
    super.key,
  });

  final Invite invite;
  final DateTime now;
  final VoidCallback onResend;
  final VoidCallback onRevoke;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final expired = invite.isExpired(now);
    return AppCard(
      key: ValueKey<String>('pending_invite_${invite.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              MemberAvatar(name: invite.inviteeName),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      invite.inviteeName,
                      style: AppTextStyles.titleMd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      IndianPhone.format(invite.inviteePhoneE164),
                      style: AppTextStyles.bodyMdTabular.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: <Widget>[
                        if (expired) ...<Widget>[
                          const Icon(
                            Icons.schedule_outlined,
                            size: AppSizes.iconSm,
                            color: AppColors.overdue,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        Expanded(
                          child: Text(
                            inviteExpiryLabel(invite, now),
                            style: AppTextStyles.bodySmTabular.copyWith(
                              color: expired
                                  ? AppColors.overdue
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              RolePill(role: invite.role),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton.icon(
                key: ValueKey<String>('invite_resend_${invite.id}'),
                onPressed: busy ? null : onResend,
                icon: const Icon(Icons.send_outlined, size: AppSizes.iconSm),
                label: Text(expired ? 'Resend new code' : 'Resend'),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton.icon(
                key: ValueKey<String>('invite_revoke_${invite.id}'),
                style: TextButton.styleFrom(foregroundColor: AppColors.overdue),
                onPressed: busy ? null : onRevoke,
                icon: const Icon(Icons.block_outlined, size: AppSizes.iconSm),
                label: const Text('Revoke'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
