import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/widgets/currency_field.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('typing 100000 shows 1,00,000 and reports Money', (
    WidgetTester tester,
  ) async {
    final values = <Money?>[];
    await pumpThemed(
      tester,
      Padding(
        padding: const EdgeInsets.all(16),
        child: CurrencyField(onChanged: values.add),
      ),
    );

    await tester.enterText(find.byType(TextField), '100000');
    await tester.pump();

    expect(find.text('1,00,000'), findsOneWidget);
    expect(values.last, const Money.fromRupees(100000));
    expect(find.text('₹'), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.style!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('decimals and clearing', (WidgetTester tester) async {
    final values = <Money?>[];
    await pumpThemed(
      tester,
      Padding(
        padding: const EdgeInsets.all(16),
        child: CurrencyField(onChanged: values.add),
      ),
    );

    await tester.enterText(find.byType(TextField), '1234567.5');
    await tester.pump();
    expect(find.text('12,34,567.5'), findsOneWidget);
    expect(values.last, const Money(123456750));

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(values.last, isNull);
  });

  test('formatter rejects invalid edits and groups live', () {
    const f = IndianGroupingFormatter();
    TextEditingValue edit(String old, String next) => f.formatEditUpdate(
      TextEditingValue(text: old),
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      ),
    );

    expect(edit('', '1').text, '1');
    expect(edit('1,000', '1,0000').text, '10,000');
    expect(edit('10,000', '10,0000').text, '1,00,000');
    expect(edit('1,234.5', '1,234.56').text, '1,234.56');
    expect(edit('1,234.56', '1,234.567').text, '1,234.56');
    expect(edit('12', '12a').text, '12');
    expect(edit('12', '12..').text, '12');
    expect(edit('', '007').text, '7');
    expect(edit('1,00,000', '1,00,000').selection.baseOffset, 8);
  });

  testWidgets('field is at least 56dp tall', (WidgetTester tester) async {
    await pumpThemed(
      tester,
      const Padding(padding: EdgeInsets.all(16), child: CurrencyField()),
    );
    expect(
      tester.getSize(find.byType(TextField)).height,
      greaterThanOrEqualTo(56),
    );
  });
}
