import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/features/calendar/presentation/screens/calendar_screen.dart';

import '../dashboard/dashboard_test_support.dart';

/// aggregatesFixture, today Tue 7 Nov 2023 (see dashboard_screen_test).
Future<void> pumpCalendar(
  WidgetTester tester, {
  required double width,
  double height = 2400,
  LaunchLog? launches,
  double textScale = 1,
}) => pumpLedgerScreen(
  tester,
  const CalendarScreen(),
  width: width,
  height: height,
  seed: aggregatesFixture(),
  launches: launches,
  textScale: textScale,
);

Finder inside(String key, String text) =>
    find.descendant(of: find.byKey(k(key)), matching: find.text(text));

void main() {
  for (final width in <double>[400, 1024]) {
    final w = width.toInt();
    testWidgets('month grid, dots, legend and today\'s list @$w', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(tester, width: width);
      expect(find.text('November 2023'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Tue, 7 Nov, today, 2 pending'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Thu, 9 Nov, nothing scheduled'),
        findsOneWidget,
      );
      expect(inside('legend_collected', '₹0'), findsOneWidget);
      expect(inside('legend_pending', '₹60,000'), findsOneWidget);
      expect(inside('legend_overdue', '₹0'), findsOneWidget);

      final agenda = find.byKey(k('day_agenda_2023-11-07'));
      expect(agenda, findsOneWidget);
      expect(
        find.descendant(
          of: agenda,
          matching: find.text('2 collections · ₹15,000'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(k('due_row_c1_2')), findsOneWidget);
      expect(find.byKey(k('due_row_c2_3')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('previous month: collected, overdue and the selected day', (
    WidgetTester tester,
  ) async {
    await pumpCalendar(tester, width: 400);
    await tester.tap(find.byKey(k('cal_prev')));
    await pumpFrames(tester);
    expect(find.text('October 2023'), findsOneWidget);
    expect(inside('legend_collected', '₹15,000'), findsOneWidget);
    expect(inside('legend_overdue', '₹5,000'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Tue, 31 Oct, collected ₹10,000, 1 overdue'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(k('cal_day_2023-10-31')));
    await pumpFrames(tester);
    final overdue = tester.getTopLeft(find.byKey(k('due_row_c2_2')));
    final paid = tester.getTopLeft(find.byKey(k('due_row_c1_1')));
    expect(overdue.dy, lessThan(paid.dy)); // open rows first
    expect(find.text('Overdue · 7 days late'), findsOneWidget);
    expect(find.text('Collected'), findsWidgets);
    // A collected row has no Record button.
    expect(find.byKey(k('due_record_c1_1')), findsNothing);
    expect(find.byKey(k('due_record_c2_2')), findsOneWidget);
  });

  testWidgets('back navigation stops at the 12-month history window', (
    WidgetTester tester,
  ) async {
    await pumpCalendar(tester, width: 400);
    for (var i = 0; i < 11; i++) {
      await tester.tap(find.byKey(k('cal_prev')));
      await tester.pump();
    }
    await pumpFrames(tester);
    expect(find.text('December 2022'), findsOneWidget);
    final prev = tester.widget<IconButton>(find.byKey(k('cal_prev')));
    expect(prev.onPressed, isNull);
  });

  testWidgets('List mode groups the month by day', (WidgetTester tester) async {
    await pumpCalendar(tester, width: 400, height: 4000);
    await tester.tap(find.text('List'));
    await pumpFrames(tester);
    expect(find.byKey(k('month_grid')), findsNothing);
    expect(find.byKey(k('day_agenda_2023-11-07')), findsOneWidget);
    expect(find.byKey(k('day_agenda_2023-11-28')), findsOneWidget);
    expect(find.byKey(k('day_agenda_2023-11-08')), findsNothing);
    expect(find.byKey(k('calendar_legend')), findsOneWidget);
  });

  testWidgets('expanded: grid | day list split; list headers select', (
    WidgetTester tester,
  ) async {
    await pumpCalendar(tester, width: 1024, height: 1600);
    final main = tester.getRect(find.byKey(k('calendar_main')));
    final detail = tester.getRect(find.byKey(k('calendar_detail')));
    expect(detail.left, greaterThanOrEqualTo(main.right));

    await tester.tap(find.byKey(k('cal_day_2023-11-14')));
    await pumpFrames(tester);
    expect(
      find.descendant(
        of: find.byKey(k('calendar_detail')),
        matching: find.byKey(k('day_agenda_2023-11-14')),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('List'));
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(k('calendar_main')),
        matching: find.text('Tue, 21 Nov'),
      ),
    );
    await pumpFrames(tester);
    expect(
      find.descendant(
        of: find.byKey(k('calendar_detail')),
        matching: find.byKey(k('day_agenda_2023-11-21')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Record and Call from the day list', (WidgetTester tester) async {
    final launches = LaunchLog();
    await pumpCalendar(tester, width: 400, launches: launches);
    await tester.tap(find.byKey(k('due_call_c2_3')));
    await pumpFrames(tester);
    expect(launches.launched.single.scheme, 'tel');
    await tester.tap(find.byKey(k('due_record_c2_3')));
    await pumpFrames(tester);
    expect(find.byKey(k('contract_pay_c2')), findsOneWidget);
  });

  for (final width in <double>[360, 1024]) {
    testWidgets('survives text scale 1.3 @${width.toInt()}', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(tester, width: width, textScale: 1.3, height: 3000);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('List'));
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
