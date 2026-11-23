import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import 'contract_test_support.dart';
import 'contract_widget_harness.dart';

LedgerSeed _oneBorrower() => LedgerSeed()..borrowers.add(anita());

void main() {
  // Today: Tue 7 Nov 2023 (fixtureClock).
  const newLoan = '/contracts/new?borrowerId=b1';

  for (final width in <double>[400, 1200]) {
    final w = width.toInt();

    testWidgets('live net / effective %: flat then percent @$w', (
      WidgetTester tester,
    ) async {
      await pumpContracts(
        tester,
        initial: newLoan,
        width: width,
        seed: _oneBorrower(),
      );
      expect(find.text('Anita Sharma'), findsOneWidget);
      expect(find.text('New loan contract'), findsOneWidget);

      await typeInto(tester, 'sanctioned_field', '100000');
      await typeInto(tester, 'upfront_flat_field', '7000');
      expect(find.text('₹93,000'), findsOneWidget);
      expect(find.text('₹7,000'), findsOneWidget);
      expect(find.text('7.0% effective'), findsOneWidget);
      expect(
        find.textContaining('repays the full sanctioned ₹1,00,000'),
        findsOneWidget,
      );

      await tester.tap(find.text('Percentage %'));
      await tester.pump();
      await typeInto(tester, 'upfront_pct_field', '7.5');
      expect(find.text('₹7,500'), findsOneWidget);
      expect(find.text('₹92,500'), findsOneWidget);
      expect(find.text('7.5% effective'), findsOneWidget);
      expect(find.text('Outflow ₹92,500'), findsOneWidget);
    });

    testWidgets('weekday / day pickers per frequency @$w', (
      WidgetTester tester,
    ) async {
      await pumpContracts(tester, initial: newLoan, width: width);
      // Weekly by default, today's weekday (Tue) pre-selected.
      expect(find.byKey(k('weekday_picker')), findsOneWidget);
      expect(
        tester.widget<ChoiceChip>(find.byKey(k('weekday_2'))).selected,
        isTrue,
      );
      expect(find.textContaining('Tue, 14 Nov 2023'), findsOneWidget);
      await tester.tap(find.byKey(k('weekday_5')));
      await tester.pump();
      expect(find.textContaining('Fri, 10 Nov 2023'), findsOneWidget);

      await tester.tap(find.text('Monthly'));
      await tester.pump();
      expect(find.byKey(k('weekday_picker')), findsNothing);
      expect(find.byKey(k('month_day_picker')), findsOneWidget);
      expect(find.text('Day 7'), findsOneWidget); // today's day
      expect(find.textContaining('Thu, 7 Dec 2023'), findsOneWidget);

      await tester.tap(find.text('Daily'));
      await tester.pump();
      expect(find.byKey(k('month_day_picker')), findsNothing);
      expect(find.byKey(k('daily_note')), findsOneWidget);
      expect(find.textContaining('Wed, 8 Nov 2023'), findsOneWidget);
    });
  }

  testWidgets('cycles, maturity and preview rows', (WidgetTester tester) async {
    await pumpContracts(tester, initial: newLoan, seed: _oneBorrower());
    expect(find.byKey(k('schedule_preview')), findsNothing);
    await typeInto(tester, 'sanctioned_field', '100000');
    await typeInto(tester, 'installment_field', '30000');
    expect(find.text('4 cycles'), findsOneWidget);
    expect(find.byKey(k('preview_row_1')), findsOneWidget);
    expect(find.byKey(k('preview_row_3')), findsOneWidget);
    expect(find.byKey(k('preview_row_4')), findsNothing);
    expect(find.text('₹30,000'), findsNWidgets(3));
    expect(find.text('+1 more · Maturity 5 Dec 2023'), findsOneWidget);
    expect(find.text('Maturity 5 Dec 2023'), findsOneWidget);
    expect(find.text('Outflow ₹1,00,000 · 4 × ₹30,000'), findsOneWidget);
  });

  testWidgets('inline errors from validateContractTerms', (
    WidgetTester tester,
  ) async {
    await pumpContracts(tester, initial: '/contracts/new');
    await tester.tap(find.byKey(k('create_contract_submit')));
    await tester.pump();
    expect(find.text('Choose a borrower.'), findsOneWidget);
    expect(
      find.text('Sanctioned amount must be more than ₹0.'),
      findsOneWidget,
    );
    expect(
      find.text('Installment amount must be more than ₹0.'),
      findsOneWidget,
    );

    await typeInto(tester, 'sanctioned_field', '10000');
    await typeInto(tester, 'upfront_flat_field', '10000');
    expect(
      find.text('Upfront interest must be less than the sanctioned amount.'),
      findsOneWidget,
    );
    await typeInto(tester, 'installment_field', '20000');
    expect(
      find.text('Installment amount cannot exceed the sanctioned amount.'),
      findsOneWidget,
    );
  });

  testWidgets('create & disburse: one batch, then the contract page', (
    WidgetTester tester,
  ) async {
    final db = await pumpContracts(
      tester,
      initial: newLoan,
      seed: _oneBorrower(),
    );
    await typeInto(tester, 'sanctioned_field', '100000');
    await typeInto(tester, 'upfront_flat_field', '7000');
    await typeInto(tester, 'installment_field', '10000');
    await tester.tap(find.byKey(k('purpose_Shop stock')));
    await tester.pump();
    await tester.tap(find.byKey(k('create_contract_submit')));
    await pumpFrames(tester);

    final contracts = await tester.runAsync(
      () => db.collection('companies/$kCid/contracts').get(),
    );
    expect(contracts!.docs, hasLength(1));
    final c = contracts.docs.single.data();
    expect(c['loanNo'], 4); // cached nextLoanNo 3 + 1
    expect(c['netDisbursedPaise'], 9300000);
    expect(c['firstDueDate'], '2023-11-14');
    expect(c['purpose'], 'Shop stock');
    expect(find.text('Loan created · ₹93,000 disbursed'), findsOneWidget);
    expect(find.text('Loan schedule'), findsOneWidget);
    expect(find.text('Installment 10'), findsOneWidget);
  });

  testWidgets('a collector is sent away', (WidgetTester tester) async {
    await pumpContracts(tester, initial: newLoan, role: Role.collector);
    await pumpFrames(tester);
    expect(find.text('Home'), findsOneWidget);
    expect(find.byKey(k('create_contract_form')), findsNothing);
    expect(find.text('Only owners can create loans.'), findsOneWidget);
  });
}
