// Tester (Sprint 2): independent checks of upfront, schedule, validation.
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import '../ledger_fixtures.dart';

void main() {
  group('upfront', () {
    test('1L flat 7,000 -> net 93,000, 7.00%', () {
      final up = computeUpfront(rs(100000), UpfrontMode.flat, 700000);
      expect(up, rs(7000));
      expect(computeNetDisbursed(rs(100000), up), rs(93000));
      expect(effectiveBps(up, rs(100000)), 700);
    });

    test('percent 7% (700 bps) of 1L == 7,000', () {
      expect(computeUpfront(rs(100000), UpfrontMode.percent, 700), rs(7000));
    });

    test('percent rounds half-up on paise', () {
      // 333 paise * 50 bps / 10000 = 1.665 -> 2
      expect(
        computeUpfront(const Money(333), UpfrontMode.percent, 50),
        const Money(2),
      );
    });
  });

  group('schedule', () {
    test('1L at 30k -> 30k,30k,30k,10k; maturity = last due', () {
      final s = generateSchedule(
        sanctioned: rs(100000),
        installmentAmount: rs(30000),
        frequency: Frequency.weekly,
        firstDueDate: d(2023, 10, 31),
        preferredWeekday: 2,
      );
      expect(s.map((p) => p.amount).toList(), [
        rs(30000),
        rs(30000),
        rs(30000),
        rs(10000),
      ]);
      expect(s.map((p) => p.seq).toList(), [1, 2, 3, 4]);
      expect(s.last.dueDate, d(2023, 11, 21));
      expect(installmentCount(rs(100000), rs(30000)), 4);
    });

    test('exact division has no remainder row', () {
      expect(installmentCount(rs(100000), rs(10000)), 10);
    });

    test('monthly on the 31st clamps through Feb then returns to 31', () {
      final s = generateSchedule(
        sanctioned: rs(40000),
        installmentAmount: rs(10000),
        frequency: Frequency.monthly,
        firstDueDate: d(2024, 1, 31),
        preferredMonthDay: 31,
      );
      expect(s.map((p) => p.dueDate).toList(), [
        d(2024, 1, 31),
        d(2024, 2, 29),
        d(2024, 3, 31),
        d(2024, 4, 30),
      ]);
    });

    test('monthly 30th in non-leap Feb clamps to 28', () {
      final s = generateSchedule(
        sanctioned: rs(20000),
        installmentAmount: rs(10000),
        frequency: Frequency.monthly,
        firstDueDate: d(2023, 1, 30),
        preferredMonthDay: 30,
      );
      expect(s[1].dueDate, d(2023, 2, 28));
    });

    test('daily steps one day', () {
      final s = generateSchedule(
        sanctioned: rs(3000),
        installmentAmount: rs(1000),
        frequency: Frequency.daily,
        firstDueDate: d(2023, 12, 31),
      );
      expect(s.last.dueDate, d(2024, 1, 2));
    });

    test('installmentCount throws on zero installment', () {
      expect(() => installmentCount(rs(100), Money.zero), throwsArgumentError);
    });
  });

  group('validation', () {
    List<ValidationError> v({
      Money? sanctioned,
      UpfrontMode mode = UpfrontMode.flat,
      int input = 700000,
      Money? inst,
      Frequency f = Frequency.weekly,
      int? wd = 2,
      int? md,
    }) => validateContractTerms(
      sanctioned: sanctioned ?? rs(100000),
      upfrontMode: mode,
      upfrontInput: input,
      installmentAmount: inst ?? rs(10000),
      frequency: f,
      preferredWeekday: wd,
      preferredMonthDay: md,
      firstDueDate: d(2023, 10, 31),
      disbursedOn: d(2023, 10, 24),
    );

    test('valid terms pass', () => expect(v(), isEmpty));
    test(
      'sanctioned 0 rejected',
      () => expect(v(sanctioned: Money.zero), isNotEmpty),
    );
    test('upfront negative rejected', () => expect(v(input: -1), isNotEmpty));
    test(
      'upfront == sanctioned rejected',
      () => expect(v(input: 10000000), isNotEmpty),
    );
    test(
      'percent > 100 rejected',
      () => expect(v(mode: UpfrontMode.percent, input: 10001), isNotEmpty),
    );
    test(
      'installment > sanctioned rejected',
      () => expect(v(inst: rs(100001)), isNotEmpty),
    );
    test(
      'installment 0 rejected',
      () => expect(v(inst: Money.zero), isNotEmpty),
    );
    test(
      'weekly without weekday rejected',
      () => expect(v(wd: null), isNotEmpty),
    );
    test(
      'monthly without day rejected',
      () => expect(v(f: Frequency.monthly, wd: null), isNotEmpty),
    );
    test('payment above outstanding rejected, 0 rejected', () {
      expect(validatePaymentAmount(rs(5001), rs(5000)), isNotEmpty);
      expect(validatePaymentAmount(Money.zero, rs(5000)), isNotEmpty);
      expect(validatePaymentAmount(rs(5000), rs(5000)), isEmpty);
    });
  });
}
