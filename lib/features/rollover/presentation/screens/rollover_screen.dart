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
import '../../../../core/widgets/empty_state.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../../domain/models/models.dart';
import '../../../company/application/company_providers.dart';
import '../../../contracts/application/contract_draft.dart';
import '../../../contracts/application/contract_providers.dart';
import '../../../contracts/application/loan_label.dart';
import '../../../contracts/presentation/widgets/loan_amount_fields.dart';
import '../../../contracts/presentation/widgets/loan_schedule_fields.dart';
import '../../../contracts/presentation/widgets/loan_terms_controller.dart';
import '../../application/rollover_providers.dart';
import '../../data/rollover_repository.dart';
import '../widgets/closing_contract_card.dart';
import '../widgets/rollover_settlement_card.dart';

/// `/contracts/{id}/rollover` (Stitch "6b. Rollover Breakdown"), owner
/// only: the closing contract, the new contract's terms, the settlement
/// (net cash handover) and the new schedule. On wider windows the form is
/// limited to the dialog width (560).
class RolloverScreen extends ConsumerStatefulWidget {
  const RolloverScreen({required this.contractId, super.key});

  final String contractId;

  @override
  ConsumerState<RolloverScreen> createState() => _RolloverScreenState();
}

class _RolloverScreenState extends ConsumerState<RolloverScreen> {
  LoanTermsController? _terms;
  bool _submitted = false;
  bool _busy = false;
  bool _leaving = false;
  String? _error;

  @override
  void dispose() {
    _terms
      ?..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  /// Prefilled from the old contract's terms (sanctioned, installment,
  /// frequency, collection day); the upfront starts empty.
  LoanTermsController _termsFor(Contract c) => _terms ??= LoanTermsController(
    sanctioned: c.sanctioned,
    installment: c.installmentAmount,
    frequency: c.frequency,
    weekday: c.preferredWeekday,
    monthDay: c.preferredMonthDay,
  )..addListener(_changed);

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
        context.go(AppRoutes.contract(widget.contractId));
      }
    });
  }

  Future<void> _confirm(
    ContractView view,
    ContractDraft draft,
    RolloverQuote quote,
  ) async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (draft.errors.isNotEmpty || !quote.isValid) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final router = GoRouter.of(context);
    try {
      final r = await ref
          .read(rolloverActionsProvider)
          .rollover(view: view, draft: draft);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            r.outcome == WriteOutcome.queued
                ? 'Saved · will sync'
                : 'Rolled over · ${formatInr(quote.netCash)} handed over',
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
    if (ref.watch(currentRoleProvider) == Role.collector) {
      _leave('Only owners can roll over loans.');
      return const Scaffold(body: SizedBox.shrink());
    }
    // Keeps the company doc (cached nextLoanNo) loaded for the submit.
    ref.watch(activeCompanyProvider);
    final async = ref.watch(contractViewProvider(widget.contractId));
    final view = async.value;
    if (view == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rollover')),
        body: async.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const EmptyState(
                title: 'Loan not found',
                message:
                    'It may have been removed or you no longer have '
                    'access.',
                icon: Icons.search_off,
              ),
      );
    }
    if (!view.contract.isActive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rollover')),
        body: const EmptyState(
          key: ValueKey<String>('rollover_not_active'),
          title: 'This loan is not active',
          message: 'Only an active loan can be rolled over.',
          icon: Icons.lock_outline,
        ),
      );
    }
    return _page(view);
  }

  Widget _page(ContractView view) {
    final today = ref.watch(todayProvider);
    final c = view.contract;
    final terms = _termsFor(c);
    final draft = terms.draft(today);
    final quote = computeRollover(
      oldProjection: view.projection,
      newSanctioned: draft.sanctioned ?? Money.zero,
      upfrontMode: draft.upfrontMode,
      upfrontInput: draft.upfrontInput ?? 0,
    );
    final margin = WindowSize.of(context).margin;
    final showNetError =
        quote.netCash.isNegative || (_submitted && !quote.isValid);
    return Scaffold(
      appBar: AppBar(title: Text('Roll over ${loanLabel(c.loanNo)}')),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.dialogMaxWidth,
            ),
            child: ListView(
              key: const ValueKey<String>('rollover_form'),
              padding: EdgeInsets.fromLTRB(
                margin,
                AppSpacing.md,
                margin,
                AppSpacing.xl,
              ),
              children: <Widget>[
                ClosingContractCard(projection: view.projection),
                _heading('New contract'),
                LoanAmountFields(
                  terms: terms,
                  draft: draft,
                  showAllErrors: _submitted,
                  sanctionedLabel: 'New sanctioned amount',
                ),
                const SizedBox(height: AppSpacing.md),
                RolloverSettlementCard(
                  newSanctioned: draft.sanctioned ?? Money.zero,
                  upfront: quote.newUpfront,
                  oldOutstanding: quote.settledOldOutstanding,
                  oldLoanNo: c.loanNo,
                  error: showNetError ? quote.error : null,
                ),
                _heading('New schedule'),
                LoanScheduleFields(
                  terms: terms,
                  draft: draft,
                  today: today,
                  showAllErrors: _submitted,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _footer(view, draft, quote),
    );
  }

  Widget _heading(String title) => Padding(
    padding: AppInsets.sectionHeader,
    child: Text(title, style: AppTextStyles.headlineSm),
  );

  Widget _footer(ContractView view, ContractDraft draft, RolloverQuote quote) {
    final cycles = draft.cycles;
    final inst = draft.installmentAmount;
    final net = quote.netCash.isNegative ? Money.zero : quote.netCash;
    final outflow =
        'Outflow ${formatInr(net)}'
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
                key: const ValueKey<String>('rollover_outflow'),
                style: AppTextStyles.labelLgTabular,
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _error!,
                  key: const ValueKey<String>('rollover_error'),
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.overdue,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                key: const ValueKey<String>('rollover_confirm'),
                onPressed: _busy || !quote.isValid
                    ? null
                    : () => unawaited(_confirm(view, draft, quote)),
                child: _busy
                    ? const SizedBox.square(
                        dimension: AppSizes.iconSm,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text('Confirm rollover'),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Works offline · syncs automatically',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
