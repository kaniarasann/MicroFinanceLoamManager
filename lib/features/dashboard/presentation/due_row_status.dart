import 'package:flutter/material.dart';

import '../../../core/widgets/status_pill.dart';
import '../../../domain/ledger/ledger.dart';
import '../../../domain/models/enums.dart';

/// Pill label, colour and icon of one schedule row. Colour is never the
/// only signal: every state has its own label.
({String label, StatusKind kind, IconData? icon}) dueRowStatus(
  DueRowItem item,
) {
  if (item.contractStatus == ContractStatus.rolledOver) {
    return (
      label: 'Settled by rollover',
      kind: StatusKind.collected,
      icon: Icons.check_circle_outline,
    );
  }
  if (item.isPaid) {
    return (
      label: 'Collected',
      kind: StatusKind.collected,
      icon: Icons.check_circle_outline,
    );
  }
  final partial = item.paid.isPositive;
  return switch (item.status) {
    RowStatus.overdue => (
      label: partial
          ? 'Partial · ${daysLate(item.daysOverdue)}'
          : 'Overdue · ${daysLate(item.daysOverdue)}',
      kind: StatusKind.overdue,
      icon: Icons.error_outline,
    ),
    RowStatus.dueToday => (
      label: partial ? 'Partial · due today' : 'Due today',
      kind: StatusKind.upcoming,
      icon: null,
    ),
    _ => (
      label: partial ? 'Partially paid' : 'Pending',
      kind: StatusKind.upcoming,
      icon: null,
    ),
  };
}

/// "1 day late" / "5 days late".
String daysLate(int days) => days == 1 ? '1 day late' : '$days days late';
