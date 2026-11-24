import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/calendar/presentation/screens/calendar_screen.dart';

import '../../dashboard/dashboard_test_support.dart';
import '../../dashboard/tester/s7_tester_support.dart';

/// s7Seed, today Tue 7 Nov 2023:
/// - 24 Oct: c2 #1 paid (sage);
/// - 31 Oct: c1 #1 paid (sage) + c2 #2 overdue (terracotta);
/// - 7 Nov: c1 #2 paid today (sage) + c2 #3 due today (amber);
/// - 14 Nov: c1 #3 + c2 #4 upcoming (amber); 9 Nov: nothing.
Future<void> pumpCal(
  WidgetTester tester, {
  double width = 400,
  double height = 2600,
  Role role = Role.owner,
  double textScale = 1,
  LedgerSeed? seed,
}) => pumpLedgerScreen(
  tester,
  const CalendarScreen(),
  width: width,
  height: height,
  role: role,
  seed: seed ?? s7Seed(),
  textScale: textScale,
);

/// Colours of the status dots in one day cell.
Set<Color> dots(WidgetTester tester, String date) {
  final status = <Color>{
    AppColors.collected,
    AppColors.upcoming,
    AppColors.overdue,
  };
  final out = <Color>{};
  for (final c in tester.widgetList<Container>(
    find.descendant(
      of: find.byKey(k('cal_day_$date')),
      matching: find.byType(Container),
    ),
  )) {
    final deco = c.decoration;
    if (deco is BoxDecoration &&
        deco.shape == BoxShape.circle &&
        status.contains(deco.color)) {
      out.add(deco.color!);
    }
  }
  return out;
}

Finder inKey(String key, String text) =>
    find.descendant(of: find.byKey(k(key)), matching: find.text(text));

