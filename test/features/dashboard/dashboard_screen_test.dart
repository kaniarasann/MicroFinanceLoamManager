import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:nordic_ledger/features/overdue/presentation/screens/overdue_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/features/dashboard/application/portfolio_providers.dart';
import 'package:nordic_ledger/features/dashboard/presentation/widgets/due_row_card.dart';

import 'dashboard_test_support.dart';

/// aggregatesFixture, today Tue 7 Nov 2023:
/// - c1 Loan #04 ₹1,00,000 (net ₹93,000), ₹10,000 paid; 7 Nov ₹10,000 due.
/// - c2 Loan #05 ₹50,000 (net ₹43,000), ₹5,000 paid (₹2,000 reversed);
///   31 Oct ₹5,000 overdue 7 days; 7 Nov ₹5,000 due.
/// - c3 Loan #02 rolled over, net ₹23,000, ₹30,000 collected.
Future<void> pumpDashboard(
  WidgetTester tester, {
  required double width,
  double height = 2600,
  Role role = Role.owner,
  LedgerSeed? seed,
  LaunchLog? launches,
  double textScale = 1,
}) async {
  await pumpLedgerScreen(
    tester,
    const DashboardScreen(),
    width: width,
    height: height,
    role: role,
    seed: seed ?? aggregatesFixture(),
    launches: launches,
    textScale: textScale,
  );
}

Finder inKpi(String key, String text) =>
    find.descendant(of: find.byKey(k(key)), matching: find.text(text));

