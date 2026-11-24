import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../dashboard/presentation/contact_actions.dart';

/// Call / WhatsApp (polite reminder) / Record ₹X for one overdue loan.
class OverdueActions extends ConsumerWidget {
  const OverdueActions({required this.loan, super.key});

  final OverdueLoan loan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = loan;
    final id = l.contractId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                key: ValueKey<String>('overdue_call_$id'),
                onPressed: () =>
                    unawaited(callBorrower(context, ref, l.borrowerPhoneE164)),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Call'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                key: ValueKey<String>('overdue_whatsapp_$id'),
                onPressed: () => unawaited(
                  whatsAppBorrower(
                    context,
                    ref,
                    phoneE164: l.borrowerPhoneE164,
                    borrowerName: l.borrowerName,
                    contractId: id,
                  ),
                ),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('WhatsApp'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          key: ValueKey<String>('overdue_record_$id'),
          onPressed: () =>
              unawaited(context.push<void>(AppRoutes.recordPayment(id))),
          icon: const Icon(Icons.check_circle_outline),
          label: Text(
            'Record ${formatInr(l.amount)}',
            style: AppTextStyles.labelLgTabular.copyWith(
              color: AppColors.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
