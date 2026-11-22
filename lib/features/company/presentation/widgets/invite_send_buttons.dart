import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/invite_message.dart';

/// "Send via WhatsApp" (sage tint) and "Send via SMS" (outlined), then ghost
/// "Share link" / "Copy code". [busy] shows a spinner on that channel and
/// disables the rest; [enabled] false disables all.
class InviteSendButtons extends StatelessWidget {
  const InviteSendButtons({
    required this.onSend,
    this.busy,
    this.enabled = true,
    super.key,
  });

  final ValueChanged<InviteChannel> onSend;
  final InviteChannel? busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && busy == null;
    VoidCallback? tap(InviteChannel c) => active ? () => onSend(c) : null;

    Widget icon(InviteChannel c, IconData data) => busy == c
        ? const SizedBox.square(
            dimension: AppSizes.iconSm,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(data, size: AppSizes.iconSm + AppSpacing.xxs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          key: const ValueKey<String>('invite_send_whatsapp'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.collectedTint,
            foregroundColor: AppColors.collected,
          ),
          onPressed: tap(InviteChannel.whatsApp),
          icon: icon(InviteChannel.whatsApp, Icons.chat_outlined),
          label: const Text('Send via WhatsApp'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const ValueKey<String>('invite_send_sms'),
          onPressed: tap(InviteChannel.sms),
          icon: icon(InviteChannel.sms, Icons.sms_outlined),
          label: const Text('Send via SMS'),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          children: <Widget>[
            TextButton.icon(
              key: const ValueKey<String>('invite_share'),
              onPressed: tap(InviteChannel.share),
              icon: icon(InviteChannel.share, Icons.share_outlined),
              label: const Text('Share link'),
            ),
            TextButton.icon(
              key: const ValueKey<String>('invite_copy'),
              onPressed: tap(InviteChannel.copyCode),
              icon: icon(InviteChannel.copyCode, Icons.copy_outlined),
              label: const Text('Copy code'),
            ),
          ],
        ),
      ],
    );
  }
}
