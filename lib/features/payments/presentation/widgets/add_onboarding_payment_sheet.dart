import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/money/inr_format.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/time/today_provider.dart';
import '../../../../core/widgets/adaptive_sheet.dart';
import '../../../../core/widgets/currency_field.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../../domain/models/models.dart';
import '../../../contracts/application/contract_providers.dart';
import '../../../contracts/presentation/widgets/date_field.dart';
import '../../application/payment_providers.dart';
import '../../data/payment_repository.dart';
import 'payment_mode_selector.dart';

/// Owner only: opens "Add missing onboarding payment" for a partly synced
/// onboarding (bottom sheet on phones, 560 dialog on wider windows).
/// Resolves to true when saved.
Future<bool?> showAddOnboardingPaymentSheet(
  BuildContext context, {
  required ContractView view,
}) => showAdaptiveSheet<bool>(
  context,
  (BuildContext _) => AddOnboardingPaymentSheet(view: view),
);

/// Date within [disbursedOn, onboardedOn], amount ≤ outstanding, mode and
/// an optional reference → one `origin: onboarding` payment. No receipt is
/// offered: the borrower paid this long ago.
class AddOnboardingPaymentSheet extends ConsumerStatefulWidget {
  const AddOnboardingPaymentSheet({required this.view, super.key});

  final ContractView view;

  @override
  ConsumerState<AddOnboardingPaymentSheet> createState() =>
      _AddOnboardingPaymentSheetState();
}

class _AddOnboardingPaymentSheetState
    extends ConsumerState<AddOnboardingPaymentSheet> {
  late CivilDate _date = defaultRepairDate(
    widget.view.snapshot,
    ref.read(todayProvider),
  );
  Money? _amount;
  PaymentMode _mode = PaymentMode.cash;
  late final OnboardingSync? _sync = OnboardingSync.of(widget.view.snapshot);

  /// Opening-total loan: the repair is an opening-balance row. Unknown
  /// (nothing landed yet) → the owner chooses; default yes.
  late bool _opening = _sync?.isOpeningTotal ?? true;
  final TextEditingController _reference = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Money get _cap =>
      _sync?.repairCap(widget.view.snapshot.outstanding) ?? Money.zero;

  List<ValidationError> get _errors {
    final a = _amount ?? Money.zero;
    final errors = validatePaymentAmount(a, widget.view.snapshot.outstanding);
    if (errors.isNotEmpty) return errors;
    if (a > _cap) {
      return <ValidationError>[
        ValidationError(
          LedgerFields.amount,
          'At most ${formatInr(_cap)} is missing from this onboarding.',
        ),
      ];
    }
    return const <ValidationError>[];
  }

  Future<void> _save() async {
    if (_errors.isNotEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final r = await ref
          .read(paymentActionsProvider)
          .addOnboardingPayment(
            view: widget.view,
            amount: _amount!,
            paidOn: _date,
            mode: _mode,
            reference: _reference.text,
            openingBalance: _opening,
          );
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            r.outcome == WriteOutcome.queued
                ? 'Saved · will sync'
                : 'Onboarding payment added',
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
    final c = widget.view.contract;
    final last = c.onboardedOn ?? c.disbursedOn;
    final errors = _errors;
    return Column(
      key: const ValueKey<String>('add_onboarding_payment_sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          'Add missing onboarding payment',
          style: AppTextStyles.headlineSm,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'For a past payment that did not sync. Dated from '
          '${formatCivilDate(c.disbursedOn)} to ${formatCivilDate(last)} '
          '(the onboarding day).',
          style: AppTextStyles.bodyMdTabular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${formatInr(_sync?.missing ?? Money.zero)} missing · at most '
          '${formatInr(_cap)} can be added',
          key: const ValueKey<String>('add_onboarding_missing'),
          style: AppTextStyles.labelLgTabular.copyWith(
            color: AppColors.upcoming,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Payments still queued on the phone that onboarded this loan will '
          'appear when it syncs. Check that phone first.',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
        ),
        if (_sync?.isOpeningTotal == null)
          SwitchListTile(
            key: const ValueKey<String>('add_onboarding_opening'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Part of an opening total'),
            subtitle: const Text('Labelled "Opening balance" in the ledger'),
            value: _opening,
            onChanged: (bool v) => setState(() => _opening = v),
          ),
        const SizedBox(height: AppSpacing.lg),
        DateField(
          fieldKey: const ValueKey<String>('add_onboarding_date'),
          label: 'Paid on',
          value: _date,
          first: c.disbursedOn,
          last: last,
          onChanged: (CivilDate d) => setState(() => _date = d),
        ),
        const SizedBox(height: AppSpacing.md),
        CurrencyField(
          key: const ValueKey<String>('add_onboarding_amount'),
          label: 'Amount',
          errorText: _amount == null
              ? null
              : errors
                    .where(
                      (ValidationError e) => e.field == LedgerFields.amount,
                    )
                    .firstOrNull
                    ?.message,
          onChanged: (Money? m) => setState(() => _amount = m),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Mode',
          style: AppTextStyles.labelMd.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        PaymentModeSelector(
          selected: _mode,
          onChanged: (PaymentMode m) => setState(() => _mode = m),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey<String>('add_onboarding_reference'),
          controller: _reference,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Reference (optional)',
            counterText: '',
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            _error!,
            key: const ValueKey<String>('add_onboarding_error'),
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.overdue),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const ValueKey<String>('add_onboarding_save'),
          onPressed: _busy || errors.isNotEmpty
              ? null
              : () => unawaited(_save()),
          child: _busy
              ? const SizedBox.square(
                  dimension: AppSizes.iconSm,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : const Text('Add payment'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
