import 'dart:developer' as developer;

import 'package:local_auth/local_auth.dart';

import '../../../core/config/app_config.dart';

/// Device biometric unlock.
abstract interface class BiometricService {
  /// True when the device can do a biometric check right now (hardware
  /// present and something enrolled).
  Future<bool> canCheck();

  /// Shows the system prompt. Returns false on cancel, failure or error.
  Future<bool> authenticate({String reason = AppConfig.biometricReason});
}

/// [BiometricService] over `local_auth` 3.x.
final class LocalAuthBiometricService implements BiometricService {
  LocalAuthBiometricService([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> canCheck() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on Object catch (e) {
      developer.log('Biometric check failed', name: 'auth', error: e);
      return false;
    }
  }

  @override
  Future<bool> authenticate({String reason = AppConfig.biometricReason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      // Cancel, lockout, nothing enrolled, etc.: the MPIN pad stays usable.
      developer.log('Biometric auth: ${e.code.name}', name: 'auth');
      return false;
    } on Object catch (e) {
      developer.log('Biometric auth failed', name: 'auth', error: e);
      return false;
    }
  }
}
