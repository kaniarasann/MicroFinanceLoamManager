// Tester — Sprint 8: independent checks of planCollectionNotifications.
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import '../ledger_fixtures.dart';

final CivilDate t0 = d(2026, 11, 2); // a Monday

DueRowItem due(
  String cid,
  CivilDate on,
  int amountRs, {
  int paidRs = 0,
  bool ext = false,
  ContractStatus status = ContractStatus.active,
  String name = 'Suresh Verma',
  int loanNo = 4,
}) => DueRowItem(
  contractId: cid,
  borrowerId: 'b-$cid',
  borrowerName: name,
  borrowerPhoneE164: '+919845012890',
  loanNo: loanNo,
  frequency: Frequency.weekly,
  seq: 1,
  dueDate: on,
  amount: rs(amountRs),
  paid: rs(paidRs),
  status: paidRs >= amountRs ? RowStatus.paid : RowStatus.upcoming,
  daysOverdue: 0,
  isExtension: ext,
  cyclesTotal: 10,
  contractStatus: status,
);

OverdueItem od(String cid, int amountRs, int days) => OverdueItem(
  contractId: cid,
  borrowerName: 'Late',
  loanNo: 9,
  seq: 1,
  dueDate: t0.addDays(-days),
  amount: rs(amountRs),
  daysOverdue: days,
);

List<PlannedNotification> plan({
  NotificationPrefs prefs = const NotificationPrefs(),
  CivilDate? today,
  int now = 7 * 60, // 07:00, before the 08:00 default
  List<DueRowItem> rows = const <DueRowItem>[],
  List<OverdueItem> overdue = const <OverdueItem>[],
  String company = 'Sri Lakshmi Finance',
}) => planCollectionNotifications(
  prefs: prefs,
  today: today ?? t0,
  nowMinuteOfDay: now,
  rows: rows,
  overdue: overdue,
  companyName: company,
);

Iterable<PlannedNotification> ofKind(
  List<PlannedNotification> p,
  NotificationKind k,
) => p.where((PlannedNotification n) => n.kind == k);

const NotificationPrefs allOn = NotificationPrefs(perInstallmentEnabled: true);

