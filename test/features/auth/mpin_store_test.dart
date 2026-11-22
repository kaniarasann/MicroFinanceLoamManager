import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/features/auth/data/mpin_store.dart';
import 'package:nordic_ledger/features/auth/data/secure_key_value_store.dart';

void main() {
  late InMemorySecureKeyValueStore storage;
  late MpinStore store;
  const uid = 'uid-1';

  setUp(() {
    storage = InMemorySecureKeyValueStore();
    store = MpinStore(storage, random: Random(7));
  });

  group('hash and salt', () {
    test(
      'stores sha256(salt + pin + uid) hex and a 16-byte hex salt',
      () async {
        await store.setMpin(uid, '2580');
        final salt = storage.values[MpinStore.saltKey(uid)]!;
        final hash = storage.values[MpinStore.hashKey(uid)]!;
        expect(salt, matches(RegExp(r'^[0-9a-f]{32}$')));
        expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(hash, sha256.convert(utf8.encode('${salt}2580$uid')).toString());
      },
    );

    test('never stores the PIN in plain text', () async {
      await store.setMpin(uid, '2580');
      await store.verify(uid, '1111');
      for (final entry in storage.values.entries) {
        expect(entry.key, isNot(contains('2580')));
        expect(entry.value, isNot(contains('2580')));
      }
    });

    test('a new salt on every set, so equal PINs hash differently', () async {
      await store.setMpin(uid, '2580');
      final first = storage.values[MpinStore.hashKey(uid)];
      final firstSalt = storage.values[MpinStore.saltKey(uid)];
      await store.setMpin(uid, '2580');
      expect(storage.values[MpinStore.saltKey(uid)], isNot(firstSalt));
      expect(storage.values[MpinStore.hashKey(uid)], isNot(first));
      expect((await store.verify(uid, '2580')).ok, isTrue);
    });

    test('rejects PINs that are not 4 digits', () async {
      for (final bad in <String>['', '123', '12345', '12a4']) {
        expect(() => store.setMpin(uid, bad), throwsArgumentError);
      }
      expect(await store.hasMpin(uid), isFalse);
    });
  });

  group('verify', () {
    test('hasMpin reflects set / clear', () async {
      expect(await store.hasMpin(uid), isFalse);
      await store.setMpin(uid, '1234');
      expect(await store.hasMpin(uid), isTrue);
      await store.clear(uid);
      expect(await store.hasMpin(uid), isFalse);
    });

    test('correct PIN is ok and resets the counter', () async {
      await store.setMpin(uid, '1234');
      await store.verify(uid, '0000');
      await store.verify(uid, '0000');
      expect(await store.failedAttempts(uid), 2);
      final r = await store.verify(uid, '1234');
      expect(r.ok, isTrue);
      expect(r.lockedOut, isFalse);
      expect(await store.failedAttempts(uid), 0);
    });

    test('wrong PIN counts down remaining tries', () async {
      await store.setMpin(uid, '1234');
      final remaining = <int>[];
      for (var i = 0; i < 4; i++) {
        final r = await store.verify(uid, '9999');
        expect(r.ok, isFalse);
        expect(r.lockedOut, isFalse);
        remaining.add(r.remaining);
      }
      expect(remaining, <int>[4, 3, 2, 1]);
      expect(await store.failedAttempts(uid), 4);
    });

    test('5th consecutive failure locks out and wipes the MPIN', () async {
      await store.setMpin(uid, '1234');
      await store.setBiometricEnabled(uid, enabled: true);
      await store.setAutoLockMinutes(uid, 5);
      for (var i = 0; i < 4; i++) {
        await store.verify(uid, '9999');
      }
      final r = await store.verify(uid, '9999');
      expect(r.ok, isFalse);
      expect(r.lockedOut, isTrue);
      expect(r.remaining, 0);
      expect(await store.hasMpin(uid), isFalse);
      expect(await store.failedAttempts(uid), 0);
      expect(await store.biometricEnabled(uid), isFalse);
      // The auto-lock preference survives.
      expect(await store.autoLockMinutes(uid), 5);
      // Even the right PIN no longer works.
      expect((await store.verify(uid, '1234')).ok, isFalse);
    });

    test('verify without an MPIN reports locked out', () async {
      final r = await store.verify(uid, '1234');
      expect(r.ok, isFalse);
      expect(r.lockedOut, isTrue);
    });

    test('setMpin resets the failure counter', () async {
      await store.setMpin(uid, '1234');
      await store.verify(uid, '0000');
      await store.setMpin(uid, '4321');
      expect(await store.failedAttempts(uid), 0);
    });
  });

  group('per-uid isolation', () {
    test('MPINs, counters and flags are separate per uid', () async {
      await store.setMpin('a', '1111');
      await store.setMpin('b', '2222');
      await store.setBiometricEnabled('a', enabled: true);

      expect((await store.verify('a', '2222')).ok, isFalse);
      expect((await store.verify('b', '2222')).ok, isTrue);
      expect(await store.failedAttempts('a'), 1);
      expect(await store.failedAttempts('b'), 0);
      expect(await store.biometricEnabled('a'), isTrue);
      expect(await store.biometricEnabled('b'), isFalse);

      await store.clear('a');
      expect(await store.hasMpin('a'), isFalse);
      expect(await store.hasMpin('b'), isTrue);
    });

    test('the same PIN for two uids gives different hashes', () async {
      await store.setMpin('a', '1111');
      await store.setMpin('b', '1111');
      expect(
        storage.values[MpinStore.hashKey('a')],
        isNot(storage.values[MpinStore.hashKey('b')]),
      );
    });
  });

  group('preferences', () {
    test('biometric defaults off, autoLock defaults to 1 minute', () async {
      expect(await store.biometricEnabled(uid), isFalse);
      expect(await store.autoLockMinutes(uid), 1);
      await store.setBiometricEnabled(uid, enabled: true);
      await store.setAutoLockMinutes(uid, 10);
      expect(await store.biometricEnabled(uid), isTrue);
      expect(await store.autoLockMinutes(uid), 10);
    });

    test('negative auto-lock is rejected; garbage falls back to 1', () async {
      expect(() => store.setAutoLockMinutes(uid, -1), throwsArgumentError);
      storage.values[MpinStore.autoLockKey(uid)] = 'abc';
      expect(await store.autoLockMinutes(uid), 1);
    });

    test('resetFailures clears the counter', () async {
      await store.setMpin(uid, '1234');
      await store.verify(uid, '0000');
      await store.resetFailures(uid);
      expect(await store.failedAttempts(uid), 0);
    });
  });
}
