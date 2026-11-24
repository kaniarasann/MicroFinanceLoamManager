import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/time/today_provider.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../../domain/models/enums.dart';
import '../../../company/application/company_providers.dart';
import '../../application/portfolio_providers.dart';
import '../widgets/collections_chart.dart';
import '../widgets/due_today_list.dart';
import '../widgets/excess_review_card.dart';
import '../widgets/kpi_grid.dart';
import '../widgets/overdue_alert_card.dart';
import '../widgets/receivable_breakdown_card.dart';
import '../widgets/today_due_card.dart';

/// The Dashboard destination: KPIs (2×2 on phones, 4-up on tablets), the
/// overdue alert, the collections chart and receivable breakdown (8/4 on
/// tablets), today's due and the Due Today list. Every figure comes from
/// [portfolioProvider] (the offline cache through `lib/domain/ledger/`).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({this.onOpenCalendar, super.key});

  /// Switches the shell to the Calendar tab ("View schedule").
  final VoidCallback? onOpenCalendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(portfolioProvider);
    return metrics.when(
      skipLoadingOnReload: true,
      loading: () => const Center(
        key: ValueKey<String>('dashboard_loading'),
        child: CircularProgressIndicator(),
      ),
      error: (Object e, StackTrace _) => const EmptyState(
        key: ValueKey<String>('dashboard_error'),
        icon: Icons.cloud_off_outlined,
        title: "Couldn't load the dashboard",
        message: 'Check your access to this company and try again.',
      ),
      data: (PortfolioMetrics m) =>
          _DashboardBody(metrics: m, onOpenCalendar: onOpenCalendar),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.metrics, this.onOpenCalendar});

  final PortfolioMetrics metrics;
  final VoidCallback? onOpenCalendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = WindowSize.of(context);
    final isOwner = ref.watch(currentRoleProvider) == Role.owner;
    final today = ref.watch(todayProvider);
    void openOverdue() => unawaited(context.push<void>(AppRoutes.overdue));

    final m = metrics;
    final header = _Header(
      today: today,
      // On expanded windows the rail carries the "New loan" FAB.
      showNewLoan: isOwner && !size.isExpanded,
    );
    final kpis = KpiGrid(
      metrics: m,
      columns: size.tileColumns,
      onOverdueTap: openOverdue,
    );
    final alert = m.totalOverdue.isPositive
        ? OverdueAlertCard(metrics: m, onOpen: openOverdue)
        : null;
    final excess = m.excessToReview.isEmpty
        ? null
        : ExcessReviewCard(items: m.excessToReview, isOwner: isOwner);
    final chart = CollectionsChart(allowYear: !size.isCompact);
    final breakdown = ReceivableBreakdownCard(
      receivable: m.sanctionedReceivable,
      breakdown: m.receivableBreakdown,
      onViewOverdue: openOverdue,
    );
    final todayCard = TodayDueCard(todayDue: m.todayDue);
    final dueList = DueTodayList(
      items: m.todayDue.items,
      onViewSchedule: onOpenCalendar,
    );

    const gap = SizedBox(height: AppSpacing.md);
    final List<Widget> children;
    if (size.isExpanded) {
      children = <Widget>[
        header,
        kpis,
        gap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 8, child: chart),
            const SizedBox(width: AppSpacing.md),
            Expanded(flex: 4, child: breakdown),
          ],
        ),
        gap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 8, child: dueList),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  todayCard,
                  if (alert != null) ...<Widget>[gap, alert],
                  if (excess != null) ...<Widget>[gap, excess],
                ],
              ),
            ),
          ],
        ),
      ];
    } else {
      children = <Widget>[
        header,
        kpis,
        if (alert != null) ...<Widget>[gap, alert],
        if (excess != null) ...<Widget>[gap, excess],
        gap,
        chart,
        gap,
        breakdown,
        gap,
        todayCard,
        dueList,
      ];
    }

    return ListView(
      key: const ValueKey<String>('dashboard'),
      padding: AppInsets.pageBody,
      children: children,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.today, required this.showNewLoan});

  final CivilDate today;
  final bool showNewLoan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: const Text('Dashboard', style: AppTextStyles.headlineXl),
              ),
              Text(
                '${formatCivilDateWithWeekday(today)} ${today.year}',
                key: const ValueKey<String>('dashboard_date'),
                style: AppTextStyles.bodyMdTabular.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (showNewLoan)
            FilledButton.icon(
              key: const ValueKey<String>('dashboard_new_loan'),
              onPressed: () =>
                  unawaited(context.push<void>(AppRoutes.newContract())),
              icon: const Icon(Icons.add),
              label: const Text('New loan'),
            ),
        ],
      ),
    );
  }
}
