import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/overdue/presentation/screens/overdue_screen.dart';

import '../../dashboard/dashboard_test_support.dart';

/// aggregatesFixture (today Tue 7 Nov 2023) plus:
/// - c10 Loan #10 Ravi (+91 99001 12233): ₹20,000 weekly Tue ₹4,000 from
///   17 Oct, nothing paid → 17 / 24 / 31 Oct missed (21, 14, 7 days),
///   ₹12,000, critical;
/// - c2 Loan #05 Anita: 31 Oct ₹5,000, 7 days, critical;
/// - c11 Loan #11 Meena: Sat 4 Nov ₹3,000, 3 days → recent (boundary);
/// - c12 Loan #12 Suresh: Mon 6 Nov ₹2,000, 1 day → recent.
/// Totals: all ₹22,000 (4 loans); critical ₹17,000 (2); recent ₹5,000 (2).
LedgerSeed trackerSeed() {
  final seed = aggregatesFixture();
  seed.borrowers.addAll(<Borrower>[
    borrowerDoc('b2', 'Ravi Kumar', '+919900112233'),
    borrowerDoc('b3', 'Meena Iyer', '+917012345678'),
    borrowerDoc('b4', 'Suresh Verma', '+918123456789'),
  ]);
  Contract mk(
    String b,
    String id,
    int loanNo,
    String name,
    String phone, {
    required int sanctionedRs,
    required int installmentRs,
    required CivilDate firstDue,
    required int weekday,
  }) =>
      contractFor(
        b,
        id,
        loanNo: loanNo,
        sanctionedRs: sanctionedRs,
        installmentRs: installmentRs,
        firstDue: firstDue,
        weekday: weekday,
      ).copyWith(
        borrowerName: name,
        borrowerPhoneE164: phone,
        disbursedOn: d(2023, 10, 10),
      );
  seed.contracts.addAll(<Contract>[
    mk(
      'b2',
      'c10',
      10,
      'Ravi Kumar',
      '+919900112233',
      sanctionedRs: 20000,
      installmentRs: 4000,
      firstDue: d(2023, 10, 17),
      weekday: 2,
    ),
    mk(
      'b3',
      'c11',
      11,
      'Meena Iyer',
      '+917012345678',
      sanctionedRs: 3000,
      installmentRs: 3000,
      firstDue: d(2023, 11, 4),
      weekday: 6,
    ),
    mk(
      'b4',
      'c12',
      12,
      'Suresh Verma',
      '+918123456789',
      sanctionedRs: 2000,
      installmentRs: 2000,
      firstDue: d(2023, 11, 6),
      weekday: 1,
    ),
  ]);
  return seed;
}

Future<void> pumpTracker(
  WidgetTester tester, {
  double width = 400,
  double height = 3000,
  Role role = Role.owner,
  LaunchLog? launches,
  double textScale = 1,
}) => pumpLedgerScreen(
  tester,
  const OverdueScreen(),
  width: width,
  height: height,
  role: role,
  seed: trackerSeed(),
  launches: launches,
  textScale: textScale,
  wrapInScaffold: false,
);

Finder inKey(String key, String text) =>
    find.descendant(of: find.byKey(k(key)), matching: find.text(text));

