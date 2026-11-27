import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/money/inr_format.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/models.dart';
import '../../../contracts/application/contract_providers.dart';
import '../../application/payment_providers.dart';
import '../../data/payment_repository.dart';

/// Owner only: confirms "Cancel onboarded loan" with a required reason.
/// Resolves to true when the cancellation was written.
Future<bool?> showCancelOnboardedDialog(
  BuildContext context, {
  required ContractView view,
  required bool queuePending,
}) => showDialog<bool>(
  context: context,
  builder: (BuildContext _) =>
      CancelOnboardedDialog(view: view, queuePending: queuePending),
);

/// "Cancel onboarded loan?": every onboarding payment is reversed on its
/// own date, the loan becomes Cancelled and drops out of the dashboard,
/// calendar and overdue tracker. The history stays.
class CancelOnboardedDialog extends ConsumerStatefulWidget {
  const CancelOnboardedDialog({
    required this.view,
    required this.queuePending,
    super.key,
  });

  final ContractView view;
  final bool queuePending;

  @override
  ConsumerState<CancelOnboardedDialog> createState() =>
      _CancelOnboardedDialogState();
}

class _CancelOnboardedDialogState extends ConsumerState<CancelOnboardedDialog> {
  final TextEditingController _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final r = await ref
          .read(paymentActionsProvider)
          .cancelOnboarded(
            view: widget.view,
            reason: _reason.text,
            queuePending: widget.queuePending,
          );
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            r.outcome == WriteOutcome.queued
                ? 'Saved · will sync'
                : 'Onboarded loan cancelled',
          ),
        ),
      );
      if (mounted) navigator.pop(true);
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.userMessage);
    } on Object {
      if (mounted) {
        setState(() => _error = const UnknownFailure(null).userMessage);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.view.snapshot;
    final blocked = cancelOnboardedBlocker(snap);
    final rows = unreversedOnboardingPayments(snap);
    final total = Money.sum(rows.map((LedgerTransaction t) => t.amount));
    final hasReason = _reason.text.trim().isNotEmpty;
    final finishing = isCancelUnfinished(snap);
    final head =
        '${rows.length} onboarding '
        '${rows.length == 1 ? 'payment' : 'payments'} totalling '
        '${formatInr(total)} will be reversed, each on its own date';
    return AlertDialog(
      key: const ValueKey<String>('cancel_onboarded_dialog'),
      title: Text(finishing ? 'Finish cancelling?' : 'Cancel onboarded loan?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            blocked ??
                (finishing
                    ? '$head. The loan stays Cancelled.'
                    : '$head, and the loan marked Cancelled. It drops out '
                          'of the dashboard, calendar and overdue tracker; '
                          'the history stays.'),
            key: const ValueKey<String>('cancel_onboarded_text'),
            style: AppTextStyles.bodyMdTabular.copyWith(
              color: blocked == null ? null : AppColors.overdue,
            ),
          ),
          if (blocked == null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('cancel_onboarded_reason'),
              controller: _reason,
              autofocus: true,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (String _) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                hintText: 'e.g. Onboarded by mistake',
                counterText: '',
              ),
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              key: const ValueKey<String>('cancel_onboarded_error'),
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.overdue),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Keep loan'),
        ),
        if (blocked == null)
          FilledButton(
            key: const ValueKey<String>('cancel_onboarded_confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.overdue),
            onPressed: _busy || !hasReason ? null : () => unawaited(_cancel()),
            child: Text(finishing ? 'Reverse the rest' : 'Cancel loan'),
          ),
      ],
    );
  }
}
