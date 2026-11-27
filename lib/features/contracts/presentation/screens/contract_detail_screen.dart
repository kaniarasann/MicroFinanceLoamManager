import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../../domain/models/models.dart';
import '../../../company/application/company_providers.dart';
import '../../../payments/application/payment_providers.dart';
import '../../../payments/data/payment_repository.dart';
import '../../../payments/presentation/widgets/add_onboarding_payment_sheet.dart';
import '../../../payments/presentation/widgets/cancel_onboarded_dialog.dart';
import '../../../payments/presentation/widgets/payment_ledger_list.dart';
import '../../../payments/presentation/widgets/reverse_opening_dialog.dart';
import '../../../payments/presentation/widgets/reverse_payment_dialog.dart';
import '../../../rollover/presentation/widgets/rollover_link_banner.dart';
import '../../application/contract_providers.dart';
import '../../application/onboarding_resumer.dart';
import '../widgets/contract_header_card.dart';
import '../widgets/installment_row_card.dart';
import '../widgets/ledger_banner.dart';
import '../widgets/reschedule_sheet.dart';

/// `/contracts/{id}`: header, banners, the auto-extension note, filter
/// chips and the installment timeline (Stitch "7. Contract Installment
/// Schedule"). Expanded windows show the header left and the timeline
/// right. Owners and collectors.
class ContractDetailScreen extends ConsumerStatefulWidget {
  const ContractDetailScreen({required this.contractId, super.key});

  final String contractId;

  @override
  ConsumerState<ContractDetailScreen> createState() =>
      _ContractDetailScreenState();
}

class _ContractDetailScreenState extends ConsumerState<ContractDetailScreen> {
  TimelineFilter _filter = TimelineFilter.all;

