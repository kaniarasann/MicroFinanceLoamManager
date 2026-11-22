/// Pure validators for the onboarding forms and invite codes. Each returns
/// a user-facing message, or null when the value is valid.
abstract final class OnboardingValidators {
  static const int companyNameMin = 2;
  static const int companyNameMax = 80;
  static const int displayNameMax = 60;

  static String? companyName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your company name.';
    if (v.length < companyNameMin) {
      return 'Company name must be at least $companyNameMin characters.';
    }
    if (v.length > companyNameMax) {
      return 'Company name must be at most $companyNameMax characters.';
    }
    return null;
  }

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your name.';
    if (v.length > displayNameMax) {
      return 'Name must be at most $displayNameMax characters.';
    }
    return null;
  }

  /// The staff member's name on an invite.
  static String? inviteeName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return "Enter the staff member's name.";
    if (v.length > displayNameMax) {
      return 'Name must be at most $displayNameMax characters.';
    }
    return null;
  }
}

/// 6-character invite codes from an unambiguous alphabet (no 0/O, 1/I/L).
abstract final class InviteCode {
  static const String alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  static const int length = 6;

  static final RegExp _valid = RegExp('^[$alphabet]{$length}\$');

  /// Uppercases and keeps only alphabet characters, capped at [length].
  static String sanitize(String input) {
    final upper = input.toUpperCase();
    final buffer = StringBuffer();
    for (final ch in upper.split('')) {
      if (alphabet.contains(ch)) buffer.write(ch);
      if (buffer.length == length) break;
    }
    return buffer.toString();
  }

  static bool isValid(String code) => _valid.hasMatch(code);

  /// Extracts a `code=` parameter from a referrer / query string such as
  /// `utm_source=invite&code=K7Q2MD`. Returns null if absent or invalid.
  static String? fromReferrer(String? referrer) {
    if (referrer == null || referrer.isEmpty) return null;
    Map<String, String> params;
    try {
      params = Uri.splitQueryString(Uri.decodeComponent(referrer));
    } on Object {
      return null;
    }
    final raw = params['code'];
    if (raw == null) return null;
    final code = raw.trim().toUpperCase();
    return isValid(code) ? code : null;
  }
}
