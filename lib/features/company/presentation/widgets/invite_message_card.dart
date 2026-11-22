import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/models.dart';
import '../../application/invite_message.dart';

/// Preview of the message the invitee will receive, with the code in a
/// monospace bold chip.
class InviteMessageCard extends StatelessWidget {
  const InviteMessageCard({required this.invite, super.key});

  final Invite invite;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey<String>('invite_message_preview'),
      decoration: const BoxDecoration(
        color: AppColors.primarySubtle,
        borderRadius: AppRadii.mdAll,
      ),
      child: Padding(
        padding: AppInsets.cardCompact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Message preview',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Semantics(
                  label: 'Invite code ${invite.id.split('').join(' ')}',
                  excludeSemantics: true,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadii.fullAll,
                    ),
                    child: Padding(
                      padding: AppInsets.pill,
                      child: Text(
                        invite.id,
                        key: const ValueKey<String>('invite_code_chip'),
                        style: AppTextStyles.codeMono,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              InviteMessage.forInvite(invite),
              style: AppTextStyles.bodyMd,
            ),
          ],
        ),
      ),
    );
  }
}