  void _pay() =>
      unawaited(context.push<void>(AppRoutes.recordPayment(widget.contractId)));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(contractViewProvider(widget.contractId));
    final view = async.value;
    final Widget body;
    if (view != null) {
      body = _body(view);
    } else if (async.hasError) {
      body = const EmptyState(
        title: "Couldn't load this loan",
        message: 'Check your connection and try again.',
        icon: Icons.error_outline,
      );
    } else if (async.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = const EmptyState(
        title: 'Loan not found',
        message: 'It may have been removed or you no longer have access.',
        icon: Icons.search_off,
      );
    }
    final isOwner = ref.watch(currentRoleProvider) == Role.owner;
    final canReverseOpening =
        view != null &&
        isOwner &&
        canReverseIn(view.contract.status) &&
        unreversedOpeningBalance(view.snapshot).isNotEmpty;
    // F2: a cancelled loan whose onboarding payments are not all reversed
    // yet offers "Finish cancelling".
    final finishingCancel = view != null && isCancelUnfinished(view.snapshot);
    final canCancel =
        view != null &&
        isOwner &&
        view.contract.isOnboarded &&
        (view.contract.status == ContractStatus.active ||
            view.contract.status == ContractStatus.closed ||
            finishingCancel);
    final queuePending =
        ref
            .watch(onboardingQueueProvider(widget.contractId))
            .value
            ?.isPending ??
        false;
    return Scaffold(
      appBar: AppBar(
        title: Text(view == null ? 'Loan' : 'Loan schedule'),
        actions: <Widget>[
          if (canReverseOpening || canCancel)
            PopupMenuButton<String>(
              key: const ValueKey<String>('contract_menu'),
              tooltip: 'Loan options',
              icon: const Icon(Icons.more_vert),
              onSelected: (String v) => unawaited(
                v == 'cancel_onboarded'
                    ? showCancelOnboardedDialog(
                        context,
                        view: view,
                        queuePending: queuePending,
                      )
                    : showReverseOpeningDialog(context, view: view),
              ),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                if (canReverseOpening)
                  const PopupMenuItem<String>(
                    key: ValueKey<String>('reverse_opening_balance'),
                    value: 'reverse_opening',
                    child: Text('Reverse opening balance'),
                  ),
                if (canCancel)
                  PopupMenuItem<String>(
                    key: const ValueKey<String>('cancel_onboarded_loan'),
                    value: 'cancel_onboarded',
                    child: Text(
                      finishingCancel
                          ? 'Finish cancelling'
                          : 'Cancel onboarded loan',
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: view == null ? null : _footer(view),
    );
  }

  Widget _body(ContractView view) {
    final window = WindowSize.of(context);
    final margin = window.margin;
    final isOwner = ref.watch(currentRoleProvider) == Role.owner;
    // A cancelled loan collects nothing: no overdue / excess banners, no
    // auto-extension note or rows (attempt 6).
    final cancelled = view.contract.status == ContractStatus.cancelled;
    final summary = <Widget>[
      ContractHeaderCard(projection: view.projection),
      ..._links(view.contract),
      ..._onboardingSync(view, isOwner: isOwner),
      if (!cancelled) ..._banners(view.projection),
      if (cancelled) ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        const LedgerBanner(
          key: ValueKey<String>('cancelled_note'),
          text:
              'This loan is cancelled. Nothing is due or collected on it, '
              'and it is left out of the dashboard.',
          kind: StatusKind.neutral,
          icon: Icons.block,
        ),
      ] else ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        const LedgerBanner(
          key: ValueKey<String>('extension_note'),
          text:
              'Missed or partial amounts are added to the end automatically. '
              'Late payments remove them.',
          kind: StatusKind.info,
          icon: Icons.info_outline,
        ),
      ],
    ];
    final rows = <ProjectedRow>[
      for (final r in view.projection.rows)
        if (_filter.matches(r) && !(cancelled && r.isExtension)) r,
    ];
    final cycles = view.projection.rows.where(
      (ProjectedRow r) => r.countsAsCycle,
    );
    final last = cycles.isEmpty ? null : cycles.last;
    Widget rowCard(ProjectedRow r) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InstallmentRowCard(
        key: ValueKey<String>('row_${r.seq}'),
        row: r,
        view: view,
        isLast: identical(r, last),
        onCollect: view.contract.isActive ? _pay : null,
        onReschedule: view.contract.isActive && r.installmentId != null
            ? () => unawaited(showRescheduleSheet(context, view: view, row: r))
            : null,
      ),
    );
    final chips = _chips();
    final ledger = PaymentLedgerList(
      transactions: view.transactions,
      // Not on rolled-over / cancelled loans (the repository refuses too).
      canReverse: isOwner && canReverseIn(view.contract.status),
      onReverse: (LedgerTransaction tx) =>
          unawaited(showReversePaymentDialog(context, view: view, tx: tx)),
    );
    final empty = Padding(
      padding: AppInsets.emptyState,
      child: Text(
        'No ${_filter.label.toLowerCase()} installments.',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
      ),
    );

    if (window.isExpanded) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: WindowSize.maxContentWidth,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 2,
                child: ListView(
                  key: const ValueKey<String>('contract_summary_pane'),
                  padding: EdgeInsets.fromLTRB(
                    margin,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  children: <Widget>[...summary, ledger],
                ),
              ),
              Expanded(
                flex: 3,
                child: ListView(
                  key: const ValueKey<String>('contract_timeline_pane'),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    margin,
                    AppSpacing.lg,
                  ),
                  children: <Widget>[
                    chips,
                    const SizedBox(height: AppSpacing.md),
                    if (rows.isEmpty) empty,
                    for (final r in rows) rowCard(r),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      key: const ValueKey<String>('contract_timeline_pane'),
      padding: EdgeInsets.fromLTRB(
        margin,
        AppSpacing.md,
        margin,
        AppSpacing.lg,
      ),
      children: <Widget>[
        ...summary,
        const SizedBox(height: AppSpacing.lg),
        chips,
        const SizedBox(height: AppSpacing.md),
        if (rows.isEmpty) empty,
        for (final r in rows) rowCard(r),
        ledger,
      ],
    );
  }

  List<Widget> _links(Contract c) {
    final to = c.rolledOverToContractId;
    final from = c.rolledOverFromContractId;
    return <Widget>[
      if (to != null) ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        RolloverLinkBanner(linkedContractId: to, forward: true),
      ],
      if (from != null) ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        RolloverLinkBanner(linkedContractId: from, forward: false),
      ],
    ];
  }

