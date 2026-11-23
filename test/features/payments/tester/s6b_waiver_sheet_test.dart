import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import '../../contracts/contract_test_support.dart';
import '../payment_widget_harness.dart';

/// Tester S6 Task 12b (widgets): Stitch contract on 3 Dec 2023, outstanding
/// ₹64,000.
void main() {
  String confirmLabel(WidgetTester t) =>
      ((t.widget<FilledButton>(find.byKey(k('pay_confirm'))).child! as Text)
          .data)!;

  Future<List<Map<String, dynamic>>> txDocs(
    WidgetTester t,
    FakeFirebaseFirestore db,
  ) async {
    final q = await t.runAsync(
      () => db.collection('companies/$kCid/transactions').get(),
    );
    return <Map<String, dynamic>>[for (final d in q!.docs) d.data()];
  }

  for (final width in <double>[400, 1024]) {
    testWidgets('Close loan chip prefills ₹64,000 (width $width)', (
      WidgetTester t,
    ) async {
      await pumpPayments(t, width: width);
      expect(find.byKey(k('chip_close')), findsOneWidget);
      expect(find.text('Close loan ₹64,000'), findsOneWidget);
      await tapKey(t, 'chip_close');
      final field = t.widget<TextField>(
        find.descendant(
          of: find.byKey(k('pay_amount')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '64,000');
      expect(confirmLabel(t), 'Confirm & close loan');
    });
  }

  testWidgets('collector: Close loan chip, no waive switch; closes by cash', (
    WidgetTester t,
  ) async {
    final db = await pumpPayments(t, role: Role.collector);
    expect(find.text('Close loan ₹64,000'), findsOneWidget);
    await tapKey(t, 'chip_close');
    expect(find.byKey(k('waive_toggle')), findsNothing);
    expect(find.text('Settle for less (waive the rest)'), findsNothing);
    expect(find.byKey(k('waive_reason')), findsNothing);
    expect(confirmLabel(t), 'Confirm & close loan');

    await tapKey(t, 'pay_confirm');
    await settleWrites(t);
    final c = await t.runAsync(
      () => db.doc('companies/$kCid/contracts/c1').get(),
    );
    expect(c!.data()!['status'], 'closed');
    expect(c.data()!['totalWaivedPaise'] ?? 0, 0);
    final txs = await txDocs(t, db);
    expect(
      txs.where((Map<String, dynamic> x) => x['type'] == 'waiver'),
      isEmpty,
    );
  });

  testWidgets('owner full write-off: cash ₹0 + waive ₹64,000 closes', (
    WidgetTester t,
  ) async {
    final db = await pumpPayments(t);
    final before = (await txDocs(t, db)).length;
    await tapKey(t, 'chip_close');
    await tapKey(t, 'waive_toggle');
    await typeInto(t, 'pay_amount', '0');
    expect(find.text('Waive ₹64,000'), findsOneWidget);
    await typeInto(t, 'waive_reason', 'Borrower relocated, settled');
    expect(confirmLabel(t), 'Confirm & close loan');

    await tapKey(t, 'pay_confirm');
    await settleWrites(t);
    expect(find.byKey(k('receipt_panel')), findsOneWidget);
    expect(find.text('Loan closed · ₹64,000 waived'), findsOneWidget);

    final txs = await txDocs(t, db);
    expect(txs.length, before + 1, reason: 'only the waiver, no payment');
    final w = txs.singleWhere(
      (Map<String, dynamic> x) => x['type'] == 'waiver',
    );
    expect(w['amountPaise'], 6400000);
    expect(w['note'], 'Borrower relocated, settled');
    expect(w['mode'], isNull);
    final c = await t.runAsync(
      () => db.doc('companies/$kCid/contracts/c1').get(),
    );
    expect(c!.data()!['status'], 'closed');
    expect(c.data()!['totalWaivedPaise'], 6400000);
  });
}