void main() {
  for (final width in <double>[400, 1024]) {
    final w = width.toInt();

    testWidgets('KPIs match the recorded data @$w', (
      WidgetTester tester,
    ) async {
      await pumpDashboard(tester, width: width);
      expect(inKpi('kpi_net_disbursed', '₹1,59,000'), findsOneWidget);
      expect(inKpi('kpi_net_disbursed', '2 active loans'), findsOneWidget);
      expect(inKpi('kpi_receivable', '₹1,35,000'), findsOneWidget);
      expect(inKpi('kpi_collected', '₹45,000'), findsOneWidget);
      expect(inKpi('kpi_overdue', '₹5,000'), findsOneWidget);
      expect(
        inKpi('kpi_overdue', '1 loan · highest 7 days late'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('chart, breakdown, today card and due list @$w', (
      WidgetTester tester,
    ) async {
      await pumpDashboard(tester, width: width);
      expect(find.text('Collections · last 8 weeks'), findsOneWidget);
      // Due in 8 weeks (from Mon 18 Sep): active ₹35,000 (24 / 31 Oct,
      // 7 Nov) + c3's settled 19 Sep row ₹10,000 (rolled over). Collected:
      // ₹15,000 active + ₹30,000 (30 Sep, c3) = 100%.
      expect(
        find.text('8 weeks collection rate 100% · ₹45,000 of ₹45,000'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('^Collections chart, last 8 weeks')),
        findsOneWidget,
      );

      final breakdown = find.byKey(k('receivable_breakdown'));
      expect(
        find.descendant(of: breakdown, matching: find.text('₹1,35,000')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(k('share_overdue')),
          matching: find.text('₹5,000'),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: find.byKey(k('today_due_card')),
          matching: find.text('₹15,000'),
        ),
        findsOneWidget,
      );
      expect(find.text('₹0 / ₹15,000 (0%)'), findsOneWidget);
      expect(find.byKey(k('due_row_c1_2')), findsOneWidget);
      expect(find.byKey(k('due_row_c2_3')), findsOneWidget);
      expect(find.byKey(k('overdue_alert')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('compact: 2×2 KPIs, stacked charts, New loan in the header', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester, width: 400);
    final net = tester.getTopLeft(find.byKey(k('kpi_net_disbursed')));
    final rec = tester.getTopLeft(find.byKey(k('kpi_receivable')));
    final col = tester.getTopLeft(find.byKey(k('kpi_collected')));
    expect(rec.dy, net.dy);
    expect(col.dy, greaterThan(net.dy));
    expect(col.dx, net.dx);
    final chart = tester.getTopLeft(find.byKey(k('collections_chart')));
    final breakdown = tester.getTopLeft(find.byKey(k('receivable_breakdown')));
    expect(breakdown.dy, greaterThan(chart.dy));
    expect(find.text('12M'), findsNothing);
    expect(find.byKey(k('dashboard_new_loan')), findsOneWidget);
  });

  testWidgets('expanded: 4-up KPIs, chart 8 | breakdown 4, 12M option', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester, width: 1024, height: 1800);
    final ys = <double>{
      for (final key in <String>[
        'kpi_net_disbursed',
        'kpi_receivable',
        'kpi_collected',
        'kpi_overdue',
      ])
        tester.getTopLeft(find.byKey(k(key))).dy,
    };
    expect(ys, hasLength(1));
    final chart = tester.getRect(find.byKey(k('collections_chart')));
    final breakdown = tester.getRect(find.byKey(k('receivable_breakdown')));
    expect(breakdown.top, chart.top);
    expect(chart.width, greaterThan(breakdown.width * 1.8));
    expect(find.text('12M'), findsOneWidget);
    // The rail FAB carries "New loan" on expanded windows.
    expect(find.byKey(k('dashboard_new_loan')), findsNothing);

    await tester.tap(find.text('12M'));
    await pumpFrames(tester);
    expect(find.text('Collections · last 12 months'), findsOneWidget);
  });

  testWidgets('6M toggle and the collection-rate summary', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester, width: 400);
    await tester.tap(find.text('6M'));
    await pumpFrames(tester);
    expect(find.text('Collections · last 6 months'), findsOneWidget);
    // Jun–Nov: due Sep ₹30,000 (c3) + Oct ₹20,000 + Nov ₹60,000;
    // collected ₹45,000.
    expect(
      find.text('6 months collection rate 40% · ₹45,000 of ₹1,10,000'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a bar shows the tooltip', (WidgetTester tester) async {
    await pumpDashboard(tester, width: 400);
    final chart = find.byKey(k('collections_chart'));
    // The last (current) week's bar sits at the right edge of the plot.
    final plot = find.descendant(
      of: chart,
      matching: find.byWidgetPredicate(
        (Widget wd) => wd.runtimeType.toString() == 'BarChart',
      ),
    );
    final p = tester.getRect(plot);
    await tester.tapAt(Offset(p.right - 20, p.bottom - 40));
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Due today filters', (WidgetTester tester) async {
    await pumpDashboard(tester, width: 400);
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.text('Pending (2)'), findsOneWidget);
    expect(find.text('Collected (0)'), findsOneWidget);

    await tester.tap(find.byKey(k('due_filter_collected')));
    await pumpFrames(tester);
    expect(find.byKey(k('due_row_c1_2')), findsNothing);
    expect(find.text('Nothing collected yet today.'), findsOneWidget);

    await tester.tap(find.byKey(k('due_filter_pending')));
    await pumpFrames(tester);
    expect(find.byKey(k('due_row_c1_2')), findsOneWidget);
    expect(find.byKey(k('due_row_c2_3')), findsOneWidget);
  });

  testWidgets('Record opens the payment route; Call opens the dialer', (
    WidgetTester tester,
  ) async {
    final launches = LaunchLog();
    await pumpDashboard(tester, width: 400, launches: launches);
    await tester.tap(find.byKey(k('due_call_c1_2')));
    await pumpFrames(tester);
    expect(launches.launched.single.toString(), 'tel:+919812345678');

    await tester.tap(find.byKey(k('due_record_c1_2')));
    await pumpFrames(tester);
    expect(find.byKey(k('contract_pay_c1')), findsOneWidget);
  });

  testWidgets('overdue alert opens the tracker', (WidgetTester tester) async {
    await pumpDashboard(tester, width: 400);
    await tester.tap(find.byKey(k('overdue_alert')));
    await pumpFrames(tester);
    expect(find.byType(OverdueScreen), findsOneWidget);
  });

  testWidgets('excess on a closed contract shows "Excess to review"', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(
      tester,
      width: 400,
      seed: withClosedExcess(aggregatesFixture()),
    );
    final card = find.byKey(k('excess_review'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('₹800')),
      findsWidgets,
    );
    await tester.tap(find.byKey(k('excess_c9')));
    await pumpFrames(tester);
    expect(find.byKey(k('contract_detail_c9')), findsOneWidget);
  });

  for (final role in Role.values) {
    testWidgets('excess copy for ${role.name}s', (WidgetTester tester) async {
      await pumpDashboard(
        tester,
        width: 400,
        role: role,
        seed: withClosedExcess(aggregatesFixture()),
      );
      final ask = find.textContaining('Ask an owner to review and reverse');
      final open = find.textContaining('Open the loan to review and reverse');
      expect(ask, role == Role.collector ? findsOneWidget : findsNothing);
      expect(open, role == Role.owner ? findsOneWidget : findsNothing);
    });
  }

  testWidgets('extension rows read "Added · missed on {date}"', (
    WidgetTester tester,
  ) async {
    // c2's 31 Oct shortfall is re-planned at the end (2 Jan 2024); its
    // card shows the source in the calendar / due lists.
    await pumpLedgerScreen(
      tester,
      const DueRowCardHost(),
      width: 400,
      seed: aggregatesFixture(),
    );
    expect(
      find.textContaining('Added · missed on 31 Oct (Inst. 2)'),
      findsOneWidget,
    );
  });

  testWidgets('no excess card without excess; collector has no New loan', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester, width: 400, role: Role.collector);
    expect(find.byKey(k('excess_review')), findsNothing);
    expect(find.byKey(k('dashboard_new_loan')), findsNothing);
  });

  testWidgets('empty book: zero KPIs, no alert, empty due list', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester, width: 400, seed: LedgerSeed());
    expect(inKpi('kpi_net_disbursed', '₹0'), findsOneWidget);
    expect(inKpi('kpi_overdue', 'Nothing overdue'), findsOneWidget);
    expect(find.byKey(k('overdue_alert')), findsNothing);
    expect(find.text('No collections are due today.'), findsOneWidget);
  });

  for (final width in <double>[360, 400, 1024]) {
    testWidgets('survives text scale 1.3 @${width.toInt()}', (
      WidgetTester tester,
    ) async {
      await pumpDashboard(
        tester,
        width: width,
        height: 3200,
        textScale: 1.3,
        seed: withClosedExcess(aggregatesFixture()),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(k('due_row_c2_3')), findsOneWidget);
    });
  }
}

/// Renders the extension row of c2 (2 Jan 2024) through [DueRowCard].
class DueRowCardHost extends ConsumerWidget {
  const DueRowCardHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const day = CivilDate(2024, 1, 2);
    final items = ref.watch(dueItemsProvider(day, day));
    if (items == null) return const SizedBox.shrink();
    return ListView(
      children: <Widget>[
        for (final i in items)
          if (i.isExtension) DueRowCard(item: i),
      ],
    );
  }
}