  /// "Onboarding incomplete: X of Y payments synced" when fewer onboarding
  /// payments are on this device than the onboarding wrote, with the
  /// owner's "Add missing onboarding payment" action.
  List<Widget> _onboardingSync(ContractView view, {required bool isOwner}) {
    final sync = OnboardingSync.of(view.snapshot);
    if (view.contract.status == ContractStatus.cancelled) {
      if (!isCancelUnfinished(view.snapshot)) return const <Widget>[];
      final left = unreversedOnboardingPayments(view.snapshot).length;
      return <Widget>[
        const SizedBox(height: AppSpacing.md),
        LedgerBanner(
          key: const ValueKey<String>('cancel_unfinished_banner'),
          text:
              'Cancel not finished: $left onboarding '
              '${left == 1 ? 'payment is' : 'payments are'} not reversed yet.',
          kind: StatusKind.overdue,
          icon: Icons.report_outlined,
        ),
        if (isOwner) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const ValueKey<String>('finish_cancelling'),
            onPressed: () => unawaited(
              showCancelOnboardedDialog(
                context,
                view: view,
                queuePending: false,
              ),
            ),
            icon: const Icon(Icons.undo),
            label: const Text('Finish cancelling'),
          ),
        ],
      ];
    }
    if (sync == null) return const <Widget>[];
    final queue = ref.watch(onboardingQueueProvider(view.contract.id)).value;
    // F4: only an active loan is "finishing"; a pending list on a closed or
    // rolled-over loan falls back to the incomplete banner (+ repair where
    // valid).
    if (queue != null &&
        queue.isPending &&
        sync.isIncomplete &&
        view.contract.isActive) {
      // The sync list is still being written (an owner device resumes it
      // once batch 1 is on the server): not an error, no repair.
      return <Widget>[
        const SizedBox(height: AppSpacing.md),
        LedgerBanner(
          key: const ValueKey<String>('onboarding_finishing_banner'),
          text:
              'Finishing onboarding sync… ${sync.synced} of '
              '${sync.expected} payments. This completes automatically on '
              "an owner's phone when it is online.",
          kind: StatusKind.info,
          icon: Icons.cloud_sync_outlined,
        ),
      ];
    }
    if (sync.isOvershoot) {
      final over = sync.overshoot;
      final by = over.isPositive
          ? formatInr(over)
          : '${sync.synced - sync.expected} '
                '${sync.synced - sync.expected == 1 ? 'payment' : 'payments'}';
      return <Widget>[
        const SizedBox(height: AppSpacing.md),
        LedgerBanner(
          key: const ValueKey<String>('onboarding_overshoot_banner'),
          text:
              'Onboarding payments exceed what was onboarded by $by. '
              'Review and reverse the duplicate.',
          kind: StatusKind.overdue,
          icon: Icons.report_outlined,
        ),
      ];
    }
    if (!sync.isIncomplete) return const <Widget>[];
    final missing = sync.missing;
    final confirmed =
        ref
            .watch(contractTransactionsConfirmedProvider(view.contract.id))
            .value ??
        false;
    final cap = sync.repairCap(view.snapshot.outstanding);
    return <Widget>[
      const SizedBox(height: AppSpacing.md),
      LedgerBanner(
        key: const ValueKey<String>('onboarding_incomplete_banner'),
        text:
            'Onboarding incomplete: ${sync.synced} of ${sync.expected} '
            'payments synced'
            '${missing.isPositive ? ' · ${formatInr(missing)} missing' : ''}. '
            'Payments still queued on the phone that onboarded this loan '
            'will appear when it syncs. Check that phone first.',
        kind: StatusKind.upcoming,
        icon: Icons.sync_problem_outlined,
      ),
      if (isOwner && view.contract.isActive && cap.isPositive) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const ValueKey<String>('add_missing_onboarding_payment'),
          // Only on a server-confirmed snapshot: a cached view may simply
          // not have the other phone's batches yet.
          onPressed: confirmed
              ? () => unawaited(
                  showAddOnboardingPaymentSheet(context, view: view),
                )
              : null,
          icon: Icon(confirmed ? Icons.add : Icons.cloud_sync_outlined),
          label: Text(
            confirmed ? 'Add missing onboarding payment' : 'Waiting for sync…',
          ),
        ),
      ],
    ];
  }

  List<Widget> _banners(ContractProjection p) => <Widget>[
    if (p.hasOverdue) ...<Widget>[
      const SizedBox(height: AppSpacing.md),
      LedgerBanner(
        key: const ValueKey<String>('overdue_banner'),
        text:
            '${p.overdueCount} overdue '
            '${p.overdueCount == 1 ? 'installment' : 'installments'} · '
            '${formatInr(p.overdueAmount)} · ${p.maxDaysOverdue}d late',
        kind: StatusKind.overdue,
        icon: Icons.warning_amber_rounded,
      ),
    ],
    if (p.hasExcess) ...<Widget>[
      const SizedBox(height: AppSpacing.md),
      LedgerBanner(
        key: const ValueKey<String>('excess_banner'),
        text:
            'Excess collected ${formatInr(p.excess)}. Review and reverse '
            'the duplicate payment.',
        kind: StatusKind.upcoming,
        icon: Icons.report_outlined,
      ),
    ],
  ];

  Widget _chips() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: <Widget>[
        for (final f in TimelineFilter.values) ...<Widget>[
          ChoiceChip(
            key: ValueKey<String>('timeline_filter_${f.name}'),
            label: Text(f.label),
            selected: _filter == f,
            onSelected: (bool _) => setState(() => _filter = f),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ],
    ),
  );

  Widget? _footer(ContractView view) {
    final p = view.projection;
    if (!view.contract.isActive || p.isSettled) return null;
    final immediate = view.immediate;
    final next = p.nextDue;
    final label = immediate.isPositive
        ? 'Immediate action · Collect ${formatInr(immediate)}'
        : next == null
        ? 'Outstanding ${formatInr(p.outstanding)}'
        : 'Next due ${formatInr(next.remaining)} · '
              '${formatCivilDateDayMonth(next.dueDate)}';
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
                label,
                key: const ValueKey<String>('contract_footer_label'),
                style: AppTextStyles.labelLgTabular.copyWith(
                  color: immediate.isPositive && p.hasOverdue
                      ? AppColors.overdue
                      : AppColors.textPrimary,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                key: const ValueKey<String>('record_repayment'),
                onPressed: _pay,
                child: const Text('Record repayment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
