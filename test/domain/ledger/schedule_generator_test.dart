import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import 'ledger_fixtures.dart';

List<Money> _amounts(List<PlannedInstallment> s) =>
    s.map((PlannedInstallment p) => p.amount).toList();

List<CivilDate> _dates(List<PlannedInstallment> s) =>
    s.map((PlannedInstallment p) => p.dueDate).toList();

void main() {
  group('installmentCount', () {
    test('ceil(sanctioned / installment)', () {
      expect(installmentCount(rs(100000), rs(30000)), 4);
      expect(installmentCount(rs(100000), rs(10000)), 10);
      expect(installmentCount(rs(100000), rs(100000)), 1);
      expect(installmentCount(const Money(10000001), rs(10000)), 11);
    });

    test('throws on non-positive inputs', () {
      expect(() => installmentCount(Money.zero, rs(1)), throwsArgumentError);
      expect(() => installmentCount(rs(1), Money.zero), throwsArgumentError);
    });
  });

  group('amounts', () {
    test('₹1,00,000 at ₹30,000 → 30k, 30k, 30k, 10k', () {
      final s = generateSchedule(
        sanctioned: rs(100000),
        installmentAmount: rs(30000),
        frequency: Frequency.daily,
        firstDueDate: d(2024, 1, 1),
      );
      expect(_amounts(s), <Money>[rs(30000), rs(30000), rs(30000), rs(10000)]);
      expect(s.map((PlannedInstallment p) => p.seq), <int>[1, 2, 3, 4]);
    });

    test('₹1,00,000 at ₹10,000 → 10 × 10k', () {
      final s = generateSchedule(
        sanctioned: rs(100000),
        installmentAmount: rs(10000),
        frequency: Frequency.daily,
        firstDueDate: d(2024, 1, 1),
      );
      expect(_amounts(s), List<Money>.filled(10, rs(10000)));
    });

    test('1-paise remainder lands on the last row', () {
      final s = generateSchedule(
        sanctioned: const Money(10000001),
        installmentAmount: rs(10000),
        frequency: Frequency.daily,
        firstDueDate: d(2024, 1, 1),
      );
      expect(s, hasLength(11));
      expect(s.last.amount, const Money(1));
      expect(Money.sum(_amounts(s)), const Money(10000001));
    });

    test('not divisible: sum always equals sanctioned', () {
      final s = generateSchedule(
        sanctioned: rs(25000),
        installmentAmount: rs(3000),
        frequency: Frequency.daily,
        firstDueDate: d(2024, 1, 1),
      );
      expect(s, hasLength(9));
      expect(s.last.amount, rs(1000));
      expect(Money.sum(_amounts(s)), rs(25000));
    });

    test('366 rows OK, 367 throws', () {
      expect(
        generateSchedule(
          sanctioned: const Money(366),
          installmentAmount: const Money(1),
          frequency: Frequency.daily,
          firstDueDate: d(2024, 1, 1),
        ),
        hasLength(366),
      );
      expect(
        () => generateSchedule(
          sanctioned: const Money(367),
          installmentAmount: const Money(1),
          frequency: Frequency.daily,
          firstDueDate: d(2024, 1, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('dates', () {
    test('daily × 30 steps one day (Sundays not skipped)', () {
      final s = generateSchedule(
        sanctioned: rs(30000),
        installmentAmount: rs(1000),
        frequency: Frequency.daily,
        firstDueDate: d(2024, 2, 15),
      );
      expect(s, hasLength(30));
      expect(s.first.dueDate, d(2024, 2, 15));
      expect(s[14].dueDate, d(2024, 2, 29));
      expect(s.last.dueDate, d(2024, 3, 15));
      for (var i = 1; i < s.length; i++) {
        expect(s[i - 1].dueDate.daysBetween(s[i].dueDate), 1);
      }
    });

    test('weekly Tue from Tue 31 Oct 2023, 1L/10k → last 2 Jan 2024', () {
      final s = generateSchedule(
        sanctioned: rs(100000),
        installmentAmount: rs(10000),
        frequency: Frequency.weekly,
        firstDueDate: d(2023, 10, 31),
        preferredWeekday: 2,
      );
      expect(_dates(s), <CivilDate>[
        d(2023, 10, 31),
        d(2023, 11, 7),
        d(2023, 11, 14),
        d(2023, 11, 21),
        d(2023, 11, 28),
        d(2023, 12, 5),
        d(2023, 12, 12),
        d(2023, 12, 19),
        d(2023, 12, 26),
        d(2024, 1, 2),
      ]);
      expect(s.every((PlannedInstallment p) => p.dueDate.weekday == 2), isTrue);
    });

    test('weekly start not on the preferred weekday rolls forward', () {
      // Wed 1 Nov 2023, preferred Tue → Tue 7 Nov.
      final s = generateSchedule(
        sanctioned: rs(30000),
        installmentAmount: rs(10000),
        frequency: Frequency.weekly,
        firstDueDate: d(2023, 11, 1),
        preferredWeekday: 2,
      );
      expect(_dates(s), <CivilDate>[
        d(2023, 11, 7),
        d(2023, 11, 14),
        d(2023, 11, 21),
      ]);
      // Sun 5 Nov, preferred Mon → Mon 6 Nov.
      final s2 = generateSchedule(
        sanctioned: rs(10000),
        installmentAmount: rs(10000),
        frequency: Frequency.weekly,
        firstDueDate: d(2023, 11, 5),
        preferredWeekday: 1,
      );
      expect(s2.single.dueDate, d(2023, 11, 6));
    });

    test(
      'weekly without a preferred weekday anchors on the first due weekday',
      () {
        final s = generateSchedule(
          sanctioned: rs(20000),
          installmentAmount: rs(10000),
          frequency: Frequency.weekly,
          firstDueDate: d(2023, 11, 1),
        );
        expect(_dates(s), <CivilDate>[d(2023, 11, 1), d(2023, 11, 8)]);
      },
    );

    test('monthly on the 31st across Feb in a leap year (2024)', () {
      final s = generateSchedule(
        sanctioned: rs(40000),
        installmentAmount: rs(10000),
        frequency: Frequency.monthly,
        firstDueDate: d(2024, 1, 10),
        preferredMonthDay: 31,
      );
      expect(_dates(s), <CivilDate>[
        d(2024, 1, 31),
        d(2024, 2, 29),
        d(2024, 3, 31),
        d(2024, 4, 30),
      ]);
    });

    test('monthly on the 31st across Feb in a non-leap year (2023)', () {
      final s = generateSchedule(
        sanctioned: rs(30000),
        installmentAmount: rs(10000),
        frequency: Frequency.monthly,
        firstDueDate: d(2023, 1, 31),
        preferredMonthDay: 31,
      );
      expect(_dates(s), <CivilDate>[
        d(2023, 1, 31),
        d(2023, 2, 28),
        d(2023, 3, 31),
      ]);
    });

    test('monthly first due past the month-day moves to next month', () {
      final s = generateSchedule(
        sanctioned: rs(20000),
        installmentAmount: rs(10000),
        frequency: Frequency.monthly,
        firstDueDate: d(2023, 11, 20),
        preferredMonthDay: 15,
      );
      expect(_dates(s), <CivilDate>[d(2023, 12, 15), d(2024, 1, 15)]);
    });

    test('monthly first due in a short month clamps to its end', () {
      // 29 Feb 2023 does not exist: preferred 30 in Feb → 28 Feb.
      final s = generateSchedule(
        sanctioned: rs(20000),
        installmentAmount: rs(10000),
        frequency: Frequency.monthly,
        firstDueDate: d(2023, 2, 1),
        preferredMonthDay: 30,
      );
      expect(_dates(s), <CivilDate>[d(2023, 2, 28), d(2023, 3, 30)]);
    });

    test('monthly without a preferred day anchors on first due day', () {
      final s = generateSchedule(
        sanctioned: rs(20000),
        installmentAmount: rs(10000),
        frequency: Frequency.monthly,
        firstDueDate: d(2023, 12, 5),
      );
      expect(_dates(s), <CivilDate>[d(2023, 12, 5), d(2024, 1, 5)]);
    });
  });

  group('nextDueDate', () {
    test('daily / weekly / monthly steps', () {
      expect(nextDueDate(d(2023, 12, 31), Frequency.daily), d(2024, 1, 1));
      expect(
        nextDueDate(
          d(2023, 10, 31),
          Frequency.weekly,
          const SchedulePrefs(weekday: 2),
        ),
        d(2023, 11, 7),
      );
      // Off-anchor (rescheduled Fri) → next Tue.
      expect(
        nextDueDate(
          d(2023, 12, 8),
          Frequency.weekly,
          const SchedulePrefs(weekday: 2),
        ),
        d(2023, 12, 12),
      );
      expect(
        nextDueDate(
          d(2024, 2, 29),
          Frequency.monthly,
          const SchedulePrefs(monthDay: 31),
        ),
        d(2024, 3, 31),
      );
      expect(
        nextDueDate(
          d(2024, 3, 10),
          Frequency.monthly,
          const SchedulePrefs(monthDay: 31),
        ),
        d(2024, 3, 31),
      );
      expect(nextDueDate(d(2024, 1, 15), Frequency.monthly), d(2024, 2, 15));
      expect(nextDueDate(d(2024, 1, 15), Frequency.weekly), d(2024, 1, 22));
    });

    test('firstDueOnOrAfter keeps an on-anchor date', () {
      expect(
        firstDueOnOrAfter(
          d(2023, 10, 31),
          Frequency.weekly,
          const SchedulePrefs(weekday: 2),
        ),
        d(2023, 10, 31),
      );
    });

    test('value types', () {
      const a = SchedulePrefs(weekday: 2, monthDay: 3);
      expect(a, const SchedulePrefs(weekday: 2, monthDay: 3));
      expect(a.hashCode, const SchedulePrefs(weekday: 2, monthDay: 3).hashCode);
      expect(a == const SchedulePrefs(weekday: 2), isFalse);
      final p = PlannedInstallment(
        seq: 1,
        dueDate: d(2024, 1, 1),
        amount: rs(1),
      );
      expect(
        p,
        PlannedInstallment(seq: 1, dueDate: d(2024, 1, 1), amount: rs(1)),
      );
      expect(
        p.hashCode,
        PlannedInstallment(
          seq: 1,
          dueDate: d(2024, 1, 1),
          amount: rs(1),
        ).hashCode,
      );
      expect(p.toString(), 'PlannedInstallment(1, 2024-01-01, 100)');
    });
  });
}
