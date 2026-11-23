import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../company/application/members_providers.dart';

/// Shown after a payment is saved: the result, then the optional
/// "Send receipt to borrower" via WhatsApp or SMS from the user's own
/// phone, and Done.
class ReceiptSharePanel extends ConsumerStatefulWidget {
  const ReceiptSharePanel({
    required this.amount,
    required this.balance,
    required this.closed,
    required this.queued,
    required this.phoneE164,
    required this.message,
    required this.onDone,
    this.waived = Money.zero,
    super.key,
  });

  /// Early-closure waiver written with this close (not cash).
  final Money waived;
  final Money amount;
  final Money balance;
  final bool closed;
  final bool queued;
  final String phoneE164;
  final String message;
  final VoidCallback onDone;

  @override
  ConsumerState<ReceiptSharePanel> createState() => _ReceiptSharePanelState();
}

class _ReceiptSharePanelState extends ConsumerState<ReceiptSharePanel> {
  String? _hint;

  Future<void> _send({required bool whatsApp}) async {
    final svc = ref.read(inviteShareServiceProvider);
    final ok = whatsApp
        ? await svc.openWhatsApp(widget.phoneE164, widget.message)
        : await svc.openSms(widget.phoneE164, widget.message);
    if (!mounted) return;
    setState(
      () => _hint = ok
          ? null
          : whatsApp
          ? "WhatsApp couldn't be opened. Try SMS instead."
          : "The SMS app couldn't be opened.",
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey<String>('receipt_panel'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const Icon(
        Icons.check_circle,
        size: AppSizes.iconLg,
        color: AppColors.collected,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Recorded ${formatInr(widget.amount)}',
        textAlign: TextAlign.center,
        style: AppTextStyles.headlineSm,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        widget.closed && widget.waived.isPositive
            ? 'Loan closed · ${formatInr(widget.waived)} waived'
                  '${widget.queued ? ' · will sync' : ''}'
            : widget.closed
            ? 'Loan closed · nothing outstanding'
            : 'Balance ${formatInr(widget.balance)}'
                  '${widget.queued ? ' · will sync' : ''}',
        key: const ValueKey<String>('receipt_balance'),
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMdTabular.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        'Send receipt to borrower',
        style: AppTextStyles.labelMd.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.sm),
      DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.pressed,
          borderRadius: AppRadii.baseAll,
          border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
        ),
        child: Padding(
          padding: AppInsets.cardCompact,
          child: Text(
            widget.message,
            key: const ValueKey<String>('receipt_message'),
            style: AppTextStyles.bodyMdTabular,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey<String>('receipt_whatsapp'),
              onPressed: () => unawaited(_send(whatsApp: true)),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('WhatsApp'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey<String>('receipt_sms'),
              onPressed: () => unawaited(_send(whatsApp: false)),
              icon: const Icon(Icons.sms_outlined),
              label: const Text('SMS'),
            ),
          ),
        ],
      ),
      if (_hint != null) ...<Widget>[
        const SizedBox(height: AppSpacing.xs),
        Text(
          _hint!,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.overdue),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      FilledButton(
        key: const ValueKey<String>('receipt_done'),
        onPressed: widget.onDone,
        child: const Text('Done'),
      ),
    ],
  );
}
