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

/// Owner only: confirms "Reverse opening balance" with a required reason.
/// Resolves to true when the reversals were written.
Future<bool?> showReverseOpeningDialog(
  BuildContext context, {
  required ContractView view,
}) => showDialog<bool>(
  context: context,
  builder: (BuildContext _) => ReverseOpeningDialog(view: view),
);

/// "Reverse opening balance?" with the number of opening rows and their
/// total. Each row gets a reversal dated on its own date, so today's
/// figures do not move; the originals stay in the history, struck through.
class ReverseOpeningDialog extends ConsumerStatefulWidget {
  const ReverseOpeningDialog({required this.view, super.key});

  final ContractView view;

  @override
  ConsumerState<ReverseOpeningDialog> createState() =>
      _ReverseOpeningDialogState();
}

class _ReverseOpeningDialogState extends ConsumerState<ReverseOpeningDialog> {
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
          .reverseOpeningBalance(view: widget.view, reason: _reason.text);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            r.outcome == WriteOutcome.queued
                ? 'Saved · will sync'
                : 'Opening balance reversed',
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
    final rows = unreversedOpeningBalance(widget.view.snapshot);
    final total = Money.sum(rows.map((LedgerTransaction t) => t.amount));
    final hasReason = _reason.text.trim().isNotEmpty;
    return AlertDialog(
      key: const ValueKey<String>('reverse_opening_dialog'),
      title: const Text('Reverse opening balance?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '${rows.length} opening-balance '
            '${rows.length == 1 ? 'payment' : 'payments'} totalling '
            '${formatInr(total)} will be reversed, each on its own date. The '
            'original entries stay in the history.',
            style: AppTextStyles.bodyMdTabular,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey<String>('reverse_opening_reason'),
            controller: _reason,
            autofocus: true,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (String _) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Reason (required)',
              hintText: 'e.g. Wrong opening total',
              counterText: '',
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              key: const ValueKey<String>('reverse_opening_error'),
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
        FilledButton(
          key: const ValueKey<String>('reverse_opening_confirm'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.overdue),
          onPressed: _busy || !hasReason ? null : () => unawaited(_reverse()),
          child: const Text('Reverse'),
        ),
      ],
    );
  }
}
