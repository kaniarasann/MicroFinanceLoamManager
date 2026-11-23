import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/money/inr_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../domain/models/models.dart';
import '../../../company/application/company_providers.dart';
import '../../../contracts/application/contract_providers.dart';
import '../../application/payment_providers.dart';
import '../../data/payment_repository.dart';

/// Owner only: confirms reversing [tx] with a required reason. Resolves to
/// true when the reversal was written.
Future<bool?> showReversePaymentDialog(
  BuildContext context, {
  required ContractView view,
  required LedgerTransaction tx,
}) => showDialog<bool>(
  context: context,
  builder: (BuildContext _) => ReversePaymentDialog(view: view, tx: tx),
);

/// "Reverse payment?" with the payment's amount and date, a required
/// reason, and a terracotta Reverse button. A reversal is a new ledger
/// entry; the original payment stays in the history, struck through.
class ReversePaymentDialog extends ConsumerStatefulWidget {
  const ReversePaymentDialog({required this.view, required this.tx, super.key});

  final ContractView view;
  final LedgerTransaction tx;

  @override
  ConsumerState<ReversePaymentDialog> createState() =>
      _ReversePaymentDialogState();
}

class _ReversePaymentDialogState extends ConsumerState<ReversePaymentDialog> {
  final TextEditingController _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _reverse() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final r = await ref
          .read(paymentActionsProvider)
          .reverse(
            view: widget.view,
            transactionId: widget.tx.id,
            reason: _reason.text,
          );
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            r.outcome == WriteOutcome.queued
                ? 'Saved · will sync'
                : widget.tx.type == TxType.waiver
                ? 'Waiver reversed'
                : 'Payment reversed',
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
    final isOwner = ref.watch(currentRoleProvider) == Role.owner;
    final hasReason = _reason.text.trim().isNotEmpty;
    final tx = widget.tx;
    final waiver = tx.type == TxType.waiver;
    return AlertDialog(
      key: const ValueKey<String>('reverse_dialog'),
      title: Text(waiver ? 'Reverse waiver?' : 'Reverse payment?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            !isOwner
                ? 'Only owners can reverse payments.'
                : waiver
                ? '${formatInr(tx.amount)} waived ${formatCivilDate(tx.paidOn)} '
                      'will be reversed and the loan reopens. The original '
                      'entry stays in the history.'
                : '${formatInr(tx.amount)} received ${formatCivilDate(tx.paidOn)} '
                      'will be reversed. The original entry stays in the '
                      'history.',
            style: AppTextStyles.bodyMdTabular,
          ),
          if (isOwner) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('reverse_reason'),
              controller: _reason,
              autofocus: true,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (String _) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                hintText: 'e.g. Duplicate entry',
                counterText: '',
              ),
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              key: const ValueKey<String>('reverse_error'),
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.overdue),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (isOwner)
          FilledButton(
            key: const ValueKey<String>('reverse_confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.overdue),
            onPressed: _busy || !hasReason ? null : () => unawaited(_reverse()),
            child: const Text('Reverse'),
          ),
      ],
    );
  }
}
