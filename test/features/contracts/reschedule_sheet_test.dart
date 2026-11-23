import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import 'contract_test_support.dart';
import 'contract_widget_harness.dart';

void main() {
  Future<FakeFirebaseFirestore> open(
    WidgetTester tester, {
    double width = 400,
    Role role = Role.owner,
  }) async {
    final db = await pumpContracts(
      tester,
      initial: '/contracts/c1',
      width: width,
      seed: stitchSeed(),
      today: kStitchToday,
      role: role,
    );
    await tester.tap(find.byKey(k('reschedule_5')));
    await tester.pumpAndSettle();
    expect(find.byKey(k('reschedule_sheet')), findsOneWidget);
    return db;
  }

  FilledButton save(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(k('reschedule_save')));

  for (final width in <double>[400, 1200]) {
    testWidgets('defaults and validation @${width.toInt()}', (
      WidgetTester tester,
    ) async {
      await open(tester, width: width);
      expect(find.text('Reschedule installment 5'), findsOneWidget);
      // Amount defaults to the unpaid remainder; date to the next Tuesday.
      expect(find.text('10,000'), findsOneWidget);
      expect(find.text('Tue, 5 Dec 2023'), findsOneWidget);
      expect(save(tester).onPressed, isNotNull);

      await typeInto(tester, 'reschedule_amount', '12000');
      expect(
        find.text('Amount cannot exceed the unpaid ₹10,000.'),
        findsOneWidget,
      );
      expect(save(tester).onPressed, isNull);

      await typeInto(tester, 'reschedule_amount', '0');
      expect(find.text('Amount must be more than ₹0.'), findsOneWidget);
      expect(save(tester).onPressed, isNull);

      await typeInto(tester, 'reschedule_amount', '4000');
      expect(find.textContaining('Amount cannot'), findsNothing);
      expect(find.textContaining('Amount must'), findsNothing);
      expect(save(tester).onPressed, isNotNull);
    });
  }

  testWidgets('a collector saves one reschedule batch', (
    WidgetTester tester,
  ) async {
    final db = await open(tester, role: Role.collector);
    await typeInto(tester, 'reschedule_amount', '4000');
    await tester.enterText(find.byKey(k('reschedule_note')), 'Harvest');
    await tester.tap(find.byKey(k('reschedule_save')));
    await tester.pumpAndSettle();

    expect(find.byKey(k('reschedule_sheet')), findsNothing);
    expect(find.text('Installment rescheduled'), findsOneWidget);

    final snap = await tester.runAsync(
      () async => (
        await db.doc('companies/$kCid/installments/c1-i5').get(),
        await db
            .collection('companies/$kCid/installments')
            .where('kind', isEqualTo: 'rescheduled')
            .get(),
        await db
            .collection('companies/$kCid/transactions')
            .where('type', isEqualTo: 'reschedule')
            .get(),
      ),
    );
    final (src, moved, audit) = snap!;
    expect(src.data()!['rescheduledOutPaise'], 400000);
    expect(moved.docs, hasLength(1));
    final m = moved.docs.single.data();
    expect(m['amountDuePaise'], 400000);
    expect(m['dueDate'], '2023-12-05');
    expect(m['seq'], 11);
    expect(src.data()!['rescheduledToIds'], <String>[moved.docs.single.id]);
    expect(audit.docs.single.data()['amountPaise'], 0);
    expect(audit.docs.single.data()['note'], 'Harvest');

    // The timeline now shows the moved row and the rest still overdue.
    expect(find.text('Installment 11 · Moved'), findsOneWidget);
    expect(find.text('Moved from Inst. 5'), findsOneWidget);
    expect(find.text('₹4,000 moved to 5 Dec 2023'), findsOneWidget);
  });
}
