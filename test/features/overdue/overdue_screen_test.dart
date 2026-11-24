import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/features/overdue/presentation/screens/overdue_screen.dart';

import '../dashboard/dashboard_test_support.dart';

/// aggregatesFixture, today Tue 7 Nov 2023: c2 Loan #05 (Anita Sharma)
/// has its 31 Oct ₹5,000 installment 7 days overdue. Receivable
/// ₹1,35,000 → risk 3.7%.
Future<void> pumpOverdue(
  WidgetTester tester, {
  required double width,
  double height = 1600,
  LedgerSeed? seed,
  LaunchLog? launches,
  double textScale = 1,
}) => pumpLedgerScreen(
  tester,
  const OverdueScreen(),
  width: width,
  height: height,
  seed: seed ?? aggregatesFixture(),
  launches: launches,
  textScale: textScale,
  wrapInScaffold: false,
);

/// aggregatesFixture plus c6 (Loan #06, Ravi): ₹6,000 weekly ₹2,000 from
/// Mon 6 Nov, nothing paid → 1 day late (recent).
LedgerSeed withRecent() {
  final seed = aggregatesFixture();
  seed.borrowers.add(borrowerDoc('b2', 'Ravi Kumar', '+919900112233'));
  seed.contracts.add(
    contractFor(
      'b2',
      'c6',
      loanNo: 6,
      sanctionedRs: 6000,
      installmentRs: 2000,
      firstDue: d(2023, 11, 6),
      weekday: 1,
    ).copyWith(borrowerName: 'Ravi Kumar'),
  );
  return seed;
}

void main() {
  for (final width in <double>[400, 1024]) {
    final w = width.toInt();
    testWidgets('totals, filters and the loan card @$w', (
      WidgetTester tester,
    ) async {
      await pumpOverdue(tester, width: width);
      final total = find.byKey(k('overdue_total_card'));
      expect(
        find.descendant(of: total, matching: find.text('₹5,000')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: total, matching: find.text('1 loan')),
        findsOneWidget,
      );
      expect(find.text('Highest delay: 7 days late'), findsOneWidget);
      expect(find.text('3.7%'), findsOneWidget);
      expect(find.text('All (1)'), findsOneWidget);
      expect(find.text('Critical >3 days (1)'), findsOneWidget);
      expect(find.text('Recent 1–3 days (0)'), findsOneWidget);

      final card = find.byKey(k('overdue_loan_c2'));
      expect(card, findsOneWidget);
      for (final text in <String>[
        '7 days late',
        'Scheduled 31 Oct 2023',
        '+91 98123 45678',
        'Record ₹5,000',
      ]) {
        expect(
          find.descendant(of: card, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Critical / Recent filters', (WidgetTester tester) async {
    await pumpOverdue(tester, width: 400, seed: withRecent());
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.byKey(k('overdue_loan_c6')), findsOneWidget);

    await tester.tap(find.byKey(k('overdue_filter_critical')));
    await pumpFrames(tester);
    expect(find.byKey(k('overdue_loan_c2')), findsOneWidget);
    expect(find.byKey(k('overdue_loan_c6')), findsNothing);

    await tester.tap(find.byKey(k('overdue_filter_recent')));
    await pumpFrames(tester);
    expect(find.byKey(k('overdue_loan_c2')), findsNothing);
    expect(find.byKey(k('overdue_loan_c6')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(k('overdue_loan_c6')),
        matching: find.text('1 day late'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(k('overdue_total_card')),
        matching: find.text('₹2,000'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Call, WhatsApp and Record', (WidgetTester tester) async {
    final launches = LaunchLog();
    await pumpOverdue(tester, width: 400, launches: launches);
    await tester.tap(find.byKey(k('overdue_call_c2')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(k('overdue_whatsapp_c2')));
    await pumpFrames(tester);
    expect(launches.launched, hasLength(2));
    expect(launches.launched.first.toString(), 'tel:+919812345678');
    final wa = launches.launched.last;
    expect(wa.host, 'wa.me');
    final text = wa.queryParameters['text']!;
    expect(text, contains('₹5,000 for Loan #05 was due on 31 Oct 2023'));
    expect(text, contains('Sri Lakshmi Finance'));

    await tester.tap(find.byKey(k('overdue_record_c2')));
    await pumpFrames(tester);
    expect(find.byKey(k('contract_pay_c2')), findsOneWidget);
  });

  testWidgets('compact: tapping a card opens the loan', (
    WidgetTester tester,
  ) async {
    await pumpOverdue(tester, width: 400);
    await tester.tap(find.text('Scheduled 31 Oct 2023'));
    await pumpFrames(tester);
    expect(find.byKey(k('contract_detail_c2')), findsOneWidget);
  });

  testWidgets('expanded: list | detail with missed installments', (
    WidgetTester tester,
  ) async {
    await pumpOverdue(tester, width: 1024);
    expect(find.byKey(k('overdue_detail_empty')), findsOneWidget);
    await tester.tap(find.text('Scheduled 31 Oct 2023'));
    await pumpFrames(tester);
    final detail = find.byKey(k('overdue_detail_c2'));
    expect(detail, findsOneWidget);
    expect(
      find.descendant(of: detail, matching: find.text('Inst. 2 · 31 Oct 2023')),
      findsOneWidget,
    );
    final list = tester.getRect(find.byKey(k('overdue_list')));
    expect(tester.getRect(detail).left, greaterThanOrEqualTo(list.right));

    await tester.tap(find.byKey(k('overdue_open_schedule')));
    await pumpFrames(tester);
    expect(find.byKey(k('contract_detail_c2')), findsOneWidget);
  });

  testWidgets('nothing overdue', (WidgetTester tester) async {
    await pumpOverdue(tester, width: 400, seed: LedgerSeed());
    expect(find.text('Nothing overdue'), findsWidgets);
    expect(find.byKey(k('overdue_empty')), findsOneWidget);
  });

  for (final width in <double>[360, 1024]) {
    testWidgets('survives text scale 1.3 @${width.toInt()}', (
      WidgetTester tester,
    ) async {
      await pumpOverdue(
        tester,
        width: width,
        height: 2400,
        textScale: 1.3,
        seed: withRecent(),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
