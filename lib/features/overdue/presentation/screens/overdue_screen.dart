import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/list_detail_layout.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../dashboard/application/portfolio_providers.dart';
import '../widgets/overdue_detail_pane.dart';
import '../widgets/overdue_loan_card.dart';
import '../widgets/overdue_summary_cards.dart';

/// `/overdue`: the overdue tracker. Totals (overdue ₹, loans, highest
/// delay, risk %), All / Critical (> 3 days) / Recent (1–3 days) chips and
/// one card per overdue loan with Call / WhatsApp / Record. Phones open the
/// loan on tap; expanded windows show it in a detail pane (40/60).
class OverdueScreen extends ConsumerStatefulWidget {
  const OverdueScreen({super.key});

  @override
  ConsumerState<OverdueScreen> createState() => _OverdueScreenState();
}

class _OverdueScreenState extends ConsumerState<OverdueScreen> {
  OverdueFilter _filter = OverdueFilter.all;
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(portfolioProvider);
    final metrics = metricsAsync.value;
    final loans = ref.watch(overdueLoansProvider);
    final split = WindowSize.of(context).isExpanded;
    final size = WindowSize.of(context);

    Widget body;
    if (metrics == null || loans == null) {
      body = metricsAsync.hasError
          ? const EmptyState(
              key: ValueKey<String>('overdue_error'),
              icon: Icons.cloud_off_outlined,
              title: "Couldn't load overdue loans",
            )
          : const Center(child: CircularProgressIndicator());
    } else {
      final summary = OverdueSummary.of(loans, _filter);
      final selected = split
          ? summary.loans.where((OverdueLoan l) => l.contractId == _selectedId)
          : const <OverdueLoan>[];
      final list = _list(summary, metrics.overdueRiskBps, split);
      body = ListDetailLayout(
        list: list,
        detail: selected.isEmpty
            ? null
            : OverdueDetailPane(
                loan: selected.first,
                rows: <OverdueItem>[
                  for (final r in metrics.overdueList.reversed)
                    if (r.contractId == selected.first.contractId) r,
                ],
              ),
        emptyDetail: const EmptyState(
          key: ValueKey<String>('overdue_detail_empty'),
          icon: Icons.touch_app_outlined,
          title: 'Select an overdue loan',
          message: 'Its missed installments and actions appear here.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Overdue tracker')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: WindowSize.maxContentWidth,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size.margin),
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _list(OverdueSummary s, int riskBps, bool split) {
    final labels = <OverdueFilter, String>{
      OverdueFilter.all: 'All (${s.allCount})',
      OverdueFilter.critical: 'Critical >3 days (${s.criticalCount})',
      OverdueFilter.recent: 'Recent 1–3 days (${s.recentCount})',
    };
    return ListView(
      key: const ValueKey<String>('overdue_list'),
      padding: AppInsets.pageBody,
      children: <Widget>[
        OverdueSummaryCards(summary: s, riskBps: riskBps),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final f in OverdueFilter.values)
              ChoiceChip(
                key: ValueKey<String>('overdue_filter_${f.name}'),
                label: Text(labels[f]!, style: AppTextStyles.labelMdTabular),
                selected: _filter == f,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (bool _) => setState(() => _filter = f),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (s.loans.isEmpty)
          EmptyState(
            key: const ValueKey<String>('overdue_empty'),
            icon: Icons.verified_outlined,
            title: s.allCount == 0
                ? 'Nothing overdue'
                : 'No loans in this filter',
            message: s.allCount == 0
                ? 'Every installment due before today is collected.'
                : null,
          )
        else
          for (final l in s.loans) ...<Widget>[
            OverdueLoanCard(
              loan: l,
              selected: split && l.contractId == _selectedId,
              onOpen: () => split
                  ? setState(() => _selectedId = l.contractId)
                  : unawaited(
                      context.push<void>(AppRoutes.contract(l.contractId)),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}