void main() {
  testWidgets('S7-O1 one card per loan, ordered by the highest delay', (
    WidgetTester tester,
  ) async {
    await pumpTracker(tester);
    final ids = <String>['c10', 'c2', 'c11', 'c12'];
    final ys = <double>[
      for (final id in ids)
        tester.getTopLeft(find.byKey(k('overdue_loan_$id'))).dy,
    ];
    expect(ys, orderedEquals(<double>[...ys]..sort()));
    expect(inKey('overdue_loan_c10', '21 days late'), findsOneWidget);
    expect(
      inKey('overdue_loan_c10', 'Scheduled 17 Oct 2023 · 3 installments'),
      findsOneWidget,
    );
    expect(inKey('overdue_loan_c10', '₹12,000'), findsOneWidget);
    expect(inKey('overdue_loan_c11', '3 days late'), findsOneWidget);
    expect(inKey('overdue_total_card', '₹22,000'), findsOneWidget);
    expect(inKey('overdue_total_card', '4 loans'), findsOneWidget);
    expect(find.text('Highest delay: 21 days late'), findsOneWidget);
  });

  testWidgets('S7-O2 Critical / Recent filters and their totals', (
    WidgetTester tester,
  ) async {
    await pumpTracker(tester);
    expect(find.text('All (4)'), findsOneWidget);
    expect(find.text('Critical >3 days (2)'), findsOneWidget);
    expect(find.text('Recent 1–3 days (2)'), findsOneWidget);

    await tester.tap(find.byKey(k('overdue_filter_critical')));
    await pumpFrames(tester);
    expect(find.byKey(k('overdue_loan_c10')), findsOneWidget);
    expect(find.byKey(k('overdue_loan_c2')), findsOneWidget);
    expect(find.byKey(k('overdue_loan_c11')), findsNothing);
    expect(find.byKey(k('overdue_loan_c12')), findsNothing);
    expect(inKey('overdue_total_card', '₹17,000'), findsOneWidget);
    expect(inKey('overdue_total_card', '2 loans'), findsOneWidget);

    await tester.tap(find.byKey(k('overdue_filter_recent')));
    await pumpFrames(tester);
    expect(find.byKey(k('overdue_loan_c10')), findsNothing);
    expect(find.byKey(k('overdue_loan_c11')), findsOneWidget); // 3 days
    expect(find.byKey(k('overdue_loan_c12')), findsOneWidget);
    expect(inKey('overdue_total_card', '₹5,000'), findsOneWidget);
    expect(find.text('Highest delay: 3 days late'), findsOneWidget);
  });

  testWidgets('S7-O3 Call, WhatsApp (reminder text) and Record', (
    WidgetTester tester,
  ) async {
    final launches = LaunchLog();
    await pumpTracker(tester, launches: launches);
    await tester.tap(find.byKey(k('overdue_call_c10')));
    await pumpFrames(tester);
    expect(launches.launched.last.toString(), 'tel:+919900112233');

    await tester.tap(find.byKey(k('overdue_whatsapp_c10')));
    await pumpFrames(tester);
    final wa = launches.launched.last;
    expect(wa.host, 'wa.me');
    expect(wa.path, contains('919900112233'));
    final text = wa.queryParameters['text']!;
    expect(text, startsWith('Hello Ravi Kumar'));
    expect(text, contains('Sri Lakshmi Finance'));
    expect(text, contains('₹4,000 for Loan #10 was due on 17 Oct 2023'));
    expect(text.toLowerCase(), isNot(contains('upi')));

    await tester.tap(find.byKey(k('overdue_record_c10')));
    await pumpFrames(tester);
    expect(find.byKey(k('contract_pay_c10')), findsOneWidget);
  });

  testWidgets('S7-O4 collector sees the tracker and its actions', (
    WidgetTester tester,
  ) async {
    await pumpTracker(tester, role: Role.collector);
    expect(find.byKey(k('overdue_loan_c10')), findsOneWidget);
    expect(find.byKey(k('overdue_record_c10')), findsOneWidget);
    expect(find.byKey(k('overdue_whatsapp_c10')), findsOneWidget);
  });

  testWidgets('S7-O5 tablet 1024: list | detail split (40/60)', (
    WidgetTester tester,
  ) async {
    await pumpTracker(tester, width: 1024, height: 1600);
    expect(find.byKey(k('overdue_detail_empty')), findsOneWidget);
    await tester.tap(find.text('Scheduled 17 Oct 2023 · 3 installments'));
    await pumpFrames(tester);
    final detail = find.byKey(k('overdue_detail_c10'));
    expect(detail, findsOneWidget);
    final list = tester.getRect(find.byKey(k('overdue_list')));
    final pane = tester.getRect(detail);
    expect(pane.left, greaterThanOrEqualTo(list.right));
    expect(list.width / (list.width + pane.width), closeTo(0.4, 0.06));
    for (final t in <String>[
      'Inst. 1 · 17 Oct 2023',
      'Inst. 2 · 24 Oct 2023',
      'Inst. 3 · 31 Oct 2023',
    ]) {
      expect(
        find.descendant(of: detail, matching: find.text(t)),
        findsOneWidget,
      );
    }
    // Still on /overdue (no push on tablets).
    expect(find.byType(OverdueScreen), findsOneWidget);
    expect(find.byKey(k('contract_detail_c10')), findsNothing);
  });

  for (final width in <double>[360, 1024]) {
    testWidgets('S7-O6 text scale 1.3 @${width.toInt()}', (
      WidgetTester tester,
    ) async {
      await pumpTracker(tester, width: width, height: 3600, textScale: 1.3);
      expect(tester.takeException(), isNull);
      if (width > 1000) {
        await tester.tap(find.text('Scheduled 17 Oct 2023 · 3 installments'));
        await pumpFrames(tester);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byKey(k('overdue_filter_recent')));
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
