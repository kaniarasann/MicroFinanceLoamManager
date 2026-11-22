// Tester-added edge cases for Sprint 1 (core foundation).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/money/inr_format.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/ist_clock.dart';
import 'package:nordic_ledger/core/widgets/currency_field.dart';
import 'package:nordic_ledger/core/widgets/pin_pad.dart';

import '../helpers/pump_app.dart';

TextEditingValue _fmt(String oldText, String newText) =>
    const IndianGroupingFormatter().formatEditUpdate(
      TextEditingValue(
        text: oldText,
        selection: TextSelection.collapsed(offset: oldText.length),
      ),
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      ),
    );

void main() {
  group('INR formatting extremes', () {
    test('zero, single paisa, negative paise-only', () {
      expect(formatInr(Money.zero), '₹0');
      expect(formatInr(const Money(1)), '₹0.01');
      expect(formatInr(const Money(-5)), '−₹0.05');
    });

    test('crore and 13-digit maximum use Indian grouping', () {
      expect(formatInr(const Money.fromRupees(10000000)), '₹1,00,00,000');
      expect(
        formatInr(const Money.fromRupees(9999999999999)),
        '₹99,99,99,99,99,999',
      );
    });

    test('short format unit promotion boundaries', () {
      expect(formatInrShort(const Money.fromRupees(999)), '₹999');
      expect(formatInrShort(const Money.fromRupees(1000)), '₹1k');
      expect(formatInrShort(const Money.fromRupees(99949)), '₹99.9k');
      expect(formatInrShort(const Money.fromRupees(99950)), '₹1L');
      expect(formatInrShort(const Money.fromRupees(9995000)), '₹1Cr');
      expect(formatInrShort(const Money(99950)), '₹1k'); // 999.50 → 1000
      expect(formatInrShort(const Money(-150000000)), '−₹15L');
    });

    test('parse accepts valid forms', () {
      expect(parseInrInput(' ₹ 1,00,000 '), const Money.fromRupees(100000));
      expect(parseInrInput('100,000'), const Money.fromRupees(100000));
      expect(parseInrInput('0'), Money.zero);
      expect(parseInrInput('007'), const Money.fromRupees(7));
      expect(parseInrInput('1234.'), const Money.fromRupees(1234));
      expect(parseInrInput('9999999999999.99'), const Money(999999999999999));
    });

    test('parse rejects malformed, negative and oversized input', () {
      for (final bad in <String>[
        '',
        '₹',
        '-100',
        '−100',
        '.5',
        '1.234',
        '1,00,000,000',
        '10,00',
        '1,,000',
        '1 000',
        'abc',
        '12345678901234',
        '1e5',
      ]) {
        expect(parseInrInput(bad), isNull, reason: bad);
      }
    });

    test('percentOf: zero total and truncation', () {
      expect(const Money(7000).percentOf(Money.zero), 0);
      expect(const Money(1).percentOf(const Money(3)), 3333);
    });
  });

  group('CivilDate month clamping', () {
    const jan31 = CivilDate(2024, 1, 31);

    test('31 Jan → 29 Feb (leap) / 28 Feb (non-leap)', () {
      expect(jan31.addMonthsClamped(1), const CivilDate(2024, 2, 29));
      expect(
        const CivilDate(2023, 1, 31).addMonthsClamped(1),
        const CivilDate(2023, 2, 28),
      );
    });

    test('anchor day restores 31 after a short month', () {
      final feb = jan31.addMonthsClamped(1);
      expect(
        feb.addMonthsClamped(1, preferredDay: 31),
        const CivilDate(2024, 3, 31),
      );
      expect(
        jan31.addMonthsClamped(3, preferredDay: 31),
        const CivilDate(2024, 4, 30),
      );
    });

    test('year rollover forward and backward', () {
      expect(
        const CivilDate(2024, 12, 31).addMonthsClamped(2),
        const CivilDate(2025, 2, 28),
      );
      expect(
        const CivilDate(2024, 3, 31).addMonthsClamped(-1),
        const CivilDate(2024, 2, 29),
      );
      expect(
        const CivilDate(2024, 1, 15).addMonthsClamped(-13),
        const CivilDate(2022, 12, 15),
      );
    });

    test('century leap rules', () {
      expect(CivilDate.isLeapYear(1900), isFalse);
      expect(CivilDate.isLeapYear(2000), isTrue);
      expect(CivilDate.daysInMonth(2100, 2), 28);
      expect(CivilDate.tryParse('2000-02-29'), const CivilDate(2000, 2, 29));
      expect(CivilDate.tryParse('2100-02-29'), isNull);
    });

    test('parse rejects malformed input', () {
      for (final bad in <String>[
        '2024-2-01',
        '2024-13-01',
        '2024-00-10',
        '2024-04-31',
        '24-01-01',
        '2024-01-01T00:00',
        '',
      ]) {
        expect(CivilDate.tryParse(bad), isNull, reason: bad);
      }
      expect(() => CivilDate.parse('2023-02-30'), throwsFormatException);
    });

    test('daysBetween across leap day and sign', () {
      const a = CivilDate(2024, 2, 28);
      const b = CivilDate(2024, 3, 1);
      expect(a.daysBetween(b), 2);
      expect(b.daysBetween(a), -2);
      expect(a.addDays(366), const CivilDate(2025, 2, 28));
    });

    test('IST today at 23:59 and 00:00 boundaries', () {
      expect(
        CivilDate.todayIst(FixedClock.ist(2024, 3, 31, 23, 59)),
        const CivilDate(2024, 3, 31),
      );
      expect(
        CivilDate.todayIst(FixedClock.ist(2024, 4, 1, 0, 0)),
        const CivilDate(2024, 4, 1),
      );
    });

    test('IstClock returns Asia/Kolkata offset +5:30', () {
      final now = IstClock().nowIst();
      expect(now.timeZoneOffset, const Duration(hours: 5, minutes: 30));
    });

    test('date formatters', () {
      expect(formatCivilDate(const CivilDate(2023, 10, 24)), '24 Oct 2023');
      expect(
        formatCivilDateWithWeekday(const CivilDate(2023, 10, 24)),
        'Tue, 24 Oct',
      );
    });
  });

  group('IndianGroupingFormatter', () {
    test('groups as typed', () {
      expect(_fmt('10,000', '100000').text, '1,00,000');
      expect(_fmt('1,00,000', '1,00,0001').text, '10,00,001');
    });

    test('decimals: up to two kept, third rejected', () {
      expect(_fmt('1234', '1234.5').text, '1,234.5');
      expect(_fmt('1,234.56', '1,234.567').text, '1,234.56');
    });

    test('leading "." becomes 0.', () {
      expect(_fmt('', '.').text, '0.');
    });

    test('rejects letters, minus and a second dot', () {
      expect(_fmt('12', '12a').text, '12');
      expect(_fmt('12', '-12').text, '12');
      expect(_fmt('1.2', '1.2.').text, '1.2');
    });

    test('caps at 13 rupee digits', () {
      const max = '9,99,99,99,99,99,999';
      expect(_fmt(max, '${max}9').text, max);
    });

    test('clearing yields empty text', () {
      expect(_fmt('5', '').text, '');
    });
  });

  group('CurrencyField widget', () {
    testWidgets('initialValue renders grouped; negative initial is ignored', (
      WidgetTester tester,
    ) async {
      await pumpThemed(
        tester,
        const Column(
          children: <Widget>[
            CurrencyField(initialValue: Money(12345650)),
            CurrencyField(initialValue: Money(-500)),
          ],
        ),
      );
      expect(find.text('1,23,456.50'), findsOneWidget);
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.last.controller!.text, '');
    });

    testWidgets('invalid keystroke keeps last value; "." reports zero', (
      WidgetTester tester,
    ) async {
      final values = <Money?>[];
      await pumpThemed(tester, CurrencyField(onChanged: values.add));
      await tester.enterText(find.byType(TextField), '500');
      await tester.enterText(find.byType(TextField), '500x');
      await tester.pump();
      expect(find.text('500'), findsOneWidget);
      expect(values.last, const Money.fromRupees(500));

      await tester.enterText(find.byType(TextField), '.');
      await tester.pump();
      expect(find.text('0.'), findsOneWidget);
      expect(values.last, Money.zero);
    });

    testWidgets('label and error text render', (WidgetTester tester) async {
      await pumpThemed(
        tester,
        const CurrencyField(label: 'Sanctioned amount', errorText: 'Required'),
      );
      expect(find.text('Sanctioned amount'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
    });
  });

  group('PinPad edge cases', () {
    testWidgets('disabled pad ignores taps', (WidgetTester tester) async {
      final done = <String>[];
      await pumpThemed(tester, PinPad(onCompleted: done.add, enabled: false));
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const ValueKey('pin_key_1')));
      }
      await tester.pump();
      expect(done, isEmpty);
    });

    testWidgets('backspace on empty pad is a no-op; completes once', (
      WidgetTester tester,
    ) async {
      final done = <String>[];
      await pumpThemed(tester, PinPad(onCompleted: done.add));
      await tester.tap(find.byKey(const ValueKey('pin_backspace')));
      for (final k in <String>['1', '2', '3', '4', '5']) {
        await tester.tap(find.byKey(ValueKey('pin_key_$k')));
        await tester.pump();
      }
      expect(done, <String>['1234']);
    });
  });

  group('AppFailure mapping', () {
    test('Firebase codes map to friendly failures, no raw message leaks', () {
      FirebaseException fe(String code) => FirebaseException(
        plugin: 'cloud_firestore',
        code: code,
        message: 'RAW internal detail',
      );
      expect(
        mapFirebaseException(fe('unavailable')),
        isA<OfflineRequiredFailure>(),
      );
      expect(
        mapFirebaseException(fe('permission-denied')),
        isA<PermissionDeniedFailure>(),
      );
      expect(mapFirebaseException(fe('not-found')), isA<NotFoundFailure>());
      final v = mapFirebaseException(fe('invalid-argument'));
      expect(v, isA<ValidationFailure>());
      expect(v.userMessage, isNot(contains('RAW')));
      final u = mapFirebaseException(fe('weird-code'));
      expect(u, isA<UnknownFailure>());
      expect(u.userMessage, isNot(contains('RAW')));
      expect(mapFirebaseException(StateError('x')), isA<UnknownFailure>());
      const passthrough = AppFailure.offlineRequired();
      expect(identical(mapFirebaseException(passthrough), passthrough), isTrue);
    });
  });
}
