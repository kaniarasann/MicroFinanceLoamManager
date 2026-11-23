import 'package:flutter/material.dart';

import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/ledger/ledger.dart';

/// Status pill for a borrower or contract [Standing]: Overdue Nd
/// (terracotta) / Due today (amber) / On track (sage) / No active loan.
class StandingPill extends StatelessWidget {
  const StandingPill({required this.standing, this.daysOverdue = 0, super.key});

  final Standing standing;
  final int daysOverdue;

  static String label(Standing standing, int daysOverdue) => switch (standing) {
    Standing.overdue => 'Overdue ${daysOverdue}d',
    Standing.dueToday => 'Due today',
    Standing.onTrack => 'On track',
    Standing.none => 'No active loan',
  };

  @override
  Widget build(BuildContext context) => StatusPill(
    label: label(standing, daysOverdue),
    kind: switch (standing) {
      Standing.overdue => StatusKind.overdue,
      Standing.dueToday => StatusKind.upcoming,
      Standing.onTrack => StatusKind.collected,
      Standing.none => StatusKind.neutral,
    },
    icon: switch (standing) {
      Standing.overdue => Icons.error_outline,
      Standing.dueToday => Icons.schedule,
      Standing.onTrack => Icons.check_circle_outline,
      Standing.none => null,
    },
  );
}
