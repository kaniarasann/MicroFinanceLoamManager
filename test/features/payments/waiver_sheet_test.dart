import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/borrowers/presentation/widgets/ledger_entry_tile.dart';

import '../contracts/contract_test_support.dart';
import 'payment_widget_harness.dart';

// Stitch contract on 3 Dec 2023: outstanding ₹64,000.
void main() {
  String confirmLabel(WidgetTester t) =>
      ((t.widget<FilledButton>(find.byKey(k('pay_confirm'))).child! as Text)
          .data)!;
  VoidCallback? confirmTap(WidgetTester t) =>
      t.widget<FilledButton>(find.byKey(k('pay_confirm'))).onPressed;

  testWidgets('Close loan chip fills the outstanding and switches the label', (
    WidgetTester t,
  ) async {
    await pumpPayments(t);
    expect(find.text('Close loan ₹64,000'), findsOneWidget);
    expect(confirmLabel(t), 'Confirm & record ₹4,000 (UPI)');
    await tapKey(t, 'chip_close');
    expect(find.text('64,000'), findsOneWidget);
    expect(confirmLabel(t), 'Confirm & close loan');
    expect(
      find.text('After this: ₹0 outstanding · closes the loan'),
      findsOneWidget,
    );
    // Back to Full due: the waive toggle goes away, the label returns.
    await tapKey(t, 'chip_full');
    expect(confirmLabel(t), 'Confirm & record ₹4,000 (UPI)');
    expect(find.byKey(k('waive_toggle')), findsNothing);
  });

  testWidgets('owner sees the waive toggle under Close loan; collector not', (
    WidgetTester t,
  ) async {
    await pumpPayments(t);
    expect(find.byKey(k('waive_toggle')), findsNothing);
    await tapKey(t, 'chip_close');
    expect(find.byKey(k('waive_toggle')), findsOneWidget);
    expect(find.text('Settle for less (waive the rest)'), findsOneWidget);
  });

  testWidgets('collector never sees the waive toggle', (WidgetTester t) async {
    await pumpPayments(t, role: Role.collector);
    await tapKey(t, 'chip_close');
    expect(confirmLabel(t), 'Confirm & close loan');
    expect(find.byKey(k('waive_toggle')), findsNothing);
  });

  testWidgets('waiver maths, required reason, then close with waiver', (
    WidgetTester t,
  ) async {
    final db = await pumpPayments(t);
    await tapKey(t, 'chip_close');
    await tapKey(t, 'waive_toggle');
    expect(find.text('Cash received'), findsOneWidget);
    await typeInto(t, 'pay_amount', '62000');
    expect(find.text('Waive ₹2,000'), findsOneWidget);
    expect(
      find.text('Cash ₹62,000 + waived ₹2,000 = closes the loan'),
      findsOneWidget,
    );
    expect(confirmLabel(t), 'Confirm & close loan');
    expect(confirmTap(t), isNull, reason: 'reason required');
    await typeInto(t, 'waive_reason', 'x');
    await typeInto(t, 'waive_reason', '');
    expect(find.text('Enter a reason for the waiver.'), findsOneWidget);
    expect(confirmTap(t), isNull);
    await typeInto(t, 'waive_reason', 'Early closure discount');
    expect(confirmTap(t), isNotNull);

    await tapKey(t, 'pay_confirm');
    await settleWrites(t);
    expect(find.byKey(k('receipt_panel')), findsOneWidget);
    expect(find.text('Loan closed · ₹2,000 waived'), findsOneWidget);
    final c = await t.runAsync(
      () => db.doc('companies/$kCid/contracts/c1').get(),
    );
    expect(c!.data()!['status'], 'closed');
    expect(c.data()!['totalWaivedPaise'], 200000);
    expect(c.data()!['totalPaidPaise'], 9800000);
  });

  testWidgets('cash at or above the outstanding is not a waiver', (
    WidgetTester t,
  ) async {
    await pumpPayments(t);
    await tapKey(t, 'chip_close');
    await tapKey(t, 'waive_toggle');
    await typeInto(t, 'pay_amount', '64000');
    expect(
      find.text(
        'Cash must be less than the outstanding ₹64,000 to waive the rest.',
      ),
      findsOneWidget,
    );
  });

  LedgerSeed waivedSeed() {
    final seed = stitchSeed();
    final c = seed.contracts.single;
    seed.transactions.add(
      txFor(
        c,
        'tx-w',
        2000,
        d(2023, 12, 1),
        type: TxType.waiver,
        mode: null,
      ).copyWith(note: 'Early closure'),
    );
    return seed;
  }

  testWidgets('ledger shows "Waived ₹W · reason" with Reverse; header total', (
    WidgetTester t,
  ) async {
    await pumpPayments(
      t,
      initial: '/contracts/c1',
      height: 6000,
      seed: waivedSeed(),
    );
    expect(find.text('Waived ₹2,000 · Early closure'), findsOneWidget);
    expect(find.byKey(k('reverse_tx-w')), findsOneWidget);
    expect(find.byKey(k('waived_line')), findsOneWidget);
    expect(find.text('Waived ₹2,000'), findsOneWidget);
    final amount = t.widget<Text>(
      find.descendant(
        of: find.byKey(k('ledger_amount_tx-w')),
        matching: find.byType(Text),
      ),
    );
    expect(amount.style?.color, isNot(AppColors.collected));
  });

  testWidgets('borrower ledger tile labels a waiver "Waived", not sage', (
    WidgetTester t,
  ) async {
    final c = stitchSeed().contracts.single;
    final w = txFor(c, 'tx-w', 2000, d(2023, 12, 1), type: TxType.waiver);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LedgerEntryTile(
            entry: LedgerEntry(tx: w, balanceAfter: Money.zero),
          ),
        ),
      ),
    );
    expect(find.textContaining('Waived ·'), findsOneWidget);
    expect(LedgerEntryTile.color(TxType.waiver), isNot(AppColors.collected));
  });
}
