import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/time/ist_clock.dart';

void main() {
  group('addMonthsClamped', () {
    test('31 Jan → 28 Feb in a common year', () {
      expect(
        const CivilDate(2023, 1, 31).addMonthsClamped(1),
        const CivilDate(2023, 2, 28),
      );
    });

    test('31 Jan → 29 Feb in a leap year', () {
      expect(
        const CivilDate(2024, 1, 31).addMonthsClamped(1),
        const CivilDate(2024, 2, 29),
      );
    });

    test('preferredDay restores the anchor after a short month', () {
      expect(
        const CivilDate(2023, 2, 28).addMonthsClamped(1, preferredDay: 31),
        const CivilDate(2023, 3, 31),
      );
      expect(
        const CivilDate(2023, 3, 31).addMonthsClamped(1, preferredDay: 31),
        const CivilDate(2023, 4, 30),
      );
    });

    test('crosses year boundaries both ways', () {
      expect(
        const CivilDate(2023, 11, 15).addMonthsClamped(3),
        const CivilDate(2024, 2, 15),
      );
      expect(
        const CivilDate(2024, 1, 31).addMonthsClamped(-2),
        const CivilDate(2023, 11, 30),
      );
      expect(
        const CivilDate(2023, 1, 10).addMonthsClamped(12),
        const CivilDate(2024, 1, 10),
      );
    });
  });

  group('leap years', () {
    test('rules', () {
      expect(CivilDate.isLeapYear(2024), isTrue);
      expect(CivilDate.isLeapYear(2023), isFalse);
      expect(CivilDate.isLeapYear(1900), isFalse);
      expect(CivilDate.isLeapYear(2000), isTrue);
      expect(CivilDate.daysInMonth(2024, 2), 29);
      expect(CivilDate.daysInMonth(2100, 2), 28);
    });

    test('addDays across 29 Feb', () {
      expect(
        const CivilDate(2024, 2, 28).addDays(1),
        const CivilDate(2024, 2, 29),
      );
      expect(
        const CivilDate(2024, 2, 29).addDays(1),
        const CivilDate(2024, 3, 1),
      );
      expect(
        const CivilDate(2024, 3, 1).addDays(-1),
        const CivilDate(2024, 2, 29),
      );
    });
  });

  test('weekday is 1=Mon … 7=Sun', () {
    expect(const CivilDate(2023, 10, 23).weekday, 1); // Monday
    expect(const CivilDate(2023, 10, 24).weekday, 2); // Tuesday
    expect(const CivilDate(2023, 10, 29).weekday, 7); // Sunday
  });

  test('daysBetween is other − this', () {
    const a = CivilDate(2023, 12, 25);
    const b = CivilDate(2024, 1, 5);
    expect(a.daysBetween(b), 11);
    expect(b.daysBetween(a), -11);
    expect(a.daysBetween(a), 0);
    expect(
      const CivilDate(2024, 1, 1).daysBetween(const CivilDate(2025, 1, 1)),
      366,
    );
  });

  group('parse / toString', () {
    test('round-trips', () {
      final d = CivilDate.parse('2023-10-24');
      expect(d, const CivilDate(2023, 10, 24));
      expect(d.toString(), '2023-10-24');
      expect(const CivilDate(2024, 3, 5).toString(), '2024-03-05');
    });

    test('rejects bad input', () {
      for (final bad in <String>[
        '2023-02-30',
        '2023-13-01',
        '2023-00-10',
        '2023-1-5',
        '24-10-2023',
        '',
        '2023-10-24T00:00',
      ]) {
        expect(() => CivilDate.parse(bad), throwsFormatException);
        expect(CivilDate.tryParse(bad), isNull);
      }
      expect(CivilDate.tryParse('2024-02-29'), isNotNull);
    });

    test('compareTo orders dates', () {
      final dates = <CivilDate>[
        const CivilDate(2024, 1, 2),
        const CivilDate(2023, 12, 31),
        const CivilDate(2024, 1, 1),
      ]..sort();
      expect(dates.map((CivilDate d) => d.toString()), <String>[
        '2023-12-31',
        '2024-01-01',
        '2024-01-02',
      ]);
      expect(
        const CivilDate(2023, 1, 1).isBefore(const CivilDate(2023, 1, 2)),
        isTrue,
      );
    });
  });

  group('formatters', () {
    test("'d MMM yyyy'", () {
      expect(formatCivilDate(const CivilDate(2023, 10, 24)), '24 Oct 2023');
      expect(formatCivilDate(const CivilDate(2024, 1, 5)), '5 Jan 2024');
    });

    test("'EEE, d MMM'", () {
      expect(
        formatCivilDateWithWeekday(const CivilDate(2023, 10, 24)),
        'Tue, 24 Oct',
      );
    });
  });

  group('clocks', () {
    test('todayIst uses the injected clock', () {
      final clock = FixedClock.ist(2023, 10, 24, 23, 59);
      expect(CivilDate.todayIst(clock), const CivilDate(2023, 10, 24));
    });

    test('IstClock reports Asia/Kolkata (+05:30)', () {
      final now = IstClock().nowIst();
      expect(now.timeZoneOffset, const Duration(hours: 5, minutes: 30));
    });
  });
}
