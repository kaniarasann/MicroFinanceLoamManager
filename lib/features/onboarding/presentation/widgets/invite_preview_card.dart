import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../domain/models/enums.dart';
import '../../../company/presentation/widgets/company_avatar.dart';
import '../../../company/presentation/widgets/role_pill.dart';
import '../../data/invite_repository.dart';

/// One permission line: allowed (✓) or locked (🔒).
final class InvitePermission {
  const InvitePermission(this.label, {required this.allowed});

  final String label;
  final bool allowed;
}

/// What a role may do, as shown on the invite preview.
List<InvitePermission> invitePermissions(Role role) => switch (role) {
  Role.owner => const <InvitePermission>[
    InvitePermission('Full access', allowed: true),
    InvitePermission(
      'Create loans, rollovers and manage the ledger',
      allowed: true,
    ),
    InvitePermission('Invite staff and assign roles', allowed: true),
  ],
  Role.collector => const <InvitePermission>[
    InvitePermission('View borrowers, loans and schedules', allowed: true),
    InvitePermission('Record payments and reschedule dues', allowed: true),
    InvitePermission('Send payment reminders', allowed: true),
    InvitePermission('Create, roll over or cancel loans', allowed: false),
    InvitePermission('Manage members and invites', allowed: false),
  ],
};

/// "Expires 28 Nov, 10:00 am · in 7 days" (IST).
String inviteExpiryLabel(DateTime expiresAt, DateTime now) {
  final ist = expiresAt.toUtc().add(const Duration(hours: 5, minutes: 30));
  final when = _formatIst(ist);
  final left = expiresAt.difference(now);
  final String rel;
  if (left.inDays >= 1) {
    rel = 'in ${left.inDays} ${left.inDays == 1 ? 'day' : 'days'}';
  } else if (left.inHours >= 1) {
    rel = 'in ${left.inHours} ${left.inHours == 1 ? 'hour' : 'hours'}';
  } else {
    rel = 'soon';
  }
  return 'Expires $when · $rel';
}

/// The invite preview after a successful lookup: company, inviter, role,
/// permissions and expiry.
class InvitePreviewCard extends StatelessWidget {
  const InvitePreviewCard({
    required this.preview,
    required this.now,
    super.key,
  });

  final InvitePreview preview;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final city = preview.companyCity;
    return AppCard(
      key: const ValueKey<String>('invite_preview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CompanyAvatar(name: preview.companyName),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(preview.companyName, style: AppTextStyles.titleMd),
                    if (city != null && city.isNotEmpty)
                      Text(
                        city,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Invited by ${preview.invitedByName} (Owner)',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              const Text('Your role', style: AppTextStyles.labelLg),
              const SizedBox(width: AppSpacing.sm),
              RolePill(role: preview.role),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          for (final p in invitePermissions(preview.role))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    p.allowed ? Icons.check_circle_outline : Icons.lock_outline,
                    size: AppSizes.iconSm + AppSpacing.xs,
                    color: p.allowed
                        ? AppColors.collected
                        : AppColors.textTertiary,
                    semanticLabel: p.allowed ? 'Allowed' : 'Not allowed',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      p.label,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: p.allowed
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Container(
            key: const ValueKey<String>('invite_expiry'),
            padding: AppInsets.banner,
            decoration: const BoxDecoration(
              color: AppColors.upcomingTint,
              borderRadius: AppRadii.baseAll,
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.schedule,
                  size: AppSizes.iconSm,
                  color: AppColors.upcoming,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    inviteExpiryLabel(preview.expiresAt, now),
                    style: AppTextStyles.bodyMdTabular.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// `28 Nov, 10:05 am` from an IST wall-clock [t].
String _formatIst(DateTime t) {
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour < 12 ? 'am' : 'pm';
  return '${t.day} ${_months[t.month - 1]}, $h12:$mm $ampm';
}
