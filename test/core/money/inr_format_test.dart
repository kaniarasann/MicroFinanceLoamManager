import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/inr_format.dart';
import 'package:nordic_ledger/core/money/money.dart';

void main() {
  group('formatInr grouping', () {
    const cases = <int, String>{
      0: '₹0',
      999: '₹999',
      1000: '₹1,000',
      99999: '₹99,999',
      100000: '₹1,00,000',
      1234567: '₹12,34,567',
      10000000: '₹1,00,00,000',
      123456789: '₹12,34,56,789',
    };
    cases.forEach((int rupees, String expected) {
      test('$rupees → $expected', () {
        expect(formatInr(Money.fromRupees(rupees)), expected);
      });
    });

    test('no space after the rupee sign', () {
      final s = formatInr(const Money.fromRupees(100000));
      expect(s.contains(' '), isFalse);
      expect(s.contains(' '), isFalse);
      expect(s[1], '1');
    });
  });

  group('formatInr paise', () {
    test('paise shown only when non-zero', () {
      expect(formatInr(const Money(123450)), '₹1,234.50');
      expect(formatInr(const Money(123405)), '₹1,234.05');
      expect(formatInr(const Money(123400)), '₹1,234');
      expect(formatInr(const Money(1)), '₹0.01');
    });
  });

  group('formatInr negatives', () {
    test('uses U+2212 minus before the sign', () {
      expect(formatInr(const Money.fromRupees(-1000)), '−₹1,000');
      expect(formatInr(const Money(-123450)), '−₹1,234.50');
      expect(formatInr(const Money.fromRupees(-1000)).startsWith('-'), isFalse);
    });
  });

  group('formatInrShort', () {
    const cases = <int, String>{
      0: '₹0',
      500: '₹500',
      999: '₹999',
      1000: '₹1k',
      1500: '₹1.5k',
      50000: '₹50k',
      99999: '₹1L',
      100000: '₹1L',
      150000: '₹1.5L',
      1230000: '₹12.3L',
      9999999: '₹1Cr',
      10000000: '₹1Cr',
      25000000: '₹2.5Cr',
      1500000000: '₹150Cr',
    };
    cases.forEach((int rupees, String expected) {
      test('$rupees → $expected', () {
        expect(formatInrShort(Money.fromRupees(rupees)), expected);
      });
    });

    test('drops trailing .0', () {
      expect(formatInrShort(const Money.fromRupees(200000)), '₹2L');
      expect(formatInrShort(const Money.fromRupees(201000)), '₹2L');
    });

    test('negative', () {
      expect(formatInrShort(const Money.fromRupees(-150000)), '−₹1.5L');
    });
  });

  group('parseInrInput', () {
    test('accepts valid input', () {
      expect(parseInrInput('1,00,000'), const Money.fromRupees(100000));
      expect(parseInrInput('100000'), const Money.fromRupees(100000));
      expect(parseInrInput('1234.5'), const Money(123450));
      expect(parseInrInput('1234.56'), const Money(123456));
      expect(parseInrInput('1234.'), const Money.fromRupees(1234));
      expect(parseInrInput('12,34,567'), const Money.fromRupees(1234567));
      expect(parseInrInput('100,000'), const Money.fromRupees(100000));
      expect(parseInrInput(' ₹500 '), const Money.fromRupees(500));
      expect(parseInrInput('0'), Money.zero);
      expect(parseInrInput('007'), const Money.fromRupees(7));
    });

    test('rejects invalid input', () {
      for (final bad in <String>[
        '',
        '   ',
        'abc',
        '12a',
        '1.234',
        '1..2',
        '.5',
        '-100',
        '1,0,0',
        '1,00,00',
        ',100',
        '100,',
        '1 000',
        '12345678901234',
      ]) {
        expect(parseInrInput(bad), isNull, reason: '"$bad" should be rejected');
      }
    });

    test('round-trips formatInr output', () {
      for (final paise in <int>[0, 99, 100000, 123450, 1234567800]) {
        final text = formatInr(Money(paise));
        expect(parseInrInput(text), Money(paise));
      }
    });
  });

  group('Money', () {
    test('arithmetic and comparisons', () {
      const a = Money(1000);
      const b = Money(250);
      expect(a + b, const Money(1250));
      expect(a - b, const Money(750));
      expect(b - a, const Money(-750));
      expect(a * 3, const Money(3000));
      expect(-a, const Money(-1000));
      expect(a.compareTo(b), greaterThan(0));
      expect(b < a, isTrue);
      expect(Money.zero.isZero, isTrue);
      expect(const Money(-1).isNegative, isTrue);
      expect(const Money.fromRupees(5), const Money(500));
    });

    test('percentOf returns basis points', () {
      expect(
        const Money.fromRupees(25).percentOf(const Money.fromRupees(100)),
        2500,
      );
      expect(
        const Money.fromRupees(1).percentOf(const Money.fromRupees(3)),
        3333,
      );
      expect(const Money.fromRupees(1).percentOf(Money.zero), 0);
    });
  });
}