void main() {
  group('digest content and IST time', () {
    test('S8-P1 count + Σ remaining with Indian grouping at the set time', () {
      final p = plan(
        prefs: const NotificationPrefs(digestTime: '18:30'),
        now: 9 * 60,
        rows: <DueRowItem>[
          due('a', t0, 40000),
          due('b', t0, 5000, paidRs: 2500),
          due('c', t0, 62500),
        ],
      );
      final dg = ofKind(p, NotificationKind.digest).single;
      expect(dg.date, t0);
      expect(dg.time, const DigestTime(18, 30));
      expect(dg.time.display, '6:30 PM');
      expect(dg.title, 'Sri Lakshmi Finance');
      // 40,000 + 2,500 + 62,500 = 1,05,000
      expect(dg.body, '3 collections due today · ₹1,05,000');
      expect(dg.id, digestIdBase);
    });

    test('S8-P2 singular copy and paise shown only when non-zero', () {
      final r = DueRowItem(
        contractId: 'a',
        borrowerId: 'b',
        borrowerName: 'Anita',
        borrowerPhoneE164: '+919845012890',
        loanNo: 12,
        frequency: Frequency.daily,
        seq: 1,
        dueDate: t0,
        amount: const Money(350050),
        paid: Money.zero,
        status: RowStatus.dueToday,
        daysOverdue: 0,
        isExtension: false,
        cyclesTotal: 10,
      );
      final p = plan(prefs: allOn, rows: <DueRowItem>[r]);
      expect(
        ofKind(p, NotificationKind.digest).single.body,
        '1 collection due today · ₹3,500.50',
      );
      expect(
        ofKind(p, NotificationKind.installment).single.body,
        'Anita · Loan #12 · ₹3,500.50 due today',
      );
    });

    test('S8-P3 malformed digestTime falls back to 08:00', () {
      for (final bad in <String>['8:00', '24:00', '07:60', '', 'noon']) {
        expect(DigestTime.parse(bad), DigestTime.fallback, reason: bad);
      }
      expect(DigestTime.parse('00:00').display, '12:00 AM');
      expect(DigestTime.parse('12:05').display, '12:05 PM');
    });
  });

  group('14-day window edges', () {
    test('S8-P4 day 14 (today+13) notifies, day 15 (today+14) never', () {
      final p = plan(
        prefs: allOn.copyWith(overdueNudgeEnabled: false),
        rows: <DueRowItem>[
          due('in', t0.addDays(13), 1000),
          due('out', t0.addDays(14), 2000),
        ],
      );
      expect(p, hasLength(2)); // digest + reminder for "in" only
      expect(p.every((PlannedNotification n) => n.date == t0.addDays(13)),
          isTrue);
      expect(ofKind(p, NotificationKind.digest).single.id, digestIdBase + 13);
      expect(
        p.any((PlannedNotification n) => n.contractId == 'out'),
        isFalse,
      );
    });

    test('S8-P5 a past-dated open row is not a reminder (nudge only)', () {
      final p = plan(
        prefs: allOn,
        rows: <DueRowItem>[due('past', t0.addDays(-1), 1000)],
      );
      expect(ofKind(p, NotificationKind.digest), isEmpty);
      expect(ofKind(p, NotificationKind.installment), isEmpty);
    });

    test('S8-P6 no date in the plan falls outside today..today+13', () {
      final p = plan(
        prefs: allOn,
        rows: <DueRowItem>[
          for (var i = -3; i < 20; i++) due('c$i', t0.addDays(i), 100),
        ],
        overdue: <OverdueItem>[od('o', 100, 2)],
      );
      for (final n in p) {
        final gap = t0.daysBetween(n.date);
        expect(gap, inInclusiveRange(0, notificationWindowDays - 1));
      }
    });
  });

  group('excluded rows', () {
    test('S8-P7 paid rows never notify; a partial notifies the remainder', () {
      final p = plan(
        prefs: allOn,
        rows: <DueRowItem>[
          due('paid', t0, 3500, paidRs: 3500),
          due('over', t0, 3500, paidRs: 4000),
          due('part', t0, 3500, paidRs: 1000),
        ],
      );
      final rem = ofKind(p, NotificationKind.installment).toList();
      expect(rem.map((PlannedNotification n) => n.contractId), <String>['part']);
      expect(rem.single.body, contains('₹2,500 due today'));
      expect(ofKind(p, NotificationKind.digest).single.body,
          '1 collection due today · ₹2,500');
    });

    test('S8-P8 auto-extension rows are excluded from every kind', () {
      final p = plan(
        prefs: allOn,
        rows: <DueRowItem>[due('x', t0.addDays(2), 5000, ext: true)],
      );
      expect(p, isEmpty);
    });

    for (final s in <ContractStatus>[
      ContractStatus.closed,
      ContractStatus.rolledOver,
      ContractStatus.cancelled,
    ]) {
      test('S8-P9 ${s.name} loans are excluded', () {
        final p = plan(
          prefs: allOn,
          rows: <DueRowItem>[
            due('h', t0, 5000, status: s),
            due('h2', t0.addDays(-2), 5000, status: s), // never in the nudge
          ],
        );
        expect(p, isEmpty, reason: s.name);
      });
    }
  });

  group('overdue nudge', () {
    test('S8-P10 nothing overdue and nothing due → no nudge at all', () {
      final p = plan(rows: const <DueRowItem>[]);
      expect(p, isEmpty);
    });

    test('S8-P11 a row due today is not overdue today, only from tomorrow', () {
      final p = plan(
        prefs: const NotificationPrefs(digestEnabled: false),
        rows: <DueRowItem>[due('a', t0, 3000)],
      );
      final n = ofKind(p, NotificationKind.overdue).toList();
      expect(n.first.date, t0.addDays(1));
      expect(n.first.body, '1 overdue · ₹3,000 · highest 1 day');
      expect(n.first.id, overdueIdBase + 1);
      expect(n, hasLength(notificationWindowDays - 1));
    });

    test('S8-P12 overdue today: copy sums and takes the max age', () {
      final p = plan(
        overdue: <OverdueItem>[od('a', 20000, 5), od('b', 5500, 2)],
      );
      final first = ofKind(p, NotificationKind.overdue).first;
      expect(first.date, t0);
      expect(first.body, '2 overdue · ₹25,500 · highest 5 days');
      final last = ofKind(p, NotificationKind.overdue).last;
      expect(last.body, '2 overdue · ₹25,500 · highest 18 days');
    });
  });

  group('prefs', () {
    test('S8-P13 every kind off → nothing planned despite lots of data', () {
      final p = plan(
        prefs: const NotificationPrefs(
          digestEnabled: false,
          overdueNudgeEnabled: false,
        ),
        rows: <DueRowItem>[for (var i = 0; i < 14; i++) due('c$i', t0.addDays(i), 100)],
        overdue: <OverdueItem>[od('o', 100, 3)],
      );
      expect(p, isEmpty);
    });

    test('S8-P14 per-installment is off by default', () {
      final p = plan(rows: <DueRowItem>[due('a', t0, 100)]);
      expect(ofKind(p, NotificationKind.installment), isEmpty);
      expect(ofKind(p, NotificationKind.digest), hasLength(1));
    });
  });

  test('S8-P15 the 300 cap: reminders stop at 300, digests still count all',
      () {
    final rows = <DueRowItem>[
      for (var i = 0; i < 301; i++) due('c$i', t0.addDays(i % 14), 100),
    ];
    final p = plan(
      prefs: allOn.copyWith(overdueNudgeEnabled: false),
      rows: rows,
    );
    final rem = ofKind(p, NotificationKind.installment).toList();
    expect(rem, hasLength(maxInstallmentReminders));
    expect(rem.first.id, installmentIdBase);
    expect(rem.last.id, installmentIdBase + maxInstallmentReminders - 1);
    final ids = p.map((PlannedNotification n) => n.id).toSet();
    expect(ids, hasLength(p.length), reason: 'ids are unique');
    final digests = ofKind(p, NotificationKind.digest).toList();
    var counted = 0;
    for (final dg in digests) {
      counted += int.parse(dg.body.split(' ').first);
    }
    expect(counted, 301);
    // Under Android's 500 limit with digests and nudges included.
    expect(p.length + notificationWindowDays, lessThan(500));
  });

  group('ids', () {
    test('S8-P16 stable across re-plans with the same inputs', () {
      List<PlannedNotification> once() => plan(
        prefs: allOn,
        rows: <DueRowItem>[due('a', t0, 100), due('b', t0.addDays(3), 200)],
        overdue: <OverdueItem>[od('o', 50, 1)],
      );
      expect(once(), once());
      expect(
        once().map((PlannedNotification n) => n.id),
        once().map((PlannedNotification n) => n.id),
      );
    });

    test('S8-P17 paying a later row does not shift digest/nudge ids', () {
      final before = plan(
        rows: <DueRowItem>[due('a', t0, 100), due('b', t0.addDays(3), 200)],
      );
      final after = plan(
        rows: <DueRowItem>[
          due('a', t0, 100),
          due('b', t0.addDays(3), 200, paidRs: 200),
        ],
      );
      expect(
        ofKind(after, NotificationKind.digest).single.id,
        ofKind(before, NotificationKind.digest).first.id,
      );
    });

    test('S8-P18 another company: same id scheme, its own title', () {
      final rows = <DueRowItem>[due('a', t0, 100)];
      final a = plan(rows: rows, company: 'A Co');
      final b = plan(rows: rows, company: 'B Co');
      // By design ids are per plan (the scheduler replaces the whole set on
      // a switch); only the title tells the companies apart.
      expect(a.map((PlannedNotification n) => n.id),
          b.map((PlannedNotification n) => n.id));
      expect(b.every((PlannedNotification n) => n.title == 'B Co'), isTrue);
    });

    // Rewritten in attempt 2 (design choice, see the Sprint 8 attempt-2 log):
    // ids stay per plan (S8-P18); company isolation comes from the plan
    // carrying its company id (deep links are tagged `c=` and dropped for
    // another company) and from the scheduler cancelling every pending AND
    // delivered notification as soon as the active company changes.
    test(
      'S8-P19 every entry names its company, so a delivered A notification is '
      'never opened inside B',
      () {
        final rows = <DueRowItem>[due('a', t0, 100)];
        List<PlannedNotification> forCompany(String cid) =>
            planCollectionNotifications(
              prefs: allOn,
              today: t0,
              nowMinuteOfDay: 7 * 60,
              rows: rows,
              overdue: <OverdueItem>[od('z', 100, 2)],
              companyName: cid,
              companyId: cid,
            );
        final a = forCompany('A');
        final b = forCompany('B');
        expect(a.every((PlannedNotification n) => n.companyId == 'A'), isTrue);
        expect(b.every((PlannedNotification n) => n.companyId == 'B'), isTrue);
        expect(a.first == b.first, isFalse);
      },
    );
  });

  group('midnight IST and passed digest time', () {
    test("S8-P20 23:59: today's slot skipped, first slot is tomorrow", () {
      final p = plan(now: 23 * 60 + 59, rows: <DueRowItem>[
        due('a', t0, 100),
        due('b', t0.addDays(1), 200),
      ]);
      final dg = ofKind(p, NotificationKind.digest).toList();
      expect(dg.single.date, t0.addDays(1));
      expect(dg.single.id, digestIdBase + 1);
    });

    test('S8-P21 00:00 next day: the new today is planned as day 0', () {
      final tomorrow = t0.addDays(1);
      final p = plan(today: tomorrow, now: 0, rows: <DueRowItem>[
        due('b', tomorrow, 200),
      ]);
      final dg = ofKind(p, NotificationKind.digest).single;
      expect(dg.date, tomorrow);
      expect(dg.id, digestIdBase);
    });

    test('S8-P22 digest time 00:00 at 00:00 counts as passed', () {
      final p = plan(
        prefs: const NotificationPrefs(digestTime: '00:00'),
        now: 0,
        rows: <DueRowItem>[due('a', t0, 100)],
      );
      expect(p.where((PlannedNotification n) => n.date == t0), isEmpty);
      expect(p.first.date, t0.addDays(1));
    });

    test('S8-P23 one minute before the digest time still plans today', () {
      final p = plan(
        prefs: const NotificationPrefs(digestTime: '23:59'),
        now: 23 * 60 + 58,
        rows: <DueRowItem>[due('a', t0, 100)],
      );
      expect(ofKind(p, NotificationKind.digest).single.date, t0);
    });

    test('S8-P24 digest time already passed: today has no nudge either', () {
      final p = plan(
        now: 8 * 60,
        overdue: <OverdueItem>[od('o', 100, 4)],
      );
      final n = ofKind(p, NotificationKind.overdue).toList();
      expect(n.first.date, t0.addDays(1));
      expect(n.first.body, '1 overdue · ₹100 · highest 5 days');
      expect(n, hasLength(notificationWindowDays - 1));
    });
  });
}
