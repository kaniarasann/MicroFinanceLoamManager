import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/money/inr_format.dart';
import '../../../../core/money/money.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/time/today_provider.dart';
import '../../../../core/widgets/adaptive_sheet.dart';
import '../../../../core/widgets/currency_field.dart';
import '../../../../core/widgets/segmented_toggle.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/models/models.dart';
import '../../../company/application/company_providers.dart';
import '../../../contracts/application/contract_providers.dart';
import '../../../contracts/application/loan_label.dart';
import '../../../contracts/presentation/widgets/date_field.dart';
import '../../../contracts/presentation/widgets/ledger_banner.dart';
import '../../application/payment_providers.dart';
import '../../data/payment_repository.dart';
import '../widgets/payment_mode_selector.dart';
import '../widgets/receipt_share_panel.dart';

enum _Chip { full, partial, advance, close }

enum _Tab { record, rollover }

/// `/contracts/{id}/pay` (Stitch "6. Record Payment & Rollover"): a bottom
/// sheet on phones, a dialog on wider windows (see `AdaptiveSheetPage`).
/// Owners and collectors record; only owners see the Rollover entry points.
class RecordPaymentSheet extends ConsumerStatefulWidget {
  const RecordPaymentSheet({required this.contractId, super.key});

  final String contractId;

  @override
  ConsumerState<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  final TextEditingController _amountText = TextEditingController();
  final FocusNode _amountFocus = FocusNode();
  final TextEditingController _reference = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _waiveReason = TextEditingController();
  Money? _amount;
  bool _prefilled = false;
  bool _touched = false;
  bool _partialPicked = false;

  /// The "Close loan" chip was tapped (kept while the owner edits the cash
  /// of a waiver close).
  bool _closePicked = false;

  /// Owner: "Settle for less (waive the rest)" is on.
  bool _waive = false;
  bool _reasonTouched = false;
  CivilDate? _date;
  PaymentMode _mode = PaymentMode.upi;
  bool _busy = false;
  String? _error;
  _Saved? _saved;

  @override
  void dispose() {
    _amountText.dispose();
    _amountFocus.dispose();
    _reference.dispose();
    _note.dispose();
    _waiveReason.dispose();
    super.dispose();
  }

  void _setAmount(Money m, {bool close = false}) {
    _amountText.text = m.isPositive ? formatInrPlain(m) : '';
    setState(() {
      _amount = m.isPositive ? m : null;
      _touched = true;
      _partialPicked = false;
      _closePicked = close;
      _waive = false;
    });
  }

  /// Turning the waiver on clears the field for the cash actually
  /// received; turning it off restores the full outstanding.
  void _toggleWaive(bool on, Money outstanding) {
    if (on) {
      _amountText.text = '';
      setState(() {
        _waive = true;
        _amount = null;
        _touched = true;
      });
      _amountFocus.requestFocus();
    } else {
      _setAmount(outstanding, close: true);
    }
  }

