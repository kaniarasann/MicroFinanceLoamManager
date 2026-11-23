import '../phone/indian_phone.dart';

/// Pure validators for the borrower form. Each returns a user-facing
/// message, or null when the value is valid.
abstract final class BorrowerValidators {
  static const int nameMin = 2;
  static const int nameMax = 80;
  static const int localityMax = 80;
  static const int notesMax = 500;

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return "Enter the borrower's name.";
    if (v.length < nameMin) {
      return 'Name must be at least $nameMin characters.';
    }
    if (v.length > nameMax) return 'Name must be at most $nameMax characters.';
    return null;
  }

  /// Message for a mobile number already saved for [existingName].
  static String duplicatePhone(String existingName) =>
      'This mobile is already saved for $existingName.';

  /// The borrower (if any) in [phonesById] other than [selfId] that uses
  /// the same number as [input]. [phonesById] maps id → E.164.
  static String? duplicateOf(
    String input,
    Map<String, String> phonesById, {
    String? selfId,
  }) {
    final e164 = IndianPhone.toE164(input);
    if (e164 == null) return null;
    for (final entry in phonesById.entries) {
      if (entry.key != selfId && entry.value == e164) return entry.key;
    }
    return null;
  }
}
