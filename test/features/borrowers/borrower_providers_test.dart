import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/core/time/ist_clock.dart';
import 'package:nordic_ledger/core/time/today_provider.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/borrowers/application/borrower_providers.dart';
import 'package:nordic_ledger/features/borrowers/application/reminder_message.dart';
import 'package:nordic_ledger/features/contracts/application/ledger_providers.dart';

import '../../domain/ledger/ledger_fixtures.dart';
import 'borrower_test_support.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ProviderContainer container;
  late FixedClock clock;

  Future<void> boot(LedgerSeed seed) async {
    db = FakeFirebaseFirestore();
    clock = fixtureClock();
    await seed.writeTo(db);
    container = ProviderContainer(
      overrides: borrowerOverrides(db, clock: clock),
    );
    addTearDown(container.dispose);
    container
      ..listen(borrowerSearchProvider, (_, _) {})
      ..listen(activeProjectionsProvider, (_, _) {});
    await settle();
  }

  List<String> ids() => container
      .read(borrowerSearchProvider)
      .requireValue
      .map((BorrowerListItem i) => i.borrower.id)
      .toList();

  group('search and filters', () {
    setUp(() => boot(listFixture()));

    test('all borrowers, ordered by name', () {
      expect(ids(), <String>['b1', 'b3', 'b2', 'b4']);
    });

    test('name: case-insensitive substring', () {
      final q = container.read(borrowerQueryStateProvider.notifier);
      q.setText('SHAR');
      expect(ids(), <String>['b1']);
      q.setText('  ra ');
      expect(ids(), <String>['b2']); // only "Ravi Kumar" contains "ra"
    });

    test('phone digits, with or without +91 and spaces', () {
      final q = container.read(borrowerQueryStateProvider.notifier);
      q.setText('98450');
      expect(ids(), <String>['b1']);
      q.setText('+91 99001');
      expect(ids(), <String>['b2']);
      q.setText('12890');
      expect(ids(), <String>['b1']);
      q.setText('0000');
      expect(ids(), isEmpty);
    });

    test('filters: Active only / Due this week / Overdue', () {
      final q = container.read(borrowerQueryStateProvider.notifier);
      q.setFilter(BorrowerFilter.active);
      expect(ids(), <String>['b1', 'b2', 'b4']);
      q.setFilter(BorrowerFilter.dueThisWeek);
      expect(ids(), <String>['b1', 'b2']);
      q.setFilter(BorrowerFilter.overdue);
      expect(ids(), <String>['b1']);
      q.setText('ravi');
      expect(ids(), isEmpty);
      q
        ..setFilter(BorrowerFilter.all)
        ..setText('');
      expect(ids().length, 4);
    });

    test('row figures: active count, outstanding, status', () {
      final items = {
        for (final i in container.read(borrowerItemsProvider).requireValue)
          i.borrower.id: i.stats,
      };
      expect(items['b1']!.activeCount, 2);
      expect(items['b1']!.outstanding, inr(135000));
      expect(items['b1']!.standing, Standing.overdue);
      expect(items['b1']!.maxDaysOverdue, 7);
      expect(items['b2']!.standing, Standing.onTrack);
      expect(items['b3']!.standing, Standing.none);
      expect(items['b4']!.outstanding, inr(40000));
    });
  });

  group('matchesBorrowerQuery', () {
    final b = borrowerDoc('x', 'Anita Sharma', '+919845012890');
    test('empty matches; mixed letters never match by digits', () {
      expect(matchesBorrowerQuery(b, ''), isTrue);
      expect(matchesBorrowerQuery(b, 'anita 9'), isFalse);
      expect(matchesBorrowerQuery(b, '(984) 50-12'), isTrue);
      expect(matchesBorrowerQuery(b, '+'), isFalse);
    });
  });

  group('borrowerSummary (2 active + 1 rolled over)', () {
    setUp(() => boot(aggregatesFixture()));

    test('aggregates match the hand-computed numbers', () async {
      container.listen(borrowerSummaryProvider('b1'), (_, _) {});
      await settle();
      final s = container.read(borrowerSummaryProvider('b1')).requireValue;
      expect(s.activeExposure, inr(135000));
      expect(s.lifetimeLent, inr(180000));
      expect(s.collected, inr(45000));
      expect(s.active.length, 2);
      expect(s.closed.single.id, 'c3');
      expect(s.recentReceipts.map((LedgerEntry e) => e.tx.id), <String>[
        't-c2-p2',
        't-c1-p1',
        't-c2-p1',
        't-c3-p1',
      ]);
      expect(s.recentReceipts.map((LedgerEntry e) => e.balanceAfter), <Object>[
        inr(43000),
        inr(90000),
        inr(45000),
        inr(0),
      ]);
      expect(
        contractStanding(
          s.active.firstWhere((ContractProjection p) => p.contract.id == 'c1'),
        ),
        Standing.dueToday,
      );
      expect(s.stats.standing, Standing.overdue);
    });

    test('reminder text names the earliest open installment', () async {
      container.listen(borrowerSummaryProvider('b1'), (_, _) {});
      await settle();
      final s = container.read(borrowerSummaryProvider('b1')).requireValue;
      final text = ReminderMessage.build(
        borrowerName: 'Anita Sharma',
        companyName: 'Sri Lakshmi Finance',
        active: s.active,
        today: kToday,
      );
      expect(
        text,
        'Hello Anita Sharma, this is a gentle reminder from Sri Lakshmi '
        'Finance: ₹5,000 for Loan #05 was due on 31 Oct 2023. Thank you.',
      );
      expect(
        ReminderMessage.whatsAppUri('+919845012890', text).toString(),
        startsWith('https://wa.me/919845012890?text=Hello%20Anita'),
      );
      expect(
        ReminderMessage.build(
          borrowerName: 'Meena',
          companyName: '',
          active: const <ContractProjection>[],
          today: kToday,
        ),
        'Hello Meena, greetings. Thank you.',
      );
      expect(
        ReminderMessage.telUri('+919845012890').toString(),
        'tel:+919845012890',
      );
    });
  });

  group('activeProjections memoisation', () {
    setUp(() => boot(aggregatesFixture()));

    test('unchanged contract keeps the same projection instance', () async {
      final before = container.read(activeProjectionsProvider).requireValue;
      final memo = container.read(projectionMemoProvider);
      final computed = memo.computeCount;
      expect(before.keys.toSet(), <String>{'c1', 'c2'});

      // A new payment on c1 only.
      final c1 = aggregatesFixture().contracts.first;
      await TypedRefs(
        db,
      ).transaction(kCid, 't-new').set(txFor(c1, 't-new', 10000, kToday));
      await settle();

      final after = container.read(activeProjectionsProvider).requireValue;
      expect(identical(after['c2'], before['c2']), isTrue);
      expect(identical(after['c1'], before['c1']), isFalse);
      expect(after['c1']!.totalPaid, inr(20000));
      expect(memo.computeCount, computed + 1);
    });

    test('the day ticker re-projects every contract', () async {
      final before = container.read(activeProjectionsProvider).requireValue;
      clock.now = DateTime(2023, 11, 8, 0, 1);
      container.read(todayProvider.notifier).refresh();
      await settle();
      final after = container.read(activeProjectionsProvider).requireValue;
      expect(container.read(todayProvider), d(2023, 11, 8));
      expect(identical(after['c1'], before['c1']), isFalse);
      expect(after['c1']!.today, d(2023, 11, 8));
      // c1's 7 Nov installment is now 1 day overdue.
      expect(after['c1']!.maxDaysOverdue, 1);
    });

    test('ProjectionMemo directly: equal inputs → identical output', () {
      final seed = aggregatesFixture();
      final active = seed.contracts.where((Contract c) => c.isActive).toList();
      final inst = <Installment>[for (final c in active) ...scheduleFor(c)];
      final memo = ProjectionMemo();
      final a = memo.project(
        contracts: active,
        installments: inst,
        transactions: seed.transactions,
        today: kToday,
      );
      // Fresh but equal copies (what a new snapshot delivers).
      final b = memo.project(
        contracts: <Contract>[for (final c in active) c.copyWith()],
        installments: <Installment>[for (final i in inst) i.copyWith()],
        transactions: seed.transactions.reversed.toList(),
        today: kToday,
      );
      expect(identical(a['c1'], b['c1']), isTrue);
      expect(identical(a['c2'], b['c2']), isTrue);
      expect(memo.computeCount, 2);

      // An edited contract doc re-projects that contract only.
      final c = memo.project(
        contracts: <Contract>[
          active[0].copyWith(notes: 'edited'),
          active[1],
        ],
        installments: inst,
        transactions: seed.transactions,
        today: kToday,
      );
      expect(identical(c['c1'], a['c1']), isFalse);
      expect(identical(c['c2'], a['c2']), isTrue);

      // A dropped contract leaves the memo.
      final e = memo.project(
        contracts: <Contract>[active[1]],
        installments: inst,
        transactions: seed.transactions,
        today: kToday,
      );
      expect(e.keys, <String>['c2']);
      expect(memo.computeCount, 3);
    });

    test('today provider: untilMidnight', () {
      clock.now = DateTime(2023, 11, 7, 23, 59, 30);
      expect(
        container.read(todayProvider.notifier).untilMidnight(),
        const Duration(seconds: 30),
      );
      clock.now = DateTime(2023, 11, 7, 23, 59, 59, 999);
      expect(
        container.read(todayProvider.notifier).untilMidnight(),
        const Duration(seconds: 1),
      );
    });
  });
}
