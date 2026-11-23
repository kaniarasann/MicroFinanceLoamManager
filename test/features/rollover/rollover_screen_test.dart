import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/contracts/presentation/screens/contract_detail_screen.dart';
import 'package:nordic_ledger/features/rollover/presentation/screens/rollover_screen.dart';

import '../contracts/contract_test_support.dart';
import '../payments/payment_widget_harness.dart';

// Stitch contract on 3 Dec 2023: ₹64,000 outstanding on Loan #04.
void main() {
  Text textOf(WidgetTester t, String key) => t.widget<Text>(
    find.descendant(of: find.byKey(k(key)), matching: find.byType(Text)),
  );

  bool confirmEnabled(WidgetTester t) =>
      t.widget<FilledButton>(find.byKey(k('rollover_confirm'))).onPressed !=
      null;

  for (final width in <double>[400, 1200]) {
    final w = width.toInt();
    testWidgets('closing card, settlement maths and footer @$w', (
      WidgetTester t,
    ) async {
      await pumpPayments(t, initial: '/contracts/c1/rollover', width: width);
      expect(find.byType(RolloverScreen), findsOneWidget);
      expect(find.byKey(k('closing_contract_card')), findsOneWidget);
      expect(textOf(t, 'closing_outstanding').data, '₹64,000');
      expect(
        find.text('Loan #04 will close as Rolled over. Full history is kept.'),
        findsOneWidget,
      );
      // Prefilled ₹1,00,000, no upfront yet → ₹36,000.
      expect(textOf(t, 'settle_net').data, '₹36,000');
      await typeInto(t, 'upfront_flat_field', '7000');
      expect(textOf(t, 'settle_upfront').data, '₹7,000');
      expect(textOf(t, 'settle_old').data, '₹64,000');
      expect(textOf(t, 'settle_net').data, '₹29,000');
      expect(find.text('Outflow ₹29,000 · 10 × ₹10,000'), findsOneWidget);
      expect(find.byKey(k('schedule_preview')), findsOneWidget);
      expect(confirmEnabled(t), isTrue);
    });
  }

  testWidgets('a new loan that does not cover the old balance is invalid', (
    WidgetTester t,
  ) async {
    await pumpPayments(t, initial: '/contracts/c1/rollover');
    await typeInto(t, 'sanctioned_field', '70000');
    await typeInto(t, 'upfront_flat_field', '7000');
    expect(textOf(t, 'settle_net').data, '−₹1,000');
    expect(find.byKey(k('settle_invalid')), findsOneWidget);
    expect(
      find.textContaining(
        'New loan must cover the old balance and upfront interest.',
      ),
      findsOneWidget,
    );
    expect(confirmEnabled(t), isFalse);
  });

  testWidgets('confirm rolls over and opens the new loan', (
    WidgetTester t,
  ) async {
    final db = await pumpPayments(t, initial: '/contracts/c1/rollover');
    await typeInto(t, 'upfront_flat_field', '7000');
    await t.tap(find.byKey(k('rollover_confirm')));
    await settleWrites(t);
    await settleWrites(t);
    final old = await t.runAsync(
      () => db.doc('companies/$kCid/contracts/c1').get(),
    );
    expect(old!.data()!['status'], 'rolledOver');
    final newId = old.data()!['rolledOverToContractId'] as String;
    final detail = t.widget<ContractDetailScreen>(
      find.byType(ContractDetailScreen).last,
    );
    expect(detail.contractId, newId);
    expect(find.byKey(k('rolled_over_from')), findsOneWidget);
    expect(find.text('Rolled over from Loan #04'), findsOneWidget);
  });

  testWidgets('a collector is sent back', (WidgetTester t) async {
    await pumpPayments(
      t,
      initial: '/contracts/c1/rollover',
      role: Role.collector,
    );
    await pumpFrames(t);
    expect(find.byKey(k('rollover_form')), findsNothing);
  });
}
