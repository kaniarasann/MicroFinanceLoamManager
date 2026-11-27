import 'package:flutter/material.dart';

import '../../../../core/widgets/segmented_toggle.dart';

/// Which owner flow the New loan screen is in.
enum LoanKind { newLoan, existing }

/// "New loan · Existing loan" at the top of the New loan and onboarding
/// screens (owner only; both screens are owner only).
class LoanKindToggle extends StatelessWidget {
  const LoanKindToggle({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final LoanKind selected;
  final ValueChanged<LoanKind> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedToggle<LoanKind>(
    key: const ValueKey<String>('loan_kind_toggle'),
    expand: true,
    segments: const <ToggleSegment<LoanKind>>[
      ToggleSegment<LoanKind>(value: LoanKind.newLoan, label: 'New loan'),
      ToggleSegment<LoanKind>(value: LoanKind.existing, label: 'Existing loan'),
    ],
    selected: selected,
    onChanged: (LoanKind k) {
      if (k != selected) onChanged(k);
    },
  );
}
