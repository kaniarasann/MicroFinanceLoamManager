// Tester — Sprint 5: the detail timeline for a missed fixture.
import 'package:flutter_test/flutter_test.dart';

import '../contract_test_support.dart';
import '../contract_widget_harness.dart';

/// ₹30,000 weekly ₹10,000 from Tue 31 Oct 2023, nothing paid.
/// Today Tue 14 Nov: inst 1 and 2 missed, inst 3 due today.
LedgerSeed _seed() {
  final c = contractFor(
    'b1',
    'm1',
    loanNo: 7,
    sanctionedRs: 30000,
    installmentRs: 10000,
    firstDue: d(2023, 10, 31),
  );
  return LedgerSeed()
    ..borrowers.add(anita())
    ..contracts.add(c);
}

void main() {
  testWidgets('missed rows auto-extend as "Installment N · Added"', (
    WidgetTester tester,
  ) async {
    await pumpContracts(
      tester,
      initial: '/contracts/m1',
      seed: _seed(),
      today: d(2023, 11, 14),
    );
    expect(find.text('Installment 4 · Added'), findsOneWidget);
    expect(find.text('Installment 5 · Added'), findsOneWidget);
    expect(find.text('Installment 6 · Added'), findsNothing);
    expect(find.text('Installment 1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('nothing missed (today = first due) → no extension rows', (
    WidgetTester tester,
  ) async {
    await pumpContracts(
      tester,
      initial: '/contracts/m1',
      seed: _seed(),
      today: d(2023, 10, 31),
    );
    expect(find.textContaining('· Added'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });
}
