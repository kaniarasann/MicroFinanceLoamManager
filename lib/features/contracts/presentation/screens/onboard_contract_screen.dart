import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/money/inr_format.dart';
import '../../../../core/money/money.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/time/today_provider.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../../domain/models/models.dart';
import '../../../borrowers/application/borrower_providers.dart';
import '../../../company/application/company_providers.dart';
import '../../application/contract_providers.dart';
import '../../application/onboarding_draft.dart';
import '../../data/contract_repository.dart';
import '../widgets/borrower_card.dart';
import '../widgets/date_field.dart';
import '../widgets/loan_amount_fields.dart';
import '../widgets/loan_kind_toggle.dart';
import '../widgets/loan_schedule_fields.dart';
import '../widgets/loan_summary_card.dart';
import '../widgets/loan_terms_controller.dart';
import '../widgets/onboarding_preview.dart';
import '../widgets/past_payment_sheet.dart';
import '../widgets/past_payments_section.dart';
import 'create_contract_screen.dart' show loanPurposes;

/// `/contracts/onboard?borrowerId=`: onboard an existing, in-progress loan
/// with its original terms and dates plus what was already collected
/// (Section 1 addendum 2026-11-24). Composed from Stitch "4. Create New
/// Loan Contract" (form) and "7. Contract Installment Schedule" (preview).
/// Owner only; collectors are sent away. Expanded windows show the form
/// (7 of 12 columns) beside a sticky "As of today" preview (5 of 12).
class OnboardContractScreen extends ConsumerStatefulWidget {
  const OnboardContractScreen({this.borrowerId, super.key});

  final String? borrowerId;

  @override
  ConsumerState<OnboardContractScreen> createState() =>
      _OnboardContractScreenState();
}

