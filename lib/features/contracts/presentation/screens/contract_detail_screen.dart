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
import '../../../payments/presentation/widgets/payment_ledger_list.dart';
import '../../../payments/presentation/widgets/reverse_payment_dialog.dart';
import '../../../rollover/presentation/widgets/rollover_link_banner.dart';
import '../../application/contract_providers.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(view == null ? 'Loan' : 'Loan schedule')),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: view == null ? null : _footer(view),
    );
  }

  Widget _body(ContractView view) {
    final window = WindowSize.of(context);
    final margin = window.margin;
    final summary = <Widget>[
      ContractHeaderCard(projection: view.projection),
      ..._links(view.contract),
      ..._banners(view.projection),
      const SizedBox(height: AppSpacing.md),
      const LedgerBanner(
        key: ValueKey<String>('extension_note'),
        text:
            'Missed or partial amounts are added to the end automatically. '
            'Late payments remove them.',
        kind: StatusKind.info,
        icon: Icons.info_outline,
      ),
    ];
    final rows = <ProjectedRow>[
      for (final r in view.projection.rows)
        if (_filter.matches(r)) r,
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
    final isOwner = ref.watch(currentRoleProvider) == Role.owner;
    final ledger = PaymentLedgerList(
      transactions: view.transactions,
      canReverse: isOwner,
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
