import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../../core/config/app_config.dart';
import 'secure_key_value_store.dart';

/// Outcome of [MpinStore.verify].
final class MpinVerifyResult {
  const MpinVerifyResult({
    required this.ok,
    required this.remaining,
    required this.lockedOut,
  });

  final bool ok;

  /// Attempts left before lockout (after this attempt).
  final int remaining;

  /// True when this attempt hit the limit; the MPIN has been wiped.
  final bool lockedOut;

  @override
  String toString() =>
      'MpinVerifyResult(ok: $ok, remaining: $remaining, lockedOut: $lockedOut)';
}

/// Device-local MPIN, biometric flag and auto-lock delay, keyed per uid.
///
/// Stores only `sha256(salt + pin + uid)` (hex) and a random 16-byte salt.
/// The PIN itself is never persisted and never leaves the device.
final class MpinStore {
  MpinStore(this._store, {Random? random})
    : _random = random ?? Random.secure();

  final SecureKeyValueStore _store;
  final Random _random;

  static const int maxAttempts = AppConfig.maxMpinAttempts;
  static const int saltBytes = 16;
  static final RegExp _pinPattern = RegExp(r'^\d{4}$');

  static String _key(String uid, String field) => 'nl.mpin.$uid.$field';
  static String hashKey(String uid) => _key(uid, 'hash');
  static String saltKey(String uid) => _key(uid, 'salt');
  static String failuresKey(String uid) => _key(uid, 'failures');
  static String biometricKey(String uid) => _key(uid, 'biometric');
  static String autoLockKey(String uid) => _key(uid, 'autolock');

  /// `sha256(salt + pin + uid)` as lowercase hex.
  static String hashPin({
    required String saltHex,
    required String pin,
    required String uid,
  }) => sha256.convert(utf8.encode('$saltHex$pin$uid')).toString();

  Future<bool> hasMpin(String uid) async {
    final hash = await _store.read(hashKey(uid));
    final salt = await _store.read(saltKey(uid));
    return hash != null && hash.isNotEmpty && salt != null && salt.isNotEmpty;
  }

  /// Sets (or replaces) the MPIN with a fresh salt and resets the counter.
  Future<void> setMpin(String uid, String pin) async {
    if (!_pinPattern.hasMatch(pin)) {
      throw ArgumentError.value('****', 'pin', 'must be 4 digits');
    }
    final salt = _newSaltHex();
    await _store.write(saltKey(uid), salt);
    await _store.write(
      hashKey(uid),
      hashPin(saltHex: salt, pin: pin, uid: uid),
    );
    await _store.delete(failuresKey(uid));
  }

  /// Checks [pin]. A wrong PIN increments the counter; the
  /// [maxAttempts]-th consecutive failure wipes the MPIN ([clear]).
  Future<MpinVerifyResult> verify(String uid, String pin) async {
    final hash = await _store.read(hashKey(uid));
    final salt = await _store.read(saltKey(uid));
    if (hash == null || salt == null) {
      return const MpinVerifyResult(ok: false, remaining: 0, lockedOut: true);
    }
    final candidate = hashPin(saltHex: salt, pin: pin, uid: uid);
    if (_constantTimeEquals(candidate, hash)) {
      await _store.delete(failuresKey(uid));
      return const MpinVerifyResult(
        ok: true,
        remaining: maxAttempts,
        lockedOut: false,
      );
    }
    final failures = await failedAttempts(uid) + 1;
    if (failures >= maxAttempts) {
      await clear(uid);
      return const MpinVerifyResult(ok: false, remaining: 0, lockedOut: true);
    }
    await _store.write(failuresKey(uid), '$failures');
    return MpinVerifyResult(
      ok: false,
      remaining: maxAttempts - failures,
      lockedOut: false,
    );
  }

  Future<int> failedAttempts(String uid) async =>
      int.tryParse(await _store.read(failuresKey(uid)) ?? '') ?? 0;

  /// Resets the failed-attempt counter (e.g. after a biometric unlock).
  Future<void> resetFailures(String uid) => _store.delete(failuresKey(uid));

  /// Wipes the MPIN, salt, counter and biometric opt-in for [uid].
  /// The auto-lock preference is kept.
  Future<void> clear(String uid) async {
    await _store.delete(hashKey(uid));
    await _store.delete(saltKey(uid));
    await _store.delete(failuresKey(uid));
    await _store.delete(biometricKey(uid));
  }

  Future<bool> biometricEnabled(String uid) async =>
      await _store.read(biometricKey(uid)) == 'true';

  Future<void> setBiometricEnabled(String uid, {required bool enabled}) =>
      _store.write(biometricKey(uid), '$enabled');

  Future<int> autoLockMinutes(String uid) async {
    final raw = int.tryParse(await _store.read(autoLockKey(uid)) ?? '');
    return raw == null || raw < 0 ? AppConfig.defaultAutoLockMinutes : raw;
  }

  Future<void> setAutoLockMinutes(String uid, int minutes) {
    if (minutes < 0) {
      throw ArgumentError.value(minutes, 'minutes', 'must be >= 0');
    }
    return _store.write(autoLockKey(uid), '$minutes');
  }

  String _newSaltHex() {
    final buffer = StringBuffer();
    for (var i = 0; i < saltBytes; i++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
