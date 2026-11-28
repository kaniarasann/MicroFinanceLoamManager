import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import 'ledger_fixtures.dart';

final CivilDate today = d(2023, 11, 7);

DueRowItem row(
  String contractId,
  CivilDate due,
  int amountRs, {
  int paidRs = 0,
  String name = 'Suresh Verma',
  int loanNo = 4,
  bool isExtension = false,
  ContractStatus status = ContractStatus.active,
  int seq = 1,
}) => DueRowItem(
  contractId: contractId,
  borrowerId: 'b-$contractId',
  borrowerName: name,
  borrowerPhoneE164: '+919845012890',
  loanNo: loanNo,
  frequency: Frequency.weekly,
  seq: seq,
  dueDate: due,
  amount: rs(amountRs),
  paid: rs(paidRs),
  status: paidRs >= amountRs ? RowStatus.paid : RowStatus.upcoming,
  daysOverdue: 0,
  isExtension: isExtension,
  cyclesTotal: 10,
  contractStatus: status,
);

OverdueItem late(String contractId, int amountRs, int days) => OverdueItem(
  contractId: contractId,
  borrowerName: 'Late Borrower',
  loanNo: 9,
  seq: 1,
  dueDate: today.addDays(-days),
  amount: rs(amountRs),
  daysOverdue: days,
);

const NotificationPrefs allOn = NotificationPrefs(perInstallmentEnabled: true);

/// 07:00 IST: before the default 08:00 digest.
const int early = 7 * 60;

List<PlannedNotification> plan({
  NotificationPrefs prefs = allOn,
  int now = early,
  List<DueRowItem> rows = const <DueRowItem>[],
  List<OverdueItem> overdue = const <OverdueItem>[],
  int windowDays = notificationWindowDays,
  int maxReminders = maxInstallmentReminders,
}) => planCollectionNotifications(
  prefs: prefs,
  today: today,
  nowMinuteOfDay: now,
  rows: rows,
  overdue: overdue,
  companyName: 'Sri Lakshmi Finance',
  windowDays: windowDays,
  maxReminders: maxReminders,
);

Iterable<PlannedNotification> ofKind(
  List<PlannedNotification> p,
  NotificationKind k,
) => p.where((PlannedNotification n) => n.kind == k);

