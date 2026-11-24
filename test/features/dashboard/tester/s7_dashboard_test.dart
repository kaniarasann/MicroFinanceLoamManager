import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:nordic_ledger/features/dashboard/presentation/screens/home_screen.dart';

import '../dashboard_test_support.dart';
import 's7_tester_support.dart';

Future<void> pumpDash(
  WidgetTester tester, {
  double width = 400,
  double height = 2800,
  Role role = Role.owner,
  LedgerSeed? seed,
  LaunchLog? launches,
  double textScale = 1,
}) => pumpLedgerScreen(
  tester,
  const DashboardScreen(),
  width: width,
  height: height,
  role: role,
  seed: seed ?? s7Seed(),
  launches: launches,
  textScale: textScale,
);

Finder inKey(String key, String text) =>
    find.descendant(of: find.byKey(k(key)), matching: find.text(text));

void main() {
  for (final width in <double>[400, 1024]) {
    final w = width.toInt();
    testWidgets('S7-D1 KPIs over active, closed, rolled-over and waiver '
        'loans @$w', (WidgetTester tester) async {
      await pumpDash(tester, width: width);
      expect(inKey('kpi_collected', '₹76,000'), findsOneWidget);
      expect(inKey('kpi_net_disbursed', '₹1,75,000'), findsOneWidget);
      expect(inKey('kpi_net_disbursed', '2 active loans'), findsOneWidget);
      expect(inKey('kpi_receivable', '₹1,25,000'), findsOneWidget);
      expect(inKey('kpi_overdue', '₹5,000'), findsOneWidget);
      expect(
        inKey('kpi_overdue', '1 loan · highest 7 days late'),
        findsOneWidget,
      );
      // Waiver-closed c7 and settled c8 hold no excess.
      expect(find.byKey(k('excess_review')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S7-D2 chart semantics label lists buckets and the summary', (
    WidgetTester tester,
  ) async {
    await pumpDash(tester);
    final label = find.bySemanticsLabel(
      RegExp(
        r'^Collections chart, last 8 weeks\. 18 Sep: due .*'
        r'6 Nov: due ₹15,000, collected ₹19,000\. '
        r'8 weeks collection rate \d+% · .*\.$',
      ),
    );
    expect(label, findsOneWidget);
    await tester.tap(find.text('6M'));
    await pumpFrames(tester);
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Collections chart, last 6 months\. Jun:'),
      ),
      findsOneWidget,
    );
    expect(find.text('12M'), findsNothing);
  });

  testWidgets('S7-D3 12M on tablet width only', (WidgetTester tester) async {
    await pumpDash(tester, width: 1024, height: 1800);
    expect(find.text('12M'), findsOneWidget);
    await tester.tap(find.text('12M'));
    await pumpFrames(tester);
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Collections chart, last 12 months\. Dec:'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('S7-D4 receivable breakdown: three labelled rows', (
    WidgetTester tester,
  ) async {
    await pumpDash(tester);
    expect(inKey('share_collected', 'Collected this month'), findsOneWidget);
    expect(inKey('share_upcoming', 'Upcoming next 30 days'), findsOneWidget);
    expect(inKey('share_overdue', 'Overdue'), findsOneWidget);
    // Nov cash: c1 ₹10,000 + c7 ₹9,000 + c8 ₹12,000 (+2,000 − 2,000 c2).
    expect(inKey('share_collected', '₹31,000'), findsOneWidget);
    expect(inKey('share_collected', '24%'), findsOneWidget);
    // c1 14/21/28 Nov + 5 Dec ₹40,000; c2 7/14/21/28 Nov + 5 Dec ₹25,000.
    expect(inKey('share_upcoming', '₹65,000'), findsOneWidget);
    expect(inKey('share_upcoming', '52%'), findsOneWidget);
    expect(inKey('share_overdue', '₹5,000'), findsOneWidget);
    expect(inKey('share_overdue', '4%'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(k('share_overdue')),
        matching: find.byIcon(Icons.warning_amber_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Overdue ₹5,000, 4% of receivable'),
      findsOneWidget,
    );
  });

  testWidgets('S7-D5 Due Today: paid row shown as collected, filters, '
      'progress, Record route', (WidgetTester tester) async {
    await pumpDash(tester);
    expect(find.byKey(k('today_received')), findsOneWidget);
    expect(find.text('₹10,000 / ₹15,000 (66%)'), findsOneWidget);
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.text('Pending (1)'), findsOneWidget);
    expect(find.text('Collected (1)'), findsOneWidget);

    final paid = find.byKey(k('due_row_c1_2'));
    expect(
      find.descendant(of: paid, matching: find.text('Collected')),
      findsOneWidget,
    );
    expect(find.byKey(k('due_record_c1_2')), findsNothing);
    expect(find.byKey(k('due_call_c1_2')), findsNothing);

    await tester.tap(find.byKey(k('due_filter_collected')));
    await pumpFrames(tester);
    expect(find.byKey(k('due_row_c1_2')), findsOneWidget);
    expect(find.byKey(k('due_row_c2_3')), findsNothing);

    await tester.tap(find.byKey(k('due_filter_pending')));
    await pumpFrames(tester);
    expect(find.byKey(k('due_row_c1_2')), findsNothing);
    expect(find.byKey(k('due_row_c2_3')), findsOneWidget);

    await tester.tap(find.byKey(k('due_filter_all')));
    await pumpFrames(tester);
    expect(find.byKey(k('due_row_c1_2')), findsOneWidget);

    await tester.ensureVisible(find.byKey(k('due_record_c2_3')));
    await tester.tap(find.byKey(k('due_record_c2_3')));
    await pumpFrames(tester);
    expect(find.byKey(k('contract_pay_c2')), findsOneWidget);
  });

  testWidgets('S7-D6 excess: rolled-over loan with a late payment', (
    WidgetTester tester,
  ) async {
    await pumpDash(tester, seed: s7Seed(lateRs: 2000));
    final card = find.byKey(k('excess_review'));
    expect(card, findsOneWidget);
    expect(find.byKey(k('excess_c8')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(k('excess_c8')),
        matching: find.textContaining('Rolled over'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(k('excess_c7')), findsNothing);
    // The late cash is counted as collected (cached totalPaid − settled).
    expect(inKey('kpi_collected', '₹78,000'), findsOneWidget);
  });

  testWidgets('S7-D7 collector: dashboard, no New loan; Excess to review is '
      'visible', (WidgetTester tester) async {
    await pumpDash(
      tester,
      role: Role.collector,
      seed: withClosedExcess(s7Seed()),
    );
    expect(find.byKey(k('kpi_collected')), findsOneWidget);
    expect(find.byKey(k('dashboard_new_loan')), findsNothing);
    expect(find.text('New loan'), findsNothing);
    expect(find.byKey(k('excess_review')), findsOneWidget);
    await tester.tap(find.byKey(k('excess_c9')));
    await pumpFrames(tester);
    expect(find.byKey(k('contract_detail_c9')), findsOneWidget);
  });

  for (final role in Role.values) {
    testWidgets('S7-D8 home shell @1024 ${role.name}: rail, New loan FAB '
        'only for owners', (WidgetTester tester) async {
      await pumpLedgerScreen(
        tester,
        const HomeScreen(),
        width: 1024,
        height: 1400,
        role: role,
        seed: s7Seed(),
        wrapInScaffold: false,
      );
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        find.byKey(k('rail_new_loan')),
        role == Role.owner ? findsOneWidget : findsNothing,
      );
      expect(find.byKey(k('kpi_collected')), findsOneWidget);
      // Calendar tab.
      await tester.tap(find.text('Calendar'));
      await pumpFrames(tester);
      expect(find.byKey(k('calendar_detail')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S7-D9 home shell @360 collector: bottom nav, no New loan', (
    WidgetTester tester,
  ) async {
    await pumpLedgerScreen(
      tester,
      const HomeScreen(),
      width: 360,
      height: 2400,
      role: Role.collector,
      seed: s7Seed(),
      wrapInScaffold: false,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(k('rail_new_loan')), findsNothing);
    expect(find.byKey(k('dashboard_new_loan')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[360, 1024]) {
    testWidgets('S7-D10 text scale 1.3 @${width.toInt()} with history, '
        'excess and a collected row', (WidgetTester tester) async {
      await pumpDash(
        tester,
        width: width,
        height: 3600,
        textScale: 1.3,
        seed: withClosedExcess(s7Seed(lateRs: 2000)),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('6M'));
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S7-D11 home shell @360 text scale 1.3', (
    WidgetTester tester,
  ) async {
    await pumpLedgerScreen(
      tester,
      const HomeScreen(),
      width: 360,
      height: 3600,
      seed: s7Seed(),
      textScale: 1.3,
      wrapInScaffold: false,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Calendar'));
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);
  });
}
