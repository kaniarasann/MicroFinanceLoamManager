import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/payments/presentation/screens/record_payment_sheet.dart';
import 'package:nordic_ledger/features/rollover/presentation/screens/rollover_screen.dart';

import '../contracts/contract_test_support.dart';
import 'payment_widget_harness.dart';

// Stitch contract on 3 Dec 2023: ₹36,000 of ₹1,00,000 paid; inst 4 has
// ₹4,000 left, inst 5 ₹10,000 → Full due ₹4,000, Advance ₹14,000.
void main() {
  String confirmLabel(WidgetTester tester) {
    final b = tester.widget<FilledButton>(find.byKey(k('pay_confirm')));
    return ((b.child! as Text).data)!;
  }

  for (final width in <double>[400, 1200]) {
    final w = width.toInt();

    testWidgets('header, chips, helper and footer @$w', (WidgetTester t) async {
      await pumpPayments(t, width: width);
      expect(find.byKey(k('record_payment_sheet')), findsOneWidget);
      expect(find.text('Anita Sharma'), findsWidgets);
      expect(find.text('Outstanding ₹64,000'), findsOneWidget);
      expect(find.text('Full due ₹4,000'), findsOneWidget);
      expect(find.text('Advance ₹14,000'), findsOneWidget);
      expect(
        find.text('Short amounts are added to the end of the schedule.'),
        findsOneWidget,
      );
      expect(find.text('Works offline · syncs automatically'), findsOneWidget);
      expect(confirmLabel(t), 'Confirm & record ₹4,000 (UPI)');
      expect(find.text('After this: ₹60,000 outstanding'), findsOneWidget);
      // Compact = bottom sheet, wider = dialog.
      expect(find.byType(Dialog), width < 600 ? findsNothing : findsOneWidget);
      expect(
        find.byType(BottomSheet),
        width < 600 ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('Advance chip fills ₹14,000; Partial focuses the field', (
    WidgetTester t,
  ) async {
    await pumpPayments(t);
    await tapKey(t, 'chip_advance');
    expect(confirmLabel(t), 'Confirm & record ₹14,000 (UPI)');
    expect(find.text('After this: ₹50,000 outstanding'), findsOneWidget);
    await tapKey(t, 'chip_partial');
    final field = t.widget<TextField>(
      find.descendant(
        of: find.byKey(k('pay_amount')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('validation: ₹0 and above outstanding disable confirm', (
    WidgetTester t,
  ) async {
    await pumpPayments(t);
    await typeInto(t, 'pay_amount', '64001');
    expect(
      find.text('Amount cannot exceed the outstanding ₹64,000.'),
      findsOneWidget,
    );
    expect(
      t.widget<FilledButton>(find.byKey(k('pay_confirm'))).onPressed,
      isNull,
    );
    await typeInto(t, 'pay_amount', '0');
    expect(find.text('Amount must be more than ₹0.'), findsOneWidget);
    await typeInto(t, 'pay_amount', '64000');
    expect(
      find.text('After this: ₹0 outstanding · closes the loan'),
      findsOneWidget,
    );
    expect(
      t.widget<FilledButton>(find.byKey(k('pay_confirm'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('mode cards change the confirm label', (WidgetTester t) async {
    await pumpPayments(t);
    await tapKey(t, 'mode_cash');
    expect(confirmLabel(t), 'Confirm & record ₹4,000 (Cash)');
    await tapKey(t, 'mode_bank');
    expect(confirmLabel(t), 'Confirm & record ₹4,000 (Bank)');
  });

  testWidgets('rollover entry points: owner yes, collector no', (
    WidgetTester t,
  ) async {
    await pumpPayments(t, role: Role.collector);
    expect(find.byKey(k('pay_tab_toggle')), findsNothing);
    expect(find.byKey(k('rollover_card')), findsNothing);
  });

  testWidgets('owner: the Rollover segment opens the rollover screen', (
    WidgetTester t,
  ) async {
    await pumpPayments(t);
    expect(find.byKey(k('rollover_card')), findsOneWidget);
    await t.tap(find.text('Rollover'));
    await t.pump(const Duration(seconds: 1));
    await pumpFrames(t);
    expect(find.byType(RolloverScreen), findsOneWidget);
    expect(find.byType(RecordPaymentSheet), findsNothing);
  });

  testWidgets('confirm writes the payment, then offers the receipt', (
    WidgetTester t,
  ) async {
    final db = await pumpPayments(t);
    await tapKey(t, 'pay_confirm');
    await settleWrites(t);
    expect(find.byKey(k('receipt_panel')), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(
      find.text(
        'Received ₹4,000 from Anita Sharma for Loan #04 on 3 Dec 2023 via '
        'UPI. Balance: ₹60,000. — Sri Lakshmi Finance',
      ),
      findsOneWidget,
    );
    await tapKey(t, 'receipt_whatsapp');
    await settleWrites(t);
    expect(launchedUris.single.host, 'wa.me');
    expect(launchedUris.single.path, '/919812345678');
    final payments = await t.runAsync(
      () => db
          .collection('companies/$kCid/transactions')
          .where('type', isEqualTo: 'payment')
          .get(),
    );
    expect(payments!.docs, hasLength(5));
  });
}
