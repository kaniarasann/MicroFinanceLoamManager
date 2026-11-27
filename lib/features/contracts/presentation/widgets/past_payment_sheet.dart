import 'package:flutter/material.dart';

import '../../application/loan_label.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/widgets/adaptive_sheet.dart';
import '../../../../core/widgets/currency_field.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../../domain/models/enums.dart';
import '../../../payments/presentation/widgets/payment_mode_selector.dart';
import 'date_field.dart';

/// Opens the itemised past-payment editor (bottom sheet on phones, 560
/// dialog on wider windows). Resolves to the entered row, or null when
/// cancelled. [initial] edits an existing row.
Future<PastPaymentInput?> showPastPaymentSheet(
  BuildContext context, {
  required CivilDate disbursedOn,
  required CivilDate today,
  PastPaymentInput? initial,
}) => showAdaptiveSheet<PastPaymentInput>(
  context,
  (BuildContext _) => PastPaymentSheet(
    disbursedOn: disbursedOn,
    today: today,
    initial: initial,
  ),
);

/// One itemised past payment: date in [disbursedOn, today], amount > ₹0,
/// mode and an optional reference. Pops with the row; writes nothing.
class PastPaymentSheet extends StatefulWidget {
  const PastPaymentSheet({
    required this.disbursedOn,
    required this.today,
    this.initial,
    super.key,
  });

  final CivilDate disbursedOn;
  final CivilDate today;
  final PastPaymentInput? initial;

  @override
  State<PastPaymentSheet> createState() => _PastPaymentSheetState();
}

class _PastPaymentSheetState extends State<PastPaymentSheet> {
  late CivilDate _date = _clamp(widget.initial?.paidOn ?? widget.today);
  late Money? _amount = widget.initial?.amount;
  late PaymentMode _mode = widget.initial?.mode ?? PaymentMode.cash;
  late final TextEditingController _reference = TextEditingController(
    text: widget.initial?.reference ?? '',
  );
  bool _submitted = false;

  CivilDate _clamp(CivilDate d) {
    if (d.isBefore(widget.disbursedOn)) return widget.disbursedOn;
    if (d.isAfter(widget.today)) return widget.today;
    return d;
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  String? get _amountError {
    final a = _amount;
    if (a == null || !a.isPositive) return 'Each payment must be more than ₹0.';
    return null;
  }

  void _save() {
    setState(() => _submitted = true);
    if (_amountError != null) return;
    final ref = _reference.text.trim();
    Navigator.of(context).pop(
      PastPaymentInput(
        paidOn: _date,
        amount: _amount!,
        mode: _mode,
        reference: ref.isEmpty ? null : ref,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return Column(
      key: const ValueKey<String>('past_payment_sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          editing ? 'Edit past payment' : 'Add past payment',
          style: AppTextStyles.headlineSm,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Any date from ${formatCivilDate(widget.disbursedOn)} '
          '(disbursed) to today.',
          style: AppTextStyles.bodyMdTabular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        DateField(
          fieldKey: const ValueKey<String>('past_payment_date'),
          label: 'Paid on',
          value: _date,
          first: widget.disbursedOn,
          last: widget.today,
          onChanged: (CivilDate d) => setState(() => _date = d),
        ),
        const SizedBox(height: AppSpacing.md),
        CurrencyField(
          key: const ValueKey<String>('past_payment_amount'),
          label: 'Amount',
          initialValue: widget.initial?.amount,
          autofocus: !editing,
          errorText: _submitted ? _amountError : null,
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
          key: const ValueKey<String>('past_payment_reference'),
          controller: _reference,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Reference (optional)',
            hintText: 'e.g. Book 3, page 12',
            counterText: '',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const ValueKey<String>('past_payment_save'),
          onPressed: _save,
          child: Text(editing ? 'Update payment' : 'Add payment'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Short row label for the itemised list: "12 Sep 2026 · Cash".
String pastPaymentMeta(PastPaymentInput p) => <String>[
  formatCivilDate(p.paidOn),
  if (p.mode != null) paymentModeLabel(p.mode!),
  if (p.reference != null && p.reference!.isNotEmpty) p.reference!,
].join(' · ');
