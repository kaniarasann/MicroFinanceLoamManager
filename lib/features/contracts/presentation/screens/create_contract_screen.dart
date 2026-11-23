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
import '../../../../core/time/today_provider.dart';
import '../../../../domain/models/models.dart';
import '../../../borrowers/application/borrower_providers.dart';
import '../../../company/application/company_providers.dart';
import '../../application/contract_draft.dart';
import '../../application/contract_providers.dart';
import '../../data/contract_repository.dart';
import '../widgets/borrower_card.dart';
import '../widgets/loan_amount_fields.dart';
import '../widgets/loan_schedule_fields.dart';
import '../widgets/loan_summary_card.dart';
import '../widgets/loan_terms_controller.dart';

/// Purpose tags offered on the form.
const List<String> loanPurposes = <String>[
  'Business',
  'Shop stock',
  'Agriculture',
  'Education',
  'Medical',
  'Personal',
];

/// `/contracts/new?borrowerId=`: create and disburse a loan (Stitch
/// "4. Create New Loan Contract"). Owner only; collectors are sent away.
class CreateContractScreen extends ConsumerStatefulWidget {
  const CreateContractScreen({this.borrowerId, super.key});

  final String? borrowerId;

  @override
  ConsumerState<CreateContractScreen> createState() =>
      _CreateContractScreenState();
}

class _CreateContractScreenState extends ConsumerState<CreateContractScreen> {
  late String? _borrowerId = widget.borrowerId;
  final LoanTermsController _terms = LoanTermsController();
  final TextEditingController _guarantor = TextEditingController();
  final TextEditingController _notes = TextEditingController();

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

  Future<void> _submit(ContractDraft draft, Borrower? borrower) async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (borrower == null || draft.errors.isNotEmpty) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final router = GoRouter.of(context);
    try {
      final r = await ref
          .read(contractActionsProvider)
          .create(
            borrower: borrower,
            draft: draft,
            guarantor: _guarantor.text,
            notes: _notes.text,
            purpose: _purpose,
          );
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            r.outcome == WriteOutcome.queued
                ? 'Saved · will sync'
                : 'Loan created · ${formatInr(draft.netDisbursed)} disbursed',
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
      _leave('Only owners can create loans.');
      return const Scaffold(body: SizedBox.shrink());
    }
    // Keeps the company doc (cached nextLoanNo) loaded for the submit.
    ref.watch(activeCompanyProvider);
    final today = ref.watch(todayProvider);
    final draft = _terms.draft(today);
    final id = _borrowerId;
    final borrower = id == null ? null : ref.watch(borrowerProvider(id)).value;
    final margin = WindowSize.of(context).margin;

    return Scaffold(
      appBar: AppBar(title: const Text('New loan contract')),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
            child: ListView(
              key: const ValueKey<String>('create_contract_form'),
              padding: EdgeInsets.fromLTRB(
                margin,
                AppSpacing.md,
                margin,
                AppSpacing.xl,
              ),
              children: <Widget>[
                BorrowerCard(
                  borrower: borrower,
                  loading: id != null && borrower == null,
                  errorText: _submitted && borrower == null
                      ? 'Choose a borrower.'
                      : null,
                  onPicked: (String picked) =>
                      setState(() => _borrowerId = picked),
                ),
                _step('Step 1', 'Sanctioned principal'),
                LoanAmountFields(
                  terms: _terms,
                  draft: draft,
                  showAllErrors: _submitted,
                ),
                const SizedBox(height: AppSpacing.md),
                LoanSummaryCard(
                  sanctioned: draft.sanctioned ?? Money.zero,
                  upfront: draft.upfront,
                  net: draft.netDisbursed,
                ),
                _step('Step 2', 'Recovery schedule'),
                LoanScheduleFields(
                  terms: _terms,
                  draft: draft,
                  today: today,
                  showAllErrors: _submitted,
                ),
                _step('Optional', 'Agreement & security'),
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
                        onSelected: (bool on) =>
                            setState(() => _purpose = on ? p : null),
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
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _footer(draft, borrower),
    );
  }

  static final TextStyle _label = AppTextStyles.labelMd.copyWith(
    color: AppColors.textSecondary,
  );

  Widget _step(String step, String title) => Padding(
    padding: AppInsets.sectionHeader,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(step, style: _label),
        Text(title, style: AppTextStyles.headlineSm),
      ],
    ),
  );

  Widget _footer(ContractDraft draft, Borrower? borrower) {
    final cycles = draft.cycles;
    final inst = draft.installmentAmount;
    final outflow =
        'Outflow ${formatInr(draft.netDisbursed)}'
        '${cycles != null && inst != null ? ' · $cycles × ${formatInr(inst)}' : ''}';
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
                outflow,
                key: const ValueKey<String>('outflow_line'),
                style: AppTextStyles.labelLgTabular,
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _error!,
                  key: const ValueKey<String>('create_contract_error'),
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.overdue,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                key: const ValueKey<String>('create_contract_submit'),
                onPressed: _busy
                    ? null
                    : () => unawaited(_submit(draft, borrower)),
                child: _busy
                    ? const SizedBox.square(
                        dimension: AppSizes.iconSm,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text('Create & disburse loan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
