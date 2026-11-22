import 'package:flutter/services.dart';

/// Indian mobile numbers: stored as E.164 (`+919845012890`), displayed as
/// `+91 98450 12890`.
abstract final class IndianPhone {
  static const String countryCode = '+91';

  static final RegExp _e164 = RegExp(r'^\+91[6-9]\d{9}$');

  /// Copy for an invalid number.
  static const String invalidMessage =
      'Enter a 10-digit Indian mobile number (starts with 6–9).';

  /// Normalises user input (spaces, dashes, a leading `+91`, `91` or `0`)
  /// to E.164. Returns null when it is not a valid Indian mobile number.
  static String? toE164(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length != 10) return null;
    final e164 = '$countryCode$digits';
    return _e164.hasMatch(e164) ? e164 : null;
  }

  static bool isValidE164(String value) => _e164.hasMatch(value);

  /// `+919845012890` → `+91 98450 12890`. Anything that is not a valid
  /// Indian E.164 number is returned unchanged.
  static String format(String e164) {
    if (!isValidE164(e164)) return e164;
    final n = e164.substring(3);
    return '$countryCode ${n.substring(0, 5)} ${n.substring(5)}';
  }

  /// The 10 national digits grouped `98450 12890` (for a field with a
  /// `+91` prefix). Returns '' for an invalid number.
  static String nationalDisplay(String? e164) {
    if (e164 == null || !isValidE164(e164)) return '';
    final n = e164.substring(3);
    return '${n.substring(0, 5)} ${n.substring(5)}';
  }
}

/// Input formatter for the national part of a +91 mobile: digits only, max
/// 10, grouped as `98450 12890`.
class IndianMobileInputFormatter extends TextInputFormatter {
  const IndianMobileInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    // A pasted "+91 98450 12890" / "919845012890".
    if (digits.length > 10 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    if (digits.length > 10) digits = digits.substring(0, 10);
    final text = digits.length > 5
        ? '${digits.substring(0, 5)} ${digits.substring(5)}'
        : digits;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
