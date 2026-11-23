import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/features/contracts/presentation/widgets/contract_header_card.dart';
import 'package:nordic_ledger/features/contracts/presentation/widgets/dashed_border_card.dart';

import 'contract_test_support.dart';
import 'contract_widget_harness.dart';

Finder _inRow(int seq, Finder f) =>
    find.descendant(of: find.byKey(k('row_$seq')), matching: f);

void main() {
  // The Stitch case, viewed Sun 3 Dec 2023: inst 1–3 paid, inst 4 paid
  // ₹6,000 of ₹10,000, inst 5 missed → Installment 11 + 12 added.
  Future<void> pumpStitch(WidgetTester tester, {double width = 400}) =>
      pumpContracts(
        tester,
        initial: '/contracts/c1',
        width: width,
        seed: stitchSeed(),
        today: kStitchToday,
      );

  for (final width in <double>[400, 1200]) {
    final w = width.toInt();

    testWidgets('header, banners and the Stitch timeline @$w', (
      WidgetTester tester,
    ) async {
      await pumpStitch(tester, width: width);
      expect(find.text('Anita Sharma'), findsOneWidget);
      expect(find.text('Loan #04 · Weekly · Shop stock'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('₹1,00,000'), findsWidgets);
      // The disbursement also appears in the ledger list (Sprint 6).
      expect(
        find.descendant(
          of: find.byType(ContractHeaderCard),
          matching: find.text('₹93,000'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(k('ledger_tx_tx-d')), findsOneWidget);
      expect(find.text('₹7,000'), findsOneWidget);
      expect(find.text('₹36,000 / ₹1,00,000 · 3/12 cycles'), findsOneWidget);
      expect(
        find.text('2 overdue installments · ₹14,000 · 12d late'),
        findsOneWidget,
      );
      expect(find.byKey(k('excess_banner')), findsNothing);
      expect(find.byKey(k('extension_note')), findsOneWidget);

      // Paid rows: mode chip and cleared date.
      expect(_inRow(1, find.text('UPI')), findsOneWidget);
      expect(_inRow(1, find.text('Cleared 31 Oct 2023')), findsOneWidget);
      expect(_inRow(3, find.text('Bank')), findsOneWidget);

      // Inst 4: partial and overdue.
      expect(_inRow(4, find.text('Partial · ₹4,000 short')), findsOneWidget);
      expect(_inRow(4, find.text('Paid ₹6,000 of ₹10,000')), findsOneWidget);
      expect(_inRow(4, find.text('Overdue by 12 days')), findsOneWidget);
      expect(_inRow(4, find.byKey(k('overdue_rail'))), findsOneWidget);
      // Inst 5: missed.
      expect(_inRow(5, find.text('Overdue by 5 days')), findsOneWidget);
      expect(_inRow(5, find.text('Collect ₹10,000')), findsOneWidget);
      expect(_inRow(5, find.text('Reschedule')), findsOneWidget);
      // Inst 6 (5 Dec) is due in 2 days.
      expect(_inRow(6, find.text('Due in 2 days')), findsOneWidget);

      // Extension rows, dashed, maturity on 12.
      expect(find.text('Installment 11 · Added'), findsOneWidget);
      expect(find.text('Installment 12 · Added'), findsOneWidget);
      expect(
        _inRow(11, find.text('Missed on 28 Nov (Inst. 5)')),
        findsOneWidget,
      );
      expect(
        _inRow(12, find.text('Partial on 21 Nov (Inst. 4)')),
        findsOneWidget,
      );
      expect(_inRow(11, find.byType(DashedBorderCard)), findsOneWidget);
      expect(_inRow(12, find.text('₹4,000')), findsOneWidget);
      expect(find.byKey(k('maturity_pill')), findsOneWidget);
      expect(_inRow(12, find.byKey(k('maturity_pill'))), findsOneWidget);

      expect(find.text('Immediate action · Collect ₹14,000'), findsOneWidget);
      expect(find.text('Record repayment'), findsOneWidget);
      if (width >= 840) {
        expect(find.byKey(k('contract_summary_pane')), findsOneWidget);
      } else {
        expect(find.byKey(k('contract_summary_pane')), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('filter chips: Missed / Upcoming / Paid / All', (
    WidgetTester tester,
  ) async {
    await pumpStitch(tester);
    Future<void> pick(String name) async {
      final chip = find.byKey(k('timeline_filter_$name'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();
    }

    Iterable<int> shown() => <int>[
      for (var s = 1; s <= 12; s++)
        if (find.byKey(k('row_$s')).evaluate().isNotEmpty) s,
    ];

    await pick('missed');
    expect(shown(), <int>[4, 5]);
    await pick('upcoming');
    expect(shown(), <int>[6, 7, 8, 9, 10, 11, 12]);
    await pick('paid');
    expect(shown(), <int>[1, 2, 3]);
    await pick('all');
    expect(shown(), <int>[for (var s = 1; s <= 12; s++) s]);
  });

  testWidgets('Collect and Record repayment open the /pay route', (
    WidgetTester tester,
  ) async {
    await pumpStitch(tester);
    await tester.tap(find.byKey(k('collect_5')));
    await pumpFrames(tester);
    expect(find.byKey(k('contract_pay_c1')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(k('record_repayment')));
    await pumpFrames(tester);
    expect(find.byKey(k('contract_pay_c1')), findsOneWidget);
  });

  testWidgets('an unknown contract shows "Loan not found"', (
    WidgetTester tester,
  ) async {
    await pumpContracts(tester, initial: '/contracts/nope');
    expect(find.text('Loan not found'), findsOneWidget);
  });

  testWidgets('360dp at 1.3× text: detail and create render without overflow', (
    WidgetTester tester,
  ) async {
    await pumpContracts(
      tester,
      initial: '/contracts/c1',
      width: 360,
      seed: stitchSeed(),
      today: kStitchToday,
      textScale: 1.3,
    );
    await tester.scrollUntilVisible(
      find.text('Installment 12 · Added'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('create form at 360dp, 1.3× text', (WidgetTester tester) async {
    await pumpContracts(
      tester,
      initial: '/contracts/new?borrowerId=b1',
      width: 360,
      seed: stitchSeed(),
      textScale: 1.3,
    );
    await typeInto(tester, 'sanctioned_field', '100000');
    await typeInto(tester, 'installment_field', '10000');
    expect(find.byKey(k('schedule_preview')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