class _OnboardContractScreenState extends ConsumerState<OnboardContractScreen> {
  late String? _borrowerId = widget.borrowerId;
  final LoanTermsController _terms = LoanTermsController();
  final TextEditingController _opening = TextEditingController();
  final TextEditingController _previousRef = TextEditingController();
  final TextEditingController _guarantor = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  PastPaymentsMode _mode = PastPaymentsMode.openingTotal;
  Money? _openingTotal;
  PaymentMode _openingMode = PaymentMode.cash;
  List<PastPaymentInput> _rows = const <PastPaymentInput>[];
  String? _purpose;
  bool _submitted = false;
  bool _busy = false;
  bool _leaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _terms.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _terms
      ..removeListener(_changed)
      ..dispose();
    _opening.dispose();
    _previousRef.dispose();
    _guarantor.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _leave(String message) {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    });
  }

  OnboardingDraft _draft(CivilDate today, int nextLoanNo) => OnboardingDraft(
    terms: _terms.draft(today),
    today: today,
    mode: _mode,
    openingTotal: _openingTotal,
    openingMode: _openingMode,
    rows: _rows,
    previousRef: _previousRef.text,
    cachedNextLoanNo: nextLoanNo,
  );

  Future<void> _addRow(CivilDate disbursedOn, CivilDate today) async {
    final row = await showPastPaymentSheet(
      context,
      disbursedOn: disbursedOn,
      today: today,
    );
    if (row == null || !mounted) return;
    setState(() => _rows = <PastPaymentInput>[..._rows, row]);
  }

  Future<void> _editRow(
    int index,
    CivilDate disbursedOn,
    CivilDate today,
  ) async {
    final row = await showPastPaymentSheet(
      context,
      disbursedOn: disbursedOn,
      today: today,
      initial: _rows[index],
    );
    if (row == null || !mounted) return;
    setState(() {
      _rows = <PastPaymentInput>[
        for (var i = 0; i < _rows.length; i++) i == index ? row : _rows[i],
      ];
    });
  }

  void _deleteRow(int index) => setState(() {
    _rows = <PastPaymentInput>[
      for (var i = 0; i < _rows.length; i++)
        if (i != index) _rows[i],
    ];
  });

  Future<void> _fill(OnboardingDraft d) async {
    final schedule = d.schedule;
    if (schedule == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final first = schedule.first.dueDate;
    if (first.isAfter(d.today)) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('No installment is due yet.')),
      );
      return;
    }
    // Default to the last due date before today (or yesterday), so today's
    // installment stays open unless the owner picks today explicitly.
    final before = <CivilDate>[
      for (final r in schedule)
        if (r.dueDate.isBefore(d.today)) r.dueDate,
    ];
    var initial = before.isEmpty ? d.today.addDays(-1) : before.last;
    if (initial.isBefore(first)) initial = first;
    final picked = await showDatePicker(
      context: context,
      helpText: 'Fill installments due up to',
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(d.today.year, d.today.month, d.today.day),
    );
    if (picked == null || !mounted) return;
    final upTo = CivilDate(picked.year, picked.month, picked.day);
    if (_rows.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext c) => AlertDialog(
          title: const Text('Replace the payments?'),
          content: Text(
            'The ${_rows.length} payments entered so far are replaced by one '
            'payment per installment due up to ${formatCivilDate(upTo)}.',
            style: AppTextStyles.bodyMdTabular,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey<String>('fill_replace_confirm'),
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final rows = fillFromSchedule(
      schedule: schedule,
      upTo: upTo,
      mode: PaymentMode.cash,
    );
    setState(() => _rows = rows);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          'Filled ${rows.length} ${rows.length == 1 ? 'payment' : 'payments'}'
          '. Edit any that differ.',
        ),
      ),
    );
  }

  Future<void> _submit(OnboardingDraft d, Borrower? borrower) async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (borrower == null || d.errors.isNotEmpty) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final router = GoRouter.of(context);
    final t = d.terms;
    try {
      final r = await ref
          .read(contractActionsProvider)
          .onboard(
            borrower: borrower,
            sanctioned: t.sanctioned ?? Money.zero,
            upfrontMode: t.upfrontMode,
            upfrontInput: t.upfrontInput ?? 0,
            installmentAmount: t.installmentAmount ?? Money.zero,
            frequency: t.frequency,
            preferredWeekday: t.weekday,
            preferredMonthDay: t.monthDay,
            disbursedOn: t.disbursedOn,
            firstDueDate: t.firstDueDate,
            // Only the selected mode: the spread OR the itemised rows.
            pastPayments: d.pastPayments,
            previousRef: _previousRef.text,
            guarantor: _guarantor.text,
            notes: _notes.text,
            purpose: _purpose,
          );
      messenger
        ?..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              r.outcome == WriteOutcome.queued
                  ? 'Saved · will sync'
                  : 'Loan onboarded · ${formatInr(d.collected)} collected so far',
            ),
          ),
        );
      if (mounted) unawaited(router.pushReplacement(AppRoutes.contract(r.id)));
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
    final role = ref.watch(currentRoleProvider);
    if (role == Role.collector) {
      _leave('Only owners can onboard loans.');
      return const Scaffold(body: SizedBox.shrink());
    }
    final company = ref.watch(activeCompanyProvider).value;
    final today = ref.watch(todayProvider);
    final d = _draft(today, company?.nextLoanNo ?? 0);
    final id = _borrowerId;
    final borrower = id == null ? null : ref.watch(borrowerProvider(id)).value;
    final window = WindowSize.of(context);
    final margin = window.margin;

    final form = <Widget>[
      LoanKindToggle(
        selected: LoanKind.existing,
        onChanged: (LoanKind _) => context.pushReplacement(
          AppRoutes.newContract(borrowerId: _borrowerId),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      BorrowerCard(
        borrower: borrower,
        loading: id != null && borrower == null,
        errorText: _submitted && borrower == null ? 'Choose a borrower.' : null,
        onPicked: (String picked) => setState(() => _borrowerId = picked),
      ),
      ..._step('Step 1', 'Original loan'),
      LoanAmountFields(
        terms: _terms,
        draft: d.terms,
        showAllErrors: _submitted,
        upfrontHelperText:
            'Enter what was deducted at disbursement. Unknown? Enter ₹0.',
      ),
      const SizedBox(height: AppSpacing.md),
      LoanSummaryCard(
        sanctioned: d.terms.sanctioned ?? Money.zero,
        upfront: d.terms.upfront,
        net: d.terms.netDisbursed,
      ),
      ..._step('Step 2', 'Original dates & schedule'),
      DateField(
        fieldKey: const ValueKey<String>('disbursed_on_field'),
        label: 'Disbursed on',
        value: d.disbursedOn,
        first: earliestOnboardDisbursal(today),
        last: today,
        errorText: d.errorFor(LedgerFields.disbursedOn),
        onChanged: _terms.disbursedOnChanged,
      ),
      const SizedBox(height: AppSpacing.md),
      LoanScheduleFields(
        terms: _terms,
        draft: d.terms,
        today: today,
        showAllErrors: _submitted,
        firstDueMin: d.disbursedOn,
        firstDueMax: latestOnboardFirstDue(d.disbursedOn),
        firstDueErrorText: d.errorFor(LedgerFields.firstDueDate),
        showSchedulePreview: false,
      ),
      ..._step('Step 3', 'Collected so far'),
      PastPaymentsSection(
        draft: d,
        openingController: _opening,
        showAllErrors: _submitted,
        onModeChanged: (PastPaymentsMode m) => setState(() => _mode = m),
        onOpeningChanged: (Money? m) => setState(() => _openingTotal = m),
        onOpeningModeChanged: (PaymentMode m) =>
            setState(() => _openingMode = m),
        onAdd: () => unawaited(_addRow(d.disbursedOn, today)),
        onEdit: (int i) => unawaited(_editRow(i, d.disbursedOn, today)),
        onDelete: _deleteRow,
        onFill: () => unawaited(_fill(d)),
      ),
      if (!window.isExpanded) ...<Widget>[
        ..._step('Step 4', 'As of today'),
        OnboardingPreview(projection: d.preview),
      ],
      ..._step('Optional', 'Reference & agreement'),
      TextField(
        key: const ValueKey<String>('previous_ref_field'),
        controller: _previousRef,
        maxLength: maxPreviousRefLength,
        onChanged: (String _) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Previous reference no. (optional)',
          hintText: 'Paper book or old-system loan number',
          errorText: d.errorFor(LedgerFields.previousRef),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        key: const ValueKey<String>('guarantor_field'),
        controller: _guarantor,
        textCapitalization: TextCapitalization.words,
        maxLength: 80,
        decoration: const InputDecoration(
          labelText: 'Guarantor (optional)',
          counterText: '',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Text('Purpose', style: _label),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          for (final p in loanPurposes)
            ChoiceChip(
              key: ValueKey<String>('purpose_$p'),
              label: Text(p),
              selected: _purpose == p,
              onSelected: (bool on) => setState(() => _purpose = on ? p : null),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        key: const ValueKey<String>('notes_field'),
        controller: _notes,
        textCapitalization: TextCapitalization.sentences,
        minLines: 2,
        maxLines: 4,
        maxLength: 500,
        decoration: const InputDecoration(
          labelText: 'Notes (optional)',
          counterText: '',
        ),
      ),
    ];

    final Widget body;
    if (window.isExpanded) {
      body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: WindowSize.maxContentWidth,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 7,
                child: ListView(
                  key: const ValueKey<String>('onboard_form'),
                  padding: EdgeInsets.fromLTRB(
                    margin,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  children: form,
                ),
              ),
              Expanded(
                flex: 5,
                child: ListView(
                  key: const ValueKey<String>('onboard_preview_pane'),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    margin,
                    AppSpacing.xl,
                  ),
                  children: <Widget>[
                    Text('Step 4', style: _label),
                    const Text('As of today', style: AppTextStyles.headlineSm),
                    const SizedBox(height: AppSpacing.sm),
                    OnboardingPreview(projection: d.preview),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
          child: ListView(
            key: const ValueKey<String>('onboard_form'),
            padding: EdgeInsets.fromLTRB(
              margin,
              AppSpacing.md,
              margin,
              AppSpacing.xl,
            ),
            children: form,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Onboard existing loan')),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: _footer(d, borrower),
    );
  }

  static final TextStyle _label = AppTextStyles.labelMd.copyWith(
    color: AppColors.textSecondary,
  );

  List<Widget> _step(String step, String title) => <Widget>[
    Padding(
      padding: AppInsets.sectionHeader,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(step, style: _label),
          Text(title, style: AppTextStyles.headlineSm),
        ],
      ),
    ),
  ];

  Widget _footer(OnboardingDraft d, Borrower? borrower) {
    final p = d.preview;
    final summary = p == null
        ? 'Complete the form to see the balance'
        : 'Outstanding ${formatInr(p.outstanding)} · '
              '${p.overdueCount} overdue';
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: AppInsets.cardCompact,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                summary,
                key: const ValueKey<String>('onboard_summary_line'),
                style: AppTextStyles.labelLgTabular.copyWith(
                  color: p != null && p.hasOverdue
                      ? AppColors.overdue
                      : AppColors.textPrimary,
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _error!,
                  key: const ValueKey<String>('onboard_error'),
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.overdue,
                  ),
                ),
              ] else if (_submitted && d.errors.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Fix the highlighted fields to onboard this loan.',
                  key: const ValueKey<String>('onboard_fix_fields'),
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.overdue,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                key: const ValueKey<String>('onboard_submit'),
                onPressed: _busy ? null : () => unawaited(_submit(d, borrower)),
                child: _busy
                    ? const SizedBox.square(
                        dimension: AppSizes.iconSm,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text('Onboard loan'),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Works offline · syncs automatically',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
