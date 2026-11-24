import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kpi_tile.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/ledger/ledger.dart';
import '../due_row_status.dart';

/// The four portfolio KPIs: Net disbursed, Sanctioned receivable, Total
/// collected and Total overdue. [columns] is 2 (2×2 on phones) or 4 (one
/// row on tablets).
class KpiGrid extends StatelessWidget {
  const KpiGrid({
    required this.metrics,
    required this.columns,
    this.onOverdueTap,
    super.key,
  });

  final PortfolioMetrics metrics;
  final int columns;
  final VoidCallback? onOverdueTap;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final loans = m.activeContractCount;
    final overdueLoans = m.overdueLoanCount;
    final tiles = <Widget>[
      KpiTile(
        key: const ValueKey<String>('kpi_net_disbursed'),
        label: 'Net disbursed',
        value: m.totalNetDisbursed,
        caption: loans == 1 ? '1 active loan' : '$loans active loans',
      ),
      KpiTile(
        key: const ValueKey<String>('kpi_receivable'),
        label: 'Sanctioned receivable',
        value: m.sanctionedReceivable,
        caption: 'Outstanding on active loans',
      ),
      KpiTile(
        key: const ValueKey<String>('kpi_collected'),
        label: 'Total collected',
        value: m.totalCollected,
        valueKind: StatusKind.collected,
        caption: 'Cash received, net of reversals',
      ),
      KpiTile(
        key: const ValueKey<String>('kpi_overdue'),
        label: 'Total overdue',
        value: m.totalOverdue,
        valueKind: m.totalOverdue.isPositive ? StatusKind.overdue : null,
        caption: overdueLoans == 0
            ? 'Nothing overdue'
            : '${overdueLoans == 1 ? '1 loan' : '$overdueLoans loans'} · '
                  'highest ${daysLate(m.maxDaysOverdue)}',
        onTap: onOverdueTap,
      ),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += columns) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.md));
      final cells = <Widget>[];
      for (var j = i; j < i + columns && j < tiles.length; j++) {
        if (cells.isNotEmpty) cells.add(const SizedBox(width: AppSpacing.md));
        cells.add(Expanded(child: tiles[j]));
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cells,
          ),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}
