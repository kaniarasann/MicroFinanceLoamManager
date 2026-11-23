import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import '../contracts/contract_test_support.dart';
import 'payment_widget_harness.dart';

void main() {
  testWidgets('owner: ledger lists payments with Reverse', (
    WidgetTester t,
  ) async {
    await pumpPayments(t, initial: '/contracts/c1', height: 6000);
    expect(find.byKey(k('payment_ledger')), findsOneWidget);
    for (final id in <String>['tx-1', 'tx-2', 'tx-3', 'tx-4']) {
      expect(find.byKey(k('ledger_tx_$id')), findsOneWidget);
      expect(find.byKey(k('reverse_$id')), findsOneWidget);
    }
    expect(find.byKey(k('reverse_tx-d')), findsNothing);
  });

  testWidgets('collector: no Reverse action', (WidgetTester t) async {
    await pumpPayments(
      t,
      initial: '/contracts/c1',
      height: 6000,
      role: Role.collector,
    );
    expect(find.byKey(k('ledger_tx_tx-4')), findsOneWidget);
    expect(find.byKey(k('reverse_tx-4')), findsNothing);
  });

  testWidgets('reverse needs a reason, then the payment is struck through', (
    WidgetTester t,
  ) async {
    await pumpPayments(t, initial: '/contracts/c1', height: 6000);
    await tapKey(t, 'reverse_tx-4');
    await pumpFrames(t);
    expect(find.byKey(k('reverse_dialog')), findsOneWidget);
    FilledButton confirm() =>
        t.widget<FilledButton>(find.byKey(k('reverse_confirm')));
    expect(confirm().onPressed, isNull);
    await t.enterText(find.byKey(k('reverse_reason')), 'Duplicate entry');
    await t.pump();
    expect(confirm().onPressed, isNotNull);
    await t.tap(find.byKey(k('reverse_confirm')));
    await settleWrites(t);
    await settleWrites(t);
    expect(find.byKey(k('reverse_dialog')), findsNothing);
    expect(find.byKey(k('reversed_tx-4')), findsOneWidget);
    expect(find.text('Duplicate entry'), findsOneWidget);
    expect(find.byKey(k('reverse_tx-4')), findsNothing);
    final amount = t.widget<Text>(
      find.descendant(
        of: find.byKey(k('ledger_amount_tx-4')),
        matching: find.byType(Text),
      ),
    );
    expect(amount.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('excess collected banner asks to reverse the duplicate', (
    WidgetTester t,
  ) async {
    final seed = stitchSeed();
    seed.transactions.add(
      txFor(seed.contracts.single, 'tx-x', 70000, d(2023, 12, 1)),
    );
    await pumpPayments(t, initial: '/contracts/c1', seed: seed);
    expect(
      find.text(
        'Excess collected ₹6,000. Review and reverse the duplicate payment.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('rollover links both ways', (WidgetTester t) async {
    final seed = stitchSeed();
    final old = seed.contracts.single;
    seed.contracts
      ..clear()
      ..add(
        old.copyWith(
          status: ContractStatus.rolledOver,
          rolledOverToContractId: 'c2',
        ),
      )
      ..add(old.copyWith(id: 'c2', loanNo: 7, rolledOverFromContractId: 'c1'));
    await pumpPayments(t, initial: '/contracts/c1', seed: seed);
    expect(find.text('Rolled over → Loan #07'), findsOneWidget);
    await t.tap(find.byKey(k('rolled_over_to')));
    await pumpFrames(t);
    expect(find.text('Rolled over from Loan #04'), findsOneWidget);
  });
}
