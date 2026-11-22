import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/bootstrap.dart';
import 'package:nordic_ledger/features/auth/data/secure_key_value_store.dart';
import 'package:nordic_ledger/features/onboarding/data/cache_reset_flag.dart';
import 'package:nordic_ledger/features/onboarding/data/install_referrer_source.dart';

void main() {
  group('clearFirestoreCacheIfScheduled', () {
    test('no flag: Firestore untouched', () async {
      final flag = CacheResetFlag(InMemorySecureKeyValueStore());
      var cleared = 0;
      await clearFirestoreCacheIfScheduled(flag, () async => cleared++);
      expect(cleared, 0);
    });

    test('flag set: clears persistence once and resets the flag', () async {
      final flag = CacheResetFlag(InMemorySecureKeyValueStore());
      await flag.schedule();
      var cleared = 0;
      await clearFirestoreCacheIfScheduled(flag, () async => cleared++);
      await clearFirestoreCacheIfScheduled(flag, () async => cleared++);
      expect(cleared, 1);
      expect(await flag.isPending(), isFalse);
    });

    test('a failing clear keeps the flag for the next start', () async {
      final flag = CacheResetFlag(InMemorySecureKeyValueStore());
      await flag.schedule();
      await clearFirestoreCacheIfScheduled(
        flag,
        () async => throw StateError('instance already started'),
      );
      expect(await flag.isPending(), isTrue);
    });
  });

  group('InstallReferrerSource', () {
    test('reads code= once per install', () async {
      final store = InMemorySecureKeyValueStore();
      var reads = 0;
      final src = InstallReferrerSource(
        store,
        read: () async {
          reads++;
          return 'utm_source=invite&code=K7Q2MD';
        },
      );
      expect(await src.readInviteCodeOnce(), 'K7Q2MD');
      expect(await src.readInviteCodeOnce(), isNull);
      expect(reads, 1);
    });

    test('failures and organic installs yield null', () async {
      final failing = InstallReferrerSource(
        InMemorySecureKeyValueStore(),
        read: () async => throw Exception('play service unavailable'),
      );
      expect(await failing.readInviteCodeOnce(), isNull);
      final organic = InstallReferrerSource(
        InMemorySecureKeyValueStore(),
        read: () async => 'utm_source=google-play&utm_medium=organic',
      );
      expect(await organic.readInviteCodeOnce(), isNull);
    });
  });
}
