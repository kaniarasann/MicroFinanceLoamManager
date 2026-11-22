import 'money.dart';

/// Rupee sign. No space ever follows it.
const String rupeeSign = '₹';

/// U+2212 MINUS SIGN, used for negative amounts (not a hyphen).
const String minusSign = '−';

/// Groups a non-negative integer the Indian way: 12,34,567.
String groupIndianDigits(int value) {
  assert(value >= 0, 'groupIndianDigits expects a non-negative value');
  final s = value.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '${groups.join(',')},$last3';
}

/// Amount without the `₹` sign or minus: "1,00,000" or "1,234.50".
String formatInrPlain(Money money) {
  final abs = money.paise.abs();
  final rupees = abs ~/ 100;
  final paise = abs % 100;
  final grouped = groupIndianDigits(rupees);
  return paise == 0 ? grouped : '$grouped.${paise.toString().padLeft(2, '0')}';
}

/// Full INR: `₹1,00,000`, `₹1,234.50`, `−₹1,000`.
String formatInr(Money money) {
  final sign = money.isNegative ? minusSign : '';
  return '$sign$rupeeSign${formatInrPlain(money)}';
}

/// Short INR for chart axes: ₹500, ₹50k, ₹1.5L, ₹2.5Cr (one decimal max,
/// trailing `.0` dropped, half-up rounding).
String formatInrShort(Money money) {
  final sign = money.isNegative ? minusSign : '';
  // Round paise to whole rupees, half up.
  final rupees = (money.paise.abs() + 50) ~/ 100;
  return '$sign$rupeeSign${_short(rupees)}';
}

String _short(int rupees) {
  if (rupees < 1000) return rupees.toString();

  const thousand = 1000;
  const lakh = 100000;
  const crore = 10000000;

  final k = _tenths(rupees, thousand);
  if (k < 1000) return '${_oneDecimal(k)}k';
  final l = _tenths(rupees, lakh);
  if (l < 1000) return '${_oneDecimal(l)}L';
  return '${_oneDecimal(_tenths(rupees, crore), group: true)}Cr';
}

/// rupees / unit, in tenths, rounded half up.
int _tenths(int rupees, int unit) => (rupees * 10 + unit ~/ 2) ~/ unit;

String _oneDecimal(int tenths, {bool group = false}) {
  final whole = tenths ~/ 10;
  final frac = tenths % 10;
  final wholeText = group ? groupIndianDigits(whole) : whole.toString();
  return frac == 0 ? wholeText : '$wholeText.$frac';
}

final RegExp _inputPattern = RegExp(
  r'^(\d+|\d{1,2}(?:,\d{2})*,\d{3}|\d{1,3}(?:,\d{3})+)(?:\.(\d{0,2}))?$',
);

/// Maximum digits in the rupee part of typed input (≈ ₹10 lakh crore).
const int maxInputRupeeDigits = 13;

/// Parses user input such as "1,00,000", "100000", "1234.5", "₹500".
///
/// Returns `null` for empty, negative, malformed or out-of-range input, or
/// for more than two decimal places.
Money? parseInrInput(String input) {
  var text = input.trim();
  if (text.startsWith(rupeeSign)) text = text.substring(1).trim();
  if (text.isEmpty) return null;

  final match = _inputPattern.firstMatch(text);
  if (match == null) return null;

  final intDigits = match.group(1)!.replaceAll(',', '');
  final normalized = intDigits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (normalized.length > maxInputRupeeDigits) return null;

  final rupees = int.parse(normalized);
  final fraction = match.group(2) ?? '';
  final paise = fraction.isEmpty ? 0 : int.parse(fraction.padRight(2, '0'));
  return Money(rupees * 100 + paise);
}
