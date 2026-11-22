import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/phone/indian_phone.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_sheet.dart';
import '../../../domain/models/models.dart';
import '../application/invite_message.dart';
import '../application/members_providers.dart';
import 'widgets/invite_message_card.dart';
import 'widgets/invite_send_buttons.dart';

/// Snackbar copy when an app cannot be opened.
abstract final class InviteSendCopy {
  static const String whatsAppUnavailable =
      "Couldn't open WhatsApp. Try Send via SMS instead.";
  static const String smsUnavailable =
      "Couldn't open your SMS app. Try Share link instead.";
  static String copied(String code) => 'Invite code $code copied';
}

/// Sends [invite] over [channel] from the owner's own phone and reports
/// problems / the copy confirmation with a snackbar.
Future<void> sendInvite(
  BuildContext context,
  WidgetRef ref,
  Invite invite,
  InviteChannel channel,
) async {
  final service = ref.read(inviteShareServiceProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final message = InviteMessage.forInvite(invite);
  void say(String text) =>
      messenger?.showSnackBar(SnackBar(content: Text(text)));

  switch (channel) {
    case InviteChannel.whatsApp:
      if (!await service.openWhatsApp(invite.inviteePhoneE164, message)) {
        say(InviteSendCopy.whatsAppUnavailable);
      }
    case InviteChannel.sms:
      if (!await service.openSms(invite.inviteePhoneE164, message)) {
        say(InviteSendCopy.smsUnavailable);
      }
    case InviteChannel.share:
      await service.share(
        message,
        subject: 'Join ${invite.companyName} on Nordic Ledger',
      );
    case InviteChannel.copyCode:
      await service.copy(invite.id);
      say(InviteSendCopy.copied(invite.id));
  }
}

/// Resend: the invite's message with the four send options, as a bottom
/// sheet (compact) or dialog (wider).
Future<void> showInviteShareSheet(BuildContext context, Invite invite) =>
    showAdaptiveSheet<void>(
      context,
      (BuildContext sheetContext) => _InviteShareSheet(invite: invite),
    );

class _InviteShareSheet extends ConsumerStatefulWidget {
  const _InviteShareSheet({required this.invite});

  final Invite invite;

  @override
  ConsumerState<_InviteShareSheet> createState() => _InviteShareSheetState();
}

class _InviteShareSheetState extends ConsumerState<_InviteShareSheet> {
  InviteChannel? _busy;

  Future<void> _send(InviteChannel channel) async {
    setState(() => _busy = channel);
    try {
      await sendInvite(context, ref, widget.invite, channel);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    return Column(
      key: const ValueKey<String>('invite_share_sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('Resend invite', style: AppTextStyles.headlineSm),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${invite.inviteeName} · '
          '${IndianPhone.format(invite.inviteePhoneE164)}',
          style: AppTextStyles.bodyMdTabular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        InviteMessageCard(invite: invite),
        const SizedBox(height: AppSpacing.md),
        InviteSendButtons(onSend: _send, busy: _busy),
      ],
    );
  }
}