  Future<void> _confirmWaiver(
    ContractView view,
    CivilDate paidOn,
    WaiverSplit split,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    final cash = split.cash;
    final mode = cash.isPositive ? _mode : null;
    try {
      final r = await ref
          .read(paymentActionsProvider)
          .closeWithWaiver(
            view: view,
            cash: cash,
            waiver: split.waiver,
            reason: _waiveReason.text,
            paidOn: paidOn,
            mode: mode,
            reference: _reference.text,
          );
      final queued = r.outcome == WriteOutcome.queued;
      messenger?.showSnackBar(
        SnackBar(content: Text(queued ? 'Saved · will sync' : 'Loan closed')),
      );
      final c = view.contract;
      if (mounted) {
        setState(
          () => _saved = _Saved(
            amount: cash,
            balance: Money.zero,
            closed: true,
            waived: split.waiver,
            queued: queued,
            phone: c.borrowerPhoneE164,
            message: receiptMessage(
              amount: cash,
              borrowerName: c.borrowerName,
              loanNo: c.loanNo,
              paidOn: paidOn,
              mode: mode,
              balance: Money.zero,
              waived: split.waiver,
              companyName: ref.read(activeCompanyNameProvider),
            ),
          ),
        );
      }
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

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.contract(widget.contractId));
    }
  }

  /// Closes the sheet first (so it animates out), then opens the rollover
  /// screen over the contract page.
  void _openRollover() {
    final router = GoRouter.of(context);
    final target = AppRoutes.rollover(widget.contractId);
    if (router.canPop()) {
      router.pop();
      unawaited(router.push<void>(target));
    } else {
      router.go(target);
    }
  }

  Future<void> _confirm(ContractView view, CivilDate paidOn) async {
    final amount = _amount;
    if (amount == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final r = await ref
          .read(paymentActionsProvider)
          .record(
            view: view,
            amount: amount,
            paidOn: paidOn,
            mode: _mode,
            reference: _reference.text,
            note: _note.text,
          );
      final queued = r.outcome == WriteOutcome.queued;
      messenger?.showSnackBar(
        SnackBar(content: Text(queued ? 'Saved · will sync' : 'Saved')),
      );
      final c = view.contract;
      if (mounted) {
        setState(
          () => _saved = _Saved(
            amount: amount,
            balance: r.balanceAfter,
            closed: r.closed,
            queued: queued,
            phone: c.borrowerPhoneE164,
            message: receiptMessage(
              amount: amount,
              borrowerName: c.borrowerName,
              loanNo: c.loanNo,
              paidOn: paidOn,
              mode: _mode,
              balance: r.balanceAfter,
              companyName: ref.read(activeCompanyNameProvider),
            ),
          ),
        );
      }
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
    final saved = _saved;
    if (saved != null) {
      return ReceiptSharePanel(
        amount: saved.amount,
        balance: saved.balance,
        closed: saved.closed,
        waived: saved.waived,
        queued: saved.queued,
        phoneE164: saved.phone,
        message: saved.message,
        onDone: _close,
      );
    }
    final async = ref.watch(contractViewProvider(widget.contractId));
    final view = async.value;
    if (view == null) {
      return SizedBox(
        key: const ValueKey<String>('record_payment_loading'),
        height: AppSizes.emptyStateBadge * 2,
        child: Center(
          child: async.isLoading
              ? const CircularProgressIndicator()
              : Text(
                  async.hasError
                      ? "Couldn't load this loan."
                      : 'Loan not found.',
                  style: AppTextStyles.bodyMd,
                ),
        ),
      );
    }
    return _form(view);
  }

  Widget _form(ContractView view) {
    final today = ref.watch(todayProvider);
    final isOwner = ref.watch(currentRoleProvider) == Role.owner;
    final p = view.projection;
    final c = view.contract;
    final quick = QuickAmounts.of(p);
    if (!_prefilled) {
      _prefilled = true;
      if (quick.fullDue.isPositive) {
        _amountText.text = formatInrPlain(quick.fullDue);
        _amount = quick.fullDue;
      }
    }
    final late = c.status == ContractStatus.rolledOver;
    final closed = !late && !c.isActive;
    final amount = _amount ?? Money.zero;
    final canClose = c.isActive && p.outstanding.isPositive;
    final chip = _closePicked && canClose
        ? _Chip.close
        : _partialPicked
        ? _Chip.partial
        : amount == quick.fullDue && amount.isPositive
        ? _Chip.full
        : amount == quick.advance && amount.isPositive
        ? _Chip.advance
        : amount == p.outstanding && canClose
        ? _Chip.close
        : _Chip.partial;
    // Owner only: "Settle for less" under the Close loan chip.
    final showWaive = isOwner && chip == _Chip.close;
    final waiving = showWaive && _waive;
    final split = WaiverSplit(cash: amount, outstanding: p.outstanding);
    final reasonMissing = _waiveReason.text.trim().isEmpty;
    final errors = waiving
        ? <String>[if (split.error != null) split.error!]
        : <String>[
            for (final e in validateRecordAmount(_amount, c, p.outstanding))
              e.message,
          ];
    final amountError = _touched && errors.isNotEmpty ? errors.first : null;
    final after = late ? Money.zero : p.outstanding - amount;
    final closesLoan = waiving || (!late && canClose && after.isZero);
    final paidOn = _date ?? today;
    final canSubmit =
        !closed && errors.isEmpty && !_busy && !(waiving && reasonMissing);
    final label = AppTextStyles.labelMd.copyWith(
      color: AppColors.textSecondary,
    );

    return Column(
      key: const ValueKey<String>('record_payment_sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(c.borrowerName, style: AppTextStyles.headlineSm),
                  Text(
                    '${loanLabel(c.loanNo)} · ${frequencyLabel(c.frequency)}',
                    style: AppTextStyles.bodyMdTabular.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey<String>('record_payment_close'),
              tooltip: 'Close',
              onPressed: _close,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusPill(
            key: const ValueKey<String>('outstanding_chip'),
            label: 'Outstanding ${formatInr(p.outstanding)}',
            kind: p.hasOverdue ? StatusKind.overdue : StatusKind.info,
          ),
        ),
        if (isOwner && c.isActive) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          SegmentedToggle<_Tab>(
            key: const ValueKey<String>('pay_tab_toggle'),
            expand: true,
            segments: const <ToggleSegment<_Tab>>[
              ToggleSegment<_Tab>(
                value: _Tab.record,
                label: 'Record installment',
              ),
              ToggleSegment<_Tab>(value: _Tab.rollover, label: 'Rollover'),
            ],
            selected: _Tab.record,
            onChanged: (_Tab t) {
              if (t == _Tab.rollover) _openRollover();
            },
          ),
        ],
        if (late) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          const LedgerBanner(
            key: ValueKey<String>('late_payment_note'),
            text:
                'This loan was rolled over. A payment recorded here shows as '
                'excess for the owner to review.',
            kind: StatusKind.upcoming,
            icon: Icons.info_outline,
          ),
        ],
        if (closed) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          const LedgerBanner(
            key: ValueKey<String>('closed_note'),
            text: 'This loan is closed. Payments can no longer be recorded.',
            kind: StatusKind.neutral,
            icon: Icons.lock_outline,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        CurrencyField(
          key: const ValueKey<String>('pay_amount'),
          controller: _amountText,
          focusNode: _amountFocus,
          large: true,
          label: waiving ? 'Cash received' : 'Amount received',
          errorText: amountError,
          enabled: !closed,
          onChanged: (Money? m) => setState(() {
            _amount = m;
            _touched = true;
            _partialPicked = false;
            if (!waiving) _closePicked = false;
          }),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            ChoiceChip(
              key: const ValueKey<String>('chip_full'),
              label: Text(
                'Full due ${formatInr(quick.fullDue)}',
                style: AppTextStyles.labelMdTabular,
              ),
              selected: chip == _Chip.full,
              onSelected: closed || !quick.fullDue.isPositive
                  ? null
                  : (bool _) => _setAmount(quick.fullDue),
            ),
            ChoiceChip(
              key: const ValueKey<String>('chip_partial'),
              label: const Text('Partial'),
              selected: chip == _Chip.partial,
              onSelected: closed
                  ? null
                  : (bool _) {
                      setState(() {
                        _partialPicked = true;
                        _closePicked = false;
                        _waive = false;
                      });
                      _amountFocus.requestFocus();
                    },
            ),
            ChoiceChip(
              key: const ValueKey<String>('chip_advance'),
              label: Text(
                'Advance ${formatInr(quick.advance)}',
                style: AppTextStyles.labelMdTabular,
              ),
              selected: chip == _Chip.advance,
              onSelected: closed || !quick.advance.isPositive
                  ? null
                  : (bool _) => _setAmount(quick.advance),
            ),
            if (canClose)
              ChoiceChip(
                key: const ValueKey<String>('chip_close'),
                label: Text(
                  'Close loan ${formatInr(p.outstanding)}',
                  style: AppTextStyles.labelMdTabular,
                ),
                selected: chip == _Chip.close,
                onSelected: (bool _) => _setAmount(p.outstanding, close: true),
              ),
          ],
        ),
        if (showWaive) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            key: const ValueKey<String>('waive_toggle'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Settle for less (waive the rest)',
              style: AppTextStyles.bodyMd,
            ),
            value: _waive,
            onChanged: (bool on) => _toggleWaive(on, p.outstanding),
          ),
          if (waiving) ...<Widget>[
            Text(
              'Waive ${formatInr(split.waiver.isNegative ? Money.zero : split.waiver)}',
              key: const ValueKey<String>('waive_amount'),
              style: AppTextStyles.labelLgTabular,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey<String>('waive_reason'),
              controller: _waiveReason,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (String _) => setState(() => _reasonTouched = true),
              decoration: InputDecoration(
                labelText: 'Reason for waiver',
                hintText: 'e.g. Early closure discount',
                counterText: '',
                errorText: _reasonTouched && reasonMissing
                    ? 'Enter a reason for the waiver.'
                    : null,
              ),
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Short amounts are added to the end of the schedule.',
          key: ValueKey<String>('short_helper'),
          style: AppTextStyles.bodySm,
        ),
        const SizedBox(height: AppSpacing.lg),
        DateField(
          fieldKey: const ValueKey<String>('pay_date'),
          label: 'Date of collection',
          value: paidOn,
          first: today.addDays(-maxBackdateDays),
          last: today,
          onChanged: (CivilDate d) => setState(() => _date = d),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Payment mode', style: label),
        const SizedBox(height: AppSpacing.sm),
        PaymentModeSelector(
          selected: _mode,
          onChanged: (PaymentMode m) => setState(() => _mode = m),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey<String>('pay_reference'),
          controller: _reference,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Reference (optional)',
            hintText: 'UPI ref / receipt no.',
            counterText: '',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey<String>('pay_note'),
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Internal note (optional)',
            counterText: '',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!closed)
          Text(
            waiving
                ? 'Cash ${formatInr(amount)} + waived '
                      '${formatInr(split.waiver.isNegative ? Money.zero : split.waiver)}'
                      ' = closes the loan'
                : late
                ? 'After this: excess of ${formatInr(p.excess + amount)} '
                      'to review'
                : 'After this: ${formatInr(after.isNegative ? Money.zero : after)} '
                      'outstanding${after.isZero ? ' · closes the loan' : ''}',
            key: const ValueKey<String>('after_line'),
            style: AppTextStyles.labelLgTabular.copyWith(
              color: closesLoan ? AppColors.collected : AppColors.textPrimary,
            ),
          ),
        if (isOwner && c.isActive) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Card(
            key: const ValueKey<String>('rollover_card'),
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.autorenew, color: AppColors.primary),
              title: const Text('Roll over this loan'),
              subtitle: Text(
                'Settle ${formatInr(p.outstanding)} into a new loan',
                style: AppTextStyles.bodySmTabular,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openRollover,
            ),
          ),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            _error!,
            key: const ValueKey<String>('pay_error'),
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.overdue),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const ValueKey<String>('pay_confirm'),
          onPressed: !canSubmit
              ? null
              : waiving
              ? () => unawaited(_confirmWaiver(view, paidOn, split))
              : () => unawaited(_confirm(view, paidOn)),
          child: _busy
              ? const SizedBox.square(
                  dimension: AppSizes.iconSm,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : Text(
                  closesLoan && errors.isEmpty
                      ? 'Confirm & close loan'
                      : errors.isEmpty
                      ? 'Confirm & record ${formatInr(amount)} '
                            '(${paymentModeLabel(_mode)})'
                      : 'Confirm & record',
                  style: AppTextStyles.labelLgTabular.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.cloud_done_outlined,
              size: AppSizes.iconSm,
              color: AppColors.textSecondary,
            ),
            SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                'Works offline · syncs automatically',
                key: ValueKey<String>('offline_footer'),
                style: AppTextStyles.bodySm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

final class _Saved {
  const _Saved({
    required this.amount,
    required this.balance,
    required this.closed,
    required this.queued,
    required this.phone,
    required this.message,
    this.waived = Money.zero,
  });

  final Money waived;
  final Money amount;
  final Money balance;
  final bool closed;
  final bool queued;
  final String phone;
  final String message;
}

/// The `/contracts/{id}/pay` page: [RecordPaymentSheet] as a bottom sheet
/// (compact) or a dialog (wider), over the contract page.
Page<void> recordPaymentPage(GoRouterState state) {
  final id = state.pathParameters['id']!;
  return AdaptiveSheetPage<void>(
    key: state.pageKey,
    name: state.name,
    builder: (BuildContext _) => RecordPaymentSheet(contractId: id),
  );
}
