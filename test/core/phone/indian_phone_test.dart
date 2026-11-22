import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/phone/indian_phone.dart';

void main() {
  group('IndianPhone.toE164', () {
    test('accepts common input forms', () {
      for (final input in <String>[
        '9845012890',
        '98450 12890',
        '+91 98450 12890',
        '+919845012890',
        '919845012890',
        '09845012890',
        '98450-12890',
      ]) {
        expect(IndianPhone.toE164(input), '+919845012890', reason: input);
      }
    });

    test('rejects bad numbers', () {
      for (final input in <String>[
        '',
        '12345',
        '984501289',
        '98450128901',
        '5845012890', // must start 6-9
        '+1 415 555 0100',
        'abcdefghij',
      ]) {
        expect(IndianPhone.toE164(input), isNull, reason: input);
      }
    });
  });

  test('format renders +91 98450 12890', () {
    expect(IndianPhone.format('+919845012890'), '+91 98450 12890');
    expect(IndianPhone.format('not a phone'), 'not a phone');
    expect(IndianPhone.nationalDisplay('+919845012890'), '98450 12890');
    expect(IndianPhone.nationalDisplay(null), '');
  });

  test('isValidE164', () {
    expect(IndianPhone.isValidE164('+919845012890'), isTrue);
    expect(IndianPhone.isValidE164('9845012890'), isFalse);
    expect(IndianPhone.isValidE164('+91984501289'), isFalse);
  });

  group('IndianMobileInputFormatter', () {
    const f = IndianMobileInputFormatter();
    String fmt(String text) => f
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text))
        .text;

    test('groups 5+5 and caps at 10 digits', () {
      expect(fmt('98450'), '98450');
      expect(fmt('984501'), '98450 1');
      expect(fmt('9845012890'), '98450 12890');
      expect(fmt('984501289012'), '98450 12890');
    });

    test('strips non-digits and a pasted +91', () {
      expect(fmt('+91 98450 12890'), '98450 12890');
      expect(fmt('98a45-0'), '98450');
    });
  });
}