void main() {
  testWidgets('S7-C1 dot colours per day', (WidgetTester tester) async {
    await pumpCal(tester);
    expect(dots(tester, '2023-11-07'), <Color>{
      AppColors.collected,
      AppColors.upcoming,
    });
    expect(dots(tester, '2023-11-14'), <Color>{AppColors.upcoming});
    expect(dots(tester, '2023-11-09'), isEmpty);
    await tester.tap(find.byKey(k('cal_prev')));
    await pumpFrames(tester);
    expect(dots(tester, '2023-10-31'), <Color>{
      AppColors.collected,
      AppColors.overdue,
    });
    expect(dots(tester, '2023-10-24'), <Color>{AppColors.collected});
    // c2 #1 ₹5,000 plus the settled rows of the closed c7 (₹5,000) and the
    // rolled-over c8 (₹10,000).
    expect(
      find.bySemanticsLabel('Tue, 24 Oct, collected ₹20,000'),
      findsOneWidget,
    );
  });

  testWidgets('S7-C2 legend totals equal the day lists (October)', (
    WidgetTester tester,
  ) async {
    await pumpCal(tester, height: 4000);
    await tester.tap(find.byKey(k('cal_prev')));
    await pumpFrames(tester);
    // Legend: collected ₹45,000 = active 24 Oct ₹5,000 + 31 Oct ₹10,000,
    // plus history rows (c7 closed: 2 × ₹5,000; c8 rolled over:
    // 2 × ₹10,000); overdue ₹5,000.
    expect(inKey('legend_collected', '₹45,000'), findsOneWidget);
    expect(inKey('legend_pending', '₹0'), findsOneWidget);
    expect(inKey('legend_overdue', '₹5,000'), findsOneWidget);
    await tester.tap(find.text('List'));
    await pumpFrames(tester);
    expect(
      inKey('day_agenda_2023-10-24', '3 collections · ₹20,000'),
      findsOneWidget,
    );
    expect(
      inKey('day_agenda_2023-10-31', '4 collections · ₹30,000'),
      findsOneWidget,
    );
    // Only the open overdue row takes a payment; settled and history rows
    // (closed c7, rolled-over c8) have no Record.
    expect(find.byKey(k('due_record_c2_2')), findsOneWidget);
    expect(find.byKey(k('due_record_c7_1')), findsNothing);
    expect(find.byKey(k('due_record_c8_2')), findsNothing);
    expect(find.text('Settled by rollover'), findsNWidgets(2));
    expect(find.byKey(k('due_record_c1_1')), findsNothing);
    expect(find.byKey(k('due_record_c2_1')), findsNothing);
  });

  testWidgets('S7-C3 Month / List toggle', (WidgetTester tester) async {
    await pumpCal(tester, height: 4000);
    expect(find.byKey(k('month_grid')), findsOneWidget);
    await tester.tap(find.text('List'));
    await pumpFrames(tester);
    expect(find.byKey(k('month_grid')), findsNothing);
    expect(find.byKey(k('day_agenda_2023-11-07')), findsOneWidget);
    expect(find.byKey(k('day_agenda_2023-11-09')), findsNothing);
    await tester.tap(find.text('Month'));
    await pumpFrames(tester);
    expect(find.byKey(k('month_grid')), findsOneWidget);
  });

  testWidgets('S7-C4 forward navigation stops 12 months ahead', (
    WidgetTester tester,
  ) async {
    await pumpCal(tester);
    for (var i = 0; i < 12; i++) {
      await tester.tap(find.byKey(k('cal_next')));
      await tester.pump();
    }
    await pumpFrames(tester);
    expect(find.text('November 2024'), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byKey(k('cal_next'))).onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(find.byKey(k('cal_prev'))).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('S7-C5 an empty day', (WidgetTester tester) async {
    await pumpCal(tester);
    await tester.tap(find.byKey(k('cal_day_2023-11-09')));
    await pumpFrames(tester);
    expect(inKey('day_agenda_2023-11-09', 'Nothing scheduled'), findsOneWidget);
    expect(
      find.text('No collections are scheduled for this day.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Thu, 9 Nov, nothing scheduled'),
      findsOneWidget,
    );
  });

  testWidgets('S7-C6 empty month in list mode', (WidgetTester tester) async {
    await pumpCal(tester, seed: LedgerSeed());
    await tester.tap(find.text('List'));
    await pumpFrames(tester);
    expect(find.byKey(k('calendar_list_empty')), findsOneWidget);
  });

  testWidgets('S7-C7 collector sees the calendar with Record', (
    WidgetTester tester,
  ) async {
    await pumpCal(tester, role: Role.collector);
    expect(find.byKey(k('month_grid')), findsOneWidget);
    expect(find.byKey(k('due_record_c2_3')), findsOneWidget);
  });

  testWidgets('S7-C8 tablet 1024 uses the grid | day-list split', (
    WidgetTester tester,
  ) async {
    await pumpCal(tester, width: 1024, height: 1400);
    final main = tester.getRect(find.byKey(k('calendar_main')));
    final detail = tester.getRect(find.byKey(k('calendar_detail')));
    expect(detail.left, greaterThanOrEqualTo(main.right));
    expect(
      find.descendant(
        of: find.byKey(k('calendar_detail')),
        matching: find.byKey(k('day_agenda_2023-11-07')),
      ),
      findsOneWidget,
    );
  });

  for (final width in <double>[360, 1024]) {
    testWidgets('S7-C9 text scale 1.3 @${width.toInt()} month, list and '
        'previous month', (WidgetTester tester) async {
      await pumpCal(tester, width: width, height: 3600, textScale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(k('cal_prev')));
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('List'));
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S7-C10 a closed / rolled-over loan stays on past months', (
    WidgetTester tester,
  ) async {
    await pumpCal(tester);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(k('cal_prev')));
      await pumpFrames(tester);
    }
    expect(find.text('September 2023'), findsOneWidget);
    // c3 Loan #02 (rolled over) had ₹10,000 rows on 5, 12 and 19 Sep,
    // all paid: those days should carry the sage dot, legend ₹30k.
    expect(dots(tester, '2023-09-19'), <Color>{AppColors.collected});
    expect(inKey('legend_collected', '₹30,000'), findsOneWidget);
  });
}