void main() {
  group('DigestTime', () {
    test('parses HH:mm and falls back to 08:00', () {
      expect(DigestTime.parse('06:30'), const DigestTime(6, 30));
      expect(DigestTime.parse('23:59').minuteOfDay, 23 * 60 + 59);
      expect(DigestTime.parse('24:00'), DigestTime.fallback);
      expect(DigestTime.parse('8:00'), DigestTime.fallback);
      expect(DigestTime.parse(null), DigestTime.fallback);
      expect(DigestTime.parse('abc'), DigestTime.fallback);
    });

    test('stored and display forms', () {
      expect(const DigestTime(6, 5).stored, '06:05');
      expect(const DigestTime(0, 0).display, '12:00 AM');
      expect(const DigestTime(8, 0).display, '8:00 AM');
      expect(const DigestTime(12, 30).display, '12:30 PM');
      expect(const DigestTime(18, 0).display, '6:00 PM');
      expect(const DigestTime(18, 0).toString(), '18:00');
      expect(const DigestTime(8, 0).hashCode, DigestTime.fallback.hashCode);
    });
  });

  group('digest', () {
    test('sums open rows per day with the spec copy', () {
      final p = plan(
        prefs: const NotificationPrefs(),
        rows: <DueRowItem>[
          row('c1', today, 3500),
          row('c2', today, 5000, paidRs: 1000),
          row('c3', today.addDays(2), 2000),
        ],
      );
      final digests = ofKind(p, NotificationKind.digest).toList();
      expect(digests, hasLength(2));
      expect(digests[0].date, today);
      expect(digests[0].id, digestIdBase);
      expect(digests[0].title, 'Sri Lakshmi Finance');
      expect(digests[0].body, '2 collections due today · ₹7,500');
      expect(digests[0].time, DigestTime.fallback);
      expect(digests[1].date, today.addDays(2));
      expect(digests[1].id, digestIdBase + 2);
      expect(digests[1].body, '1 collection due today · ₹2,000');
    });

    test('fully paid, extension, history and out-of-window rows never '
        'notify', () {
      final p = plan(
        prefs: const NotificationPrefs(overdueNudgeEnabled: false),
        rows: <DueRowItem>[
          row('c1', today, 3500, paidRs: 3500),
          row('c2', today.addDays(1), 3500, isExtension: true),
          row('c3', today.addDays(1), 3500, status: ContractStatus.closed),
          row('c4', today.addDays(-1), 3500),
          row('c5', today.addDays(notificationWindowDays), 3500),
        ],
      );
      expect(p, isEmpty);
    });

    test('today is skipped once the digest time has passed', () {
      final p = plan(
        prefs: const NotificationPrefs(
          digestTime: '08:00',
          overdueNudgeEnabled: false,
        ),
        now: 8 * 60,
        rows: <DueRowItem>[
          row('c1', today, 3500),
          row('c2', today.addDays(1), 1000),
        ],
      );
      expect(p.map((PlannedNotification n) => n.date), <CivilDate>[
        today.addDays(1),
      ]);
    });

    test('custom time is used for every kind', () {
      final p = plan(
        prefs: const NotificationPrefs(
          digestTime: '18:15',
          perInstallmentEnabled: true,
        ),
        now: 12 * 60,
        windowDays: 1,
        rows: <DueRowItem>[row('c1', today, 3500)],
        overdue: <OverdueItem>[late('c9', 100, 2)],
      );
      expect(p, hasLength(3));
      expect(
        p.every((PlannedNotification n) => n.time == const DigestTime(18, 15)),
        isTrue,
      );
    });

    test('nothing at all is planned within a 14-day window past day 13', () {
      final p = plan(
        rows: <DueRowItem>[row('c1', today.addDays(13), 100)],
        prefs: const NotificationPrefs(overdueNudgeEnabled: false),
      );
      expect(p.single.date, today.addDays(13));
      expect(p.single.id, digestIdBase + 13);
    });
  });

  group('per-installment reminders', () {
    test('off by default', () {
      final p = plan(
        prefs: const NotificationPrefs(),
        rows: <DueRowItem>[row('c1', today, 3500)],
      );
      expect(ofKind(p, NotificationKind.installment), isEmpty);
    });

    test('one per open row with the remaining amount and the contract id', () {
      final p = plan(
        prefs: const NotificationPrefs(
          digestEnabled: false,
          overdueNudgeEnabled: false,
          perInstallmentEnabled: true,
        ),
        rows: <DueRowItem>[
          row('c1', today, 3500, paidRs: 500),
          row('c2', today.addDays(1), 1234, name: 'Anita Sharma', loanNo: 12),
        ],
      );
      expect(p, hasLength(2));
      expect(p[0].body, 'Suresh Verma · Loan #04 · ₹3,000 due today');
      expect(p[0].contractId, 'c1');
      expect(p[0].id, installmentIdBase);
      expect(p[1].body, 'Anita Sharma · Loan #12 · ₹1,234 due today');
      expect(p[1].id, installmentIdBase + 1);
      expect(p[1].date, today.addDays(1));
    });

    test('capped at maxReminders', () {
      final p = plan(
        prefs: const NotificationPrefs(
          digestEnabled: false,
          overdueNudgeEnabled: false,
          perInstallmentEnabled: true,
        ),
        maxReminders: 2,
        rows: <DueRowItem>[
          row('c1', today, 100),
          row('c2', today, 100),
          row('c3', today.addDays(1), 100),
        ],
      );
      expect(p, hasLength(2));
      expect(p.every((PlannedNotification n) => n.date == today), isTrue);
    });
  });

  group('overdue nudge', () {
    test("today's overdue rows age by a day per day", () {
      final p = plan(
        prefs: const NotificationPrefs(digestEnabled: false),
        windowDays: 3,
        overdue: <OverdueItem>[late('c1', 25000, 5), late('c2', 500, 1)],
      );
      expect(p.map((PlannedNotification n) => n.body).toList(), <String>[
        '2 overdue · ₹25,500 · highest 5 days',
        '2 overdue · ₹25,500 · highest 6 days',
        '2 overdue · ₹25,500 · highest 7 days',
      ]);
      expect(p.first.id, overdueIdBase);
      expect(p.last.id, overdueIdBase + 2);
    });

    test('open rows join the nudge the day after they are due', () {
      final p = plan(
        prefs: const NotificationPrefs(digestEnabled: false),
        windowDays: 3,
        rows: <DueRowItem>[row('c1', today, 3500, paidRs: 500)],
      );
      expect(p, hasLength(2));
      expect(p[0].date, today.addDays(1));
      expect(p[0].body, '1 overdue · ₹3,000 · highest 1 day');
      expect(p[1].body, '1 overdue · ₹3,000 · highest 2 days');
    });

    test('the highest count takes the larger of old and new rows', () {
      final p = plan(
        prefs: const NotificationPrefs(digestEnabled: false),
        windowDays: 4,
        overdue: <OverdueItem>[late('c9', 100, 0)],
        rows: <DueRowItem>[row('c1', today, 100)],
      );
      // Day 3: old row 0+3 = 3 days, today's row 3 days.
      expect(p.last.body, '2 overdue · ₹200 · highest 3 days');
      // Day 0: only the old row.
      expect(p.first.body, '1 overdue · ₹100 · highest 0 days');
    });

    test('no nudge without overdue items, or when disabled', () {
      expect(
        plan(
          rows: <DueRowItem>[row('c1', today.addDays(1), 100)],
        ).where((PlannedNotification n) => n.date == today),
        isEmpty,
      );
      expect(
        ofKind(
          plan(
            prefs: const NotificationPrefs(overdueNudgeEnabled: false),
            overdue: <OverdueItem>[late('c1', 100, 2)],
          ),
          NotificationKind.overdue,
        ),
        isEmpty,
      );
    });
  });

  test('everything off → empty plan', () {
    expect(
      plan(
        prefs: const NotificationPrefs(
          digestEnabled: false,
          overdueNudgeEnabled: false,
        ),
        rows: <DueRowItem>[row('c1', today, 100)],
        overdue: <OverdueItem>[late('c2', 100, 2)],
      ),
      isEmpty,
    );
  });

  test('plans are value-comparable (unchanged inputs → equal plans)', () {
    List<PlannedNotification> make() => plan(
      rows: <DueRowItem>[row('c1', today, 100)],
      overdue: <OverdueItem>[late('c2', 100, 2)],
    );
    expect(make(), make());
    final a = make().first;
    expect(a.hashCode, make().first.hashCode);
    expect(a.toString(), contains('digest'));
    expect(a == make().last, isFalse);
  });
}
