import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import 'ledger_fixtures.dart';

List<ValidationError> _validate({
  Money? sanctioned,
  UpfrontMode mode = UpfrontMode.flat,
  int input = 700000,
  Money? installment,
  Frequency frequency = Frequency.weekly,
  int? weekday = 2,
  int? monthDay,
  CivilDate? firstDue,
  CivilDate? disbursedOn,
}) => validateContractTerms(
  sanctioned: sanctioned ?? rs(100000),
  upfrontMode: mode,
  upfrontInput: input,
  installmentAmount: installment ?? rs(10000),
  frequency: frequency,
  preferredWeekday: weekday,
  preferredMonthDay: monthDay,
  firstDueDate: firstDue ?? d(2023, 10, 31),
  disbursedOn: disbursedOn ?? d(2023, 10, 24),
);

Set<String> _fields(List<ValidationError> errors) =>
    errors.map((ValidationError e) => e.field).toSet();

void main() {
  group('upfront and net', () {
    test('flat ₹7,000 on ₹1,00,000 → net ₹93,000, 7.00%', () {
      final upfront = computeUpfront(rs(100000), UpfrontMode.flat, 700000);
      expect(upfront, rs(7000));
      expect(computeNetDisbursed(rs(100000), upfront), rs(93000));
      expect(effectiveBps(upfront, rs(100000)), 700);
    });

    test('percent 7.5% on ₹1,00,000 → ₹7,500', () {
      final upfront = computeUpfront(rs(100000), UpfrontMode.percent, 750);
      expect(upfront, rs(7500));
      expect(computeNetDisbursed(rs(100000), upfront), rs(92500));
      expect(effectiveBps(upfront, rs(100000)), 750);
    });

    test('percent rounds half-up to whole paise', () {
      // 333 paise × 150 bps = 4.995 paise → 5.
      expect(
        computeUpfront(const Money(333), UpfrontMode.percent, 150),
        const Money(5),
      );
      // 331 × 150 / 10000 = 4.965 → 5; 329 → 4.935 → 5; 300 → 4.5 → 5.
      expect(
        computeUpfront(const Money(300), UpfrontMode.percent, 150),
        const Money(5),
      );
      // 290 × 150 / 10000 = 4.35 → 4.
      expect(
        computeUpfront(const Money(290), UpfrontMode.percent, 150),
        const Money(4),
      );
    });

    test('effectiveBps rounds half-up and handles zero sanctioned', () {
      // 1 / 3 of 100% = 3333.33 bps → 3333; 2/3 → 6666.67 → 6667.
      expect(effectiveBps(const Money(1), const Money(3)), 3333);
      expect(effectiveBps(const Money(2), const Money(3)), 6667);
      expect(effectiveBps(rs(10), Money.zero), 0);
      expect(effectiveBps(const Money(-1), const Money(3)), -3333);
    });
  });

  group('validateContractTerms', () {
    test('valid terms → no errors', () {
      expect(_validate(), isEmpty);
      expect(_validate(mode: UpfrontMode.percent, input: 750), isEmpty);
      expect(_validate(input: 0), isEmpty);
      expect(_validate(frequency: Frequency.daily, weekday: null), isEmpty);
      expect(
        _validate(frequency: Frequency.monthly, weekday: null, monthDay: 31),
        isEmpty,
      );
      expect(
        _validate(firstDue: d(2023, 10, 24), disbursedOn: d(2023, 10, 24)),
        isEmpty,
        reason: 'first due on the disbursement day is allowed',
      );
    });

    test('sanctioned must be > 0', () {
      final errors = _validate(sanctioned: Money.zero);
      expect(_fields(errors), <String>{LedgerFields.sanctioned});
      expect(_fields(_validate(sanctioned: rs(-5))), <String>{
        LedgerFields.sanctioned,
      });
    });

    test('flat upfront: rejects ≥ sanctioned and negative', () {
      expect(_fields(_validate(input: 10000000)), <String>{
        LedgerFields.upfrontInput,
      });
      expect(_fields(_validate(input: 10000001)), <String>{
        LedgerFields.upfrontInput,
      });
      expect(_validate(input: 9999999), isEmpty);
      final negative = _validate(input: -1);
      expect(negative.single.field, LedgerFields.upfrontInput);
      expect(negative.single.message, contains('negative'));
    });

    test('percent upfront: rejects > 100% and negative', () {
      final over = _validate(mode: UpfrontMode.percent, input: 10001);
      expect(over.single.field, LedgerFields.upfrontInput);
      expect(over.single.message, contains('100%'));
      expect(_fields(_validate(mode: UpfrontMode.percent, input: -1)), <String>{
        LedgerFields.upfrontInput,
      });
    });

    test('percent upfront: 100% computes upfront == sanctioned → rejected', () {
      final errors = _validate(mode: UpfrontMode.percent, input: 10000);
      expect(errors.single.field, LedgerFields.upfrontInput);
      expect(errors.single.message, contains('less than'));
    });

    test('percent rounding can push upfront to sanctioned → rejected', () {
      // 1 paise at 99.99% rounds to 1 paise == sanctioned.
      final errors = _validate(
        sanctioned: const Money(1),
        mode: UpfrontMode.percent,
        input: 9999,
        installment: const Money(1),
      );
      expect(_fields(errors), <String>{LedgerFields.upfrontInput});
    });

    test('installment must be > 0 and ≤ sanctioned', () {
      expect(_fields(_validate(installment: Money.zero)), <String>{
        LedgerFields.installmentAmount,
      });
      expect(_fields(_validate(installment: rs(100001))), <String>{
        LedgerFields.installmentAmount,
      });
      expect(_validate(installment: rs(100000)), isEmpty);
    });

    test('weekly requires weekday 1–7', () {
      for (final bad in <int?>[null, 0, 8]) {
        expect(_fields(_validate(weekday: bad)), <String>{
          LedgerFields.preferredWeekday,
        });
      }
      expect(_validate(weekday: 1), isEmpty);
      expect(_validate(weekday: 7), isEmpty);
    });

    test('monthly requires month-day 1–31', () {
      for (final bad in <int?>[null, 0, 32]) {
        expect(
          _fields(_validate(frequency: Frequency.monthly, monthDay: bad)),
          <String>{LedgerFields.preferredMonthDay},
        );
      }
      expect(_validate(frequency: Frequency.monthly, monthDay: 1), isEmpty);
    });

    test('366 installments OK, 367 rejected', () {
      expect(
        _validate(
          sanctioned: const Money(366),
          installment: const Money(1),
          input: 0,
        ),
        isEmpty,
      );
      final errors = _validate(
        sanctioned: const Money(367),
        installment: const Money(1),
        input: 0,
      );
      expect(errors.single.field, LedgerFields.installmentCount);
      expect(errors.single.message, contains('367'));
    });

    test('first due before disbursement rejected', () {
      expect(
        _fields(
          _validate(firstDue: d(2023, 10, 23), disbursedOn: d(2023, 10, 24)),
        ),
        <String>{LedgerFields.firstDueDate},
      );
    });

    test('reports every failure at once', () {
      final errors = _validate(
        sanctioned: Money.zero,
        installment: Money.zero,
        weekday: null,
        firstDue: d(2023, 1, 1),
      );
      expect(_fields(errors), <String>{
        LedgerFields.sanctioned,
        LedgerFields.installmentAmount,
        LedgerFields.preferredWeekday,
        LedgerFields.firstDueDate,
      });
    });

    test('ValidationError equality and toString', () {
      const a = ValidationError('f', 'm');
      expect(a, const ValidationError('f', 'm'));
      expect(a == const ValidationError('f', 'x'), isFalse);
      expect(a.hashCode, const ValidationError('f', 'm').hashCode);
      expect(a.toString(), 'ValidationError(f: m)');
    });
  });

  group('validatePaymentAmount', () {
    test('accepts 0 < amount ≤ outstanding', () {
      expect(validatePaymentAmount(rs(1), rs(10)), isEmpty);
      expect(validatePaymentAmount(rs(10), rs(10)), isEmpty);
    });

    test('rejects zero / negative', () {
      expect(
        validatePaymentAmount(Money.zero, rs(10)).single.field,
        LedgerFields.amount,
      );
      expect(validatePaymentAmount(rs(-1), rs(10)), hasLength(1));
    });

    test('rejects above outstanding with formatted amount', () {
      final errors = validatePaymentAmount(rs(18001), rs(18000));
      expect(errors.single.message, contains('₹18,000'));
    });
  });
}
