/// Compile-time app configuration. Values here are public identifiers, not
/// secrets.
abstract final class AppConfig {
  /// OAuth **web** client id (client_type 3) from
  /// `android/app/google-services.json`. google_sign_in v7 needs it as the
  /// `serverClientId` so the returned ID token is accepted by Firebase Auth.
  static const String googleServerClientId =
      '38863526262-b1oat85ptpn4fllou818qn7m29vjjm6t.apps.googleusercontent.com';

  /// Consecutive wrong MPIN entries before the MPIN is wiped and Google
  /// re-auth is forced.
  static const int maxMpinAttempts = 5;

  /// Default auto-lock delay (minutes in background).
  static const int defaultAutoLockMinutes = 1;

  /// MPIN length.
  static const int mpinLength = 4;

  /// Biometric prompt reason.
  static const String biometricReason = 'Unlock Nordic Ledger';
}
