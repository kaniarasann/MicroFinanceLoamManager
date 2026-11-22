import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/core/widgets/money_text.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('renders Indian-grouped amount with tabular figures', (
    WidgetTester tester,
  ) async {
    await pumpThemed(tester, const MoneyText(Money.fromRupees(2294000)));

    final text = tester.widget<Text>(find.text('₹22,94,000'));
    expect(
      text.style!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('adds tabular figures even to a non-tabular style', (
    WidgetTester tester,
  ) async {
    await pumpThemed(
      tester,
      const MoneyText(
        Money.fromRupees(150000),
        style: AppTextStyles.bodyMd,
        short: true,
      ),
    );

    final text = tester.widget<Text>(find.text('₹1.5L'));
    expect(
      text.style!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(text.style!.fontSize, AppTextStyles.bodyMd.fontSize);
  });
}
