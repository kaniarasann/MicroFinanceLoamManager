import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/validation/onboarding_validators.dart';
import '../../auth/data/secure_key_value_store.dart';

/// Reads an invite `code=` from the Google Play install referrer, once per
/// install. Every failure (not Android, not installed from Play, the Play
/// service unavailable) is ignored and yields null.
class InstallReferrerSource {
  InstallReferrerSource(this._store, {Future<String?> Function()? read})
    : _read = read ?? _readPlayReferrer;

  static const String checkedKey = 'install_referrer_checked';

  final SecureKeyValueStore _store;
  final Future<String?> Function() _read;

  static Future<String?> _readPlayReferrer() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    final details = await AndroidPlayInstallReferrer.installReferrer;
    return details.installReferrer;
  }

  /// The invite code from the referrer on the first call after install;
  /// null on every later call or on any failure.
  Future<String?> readInviteCodeOnce() async {
    try {
      if (await _store.read(checkedKey) == '1') return null;
      await _store.write(checkedKey, '1');
      return InviteCode.fromReferrer(await _read());
    } on Object catch (e) {
      developer.log('Install referrer ignored', name: 'onboarding', error: e);
      return null;
    }
  }
}
