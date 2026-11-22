import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/features/auth/data/mpin_store.dart';
import 'package:nordic_ledger/features/auth/data/secure_key_value_store.dart';

void main() {
  late InMemorySecureKeyValueStore storage;
  late MpinStore store;
  const uid = 'uid-tester';

  setUp(() {
    storage = InMemorySecureKeyValueStore();
    store = MpinStore(storage);
  });

  test('MPIN is never stored in plain text in any key', () async {
    await store.setMpin(uid, '4821');
    await store.verify(uid, '0000'); // writes failure counter too
    final unsalted = sha256.convert(utf8.encode('4821')).toString();
    for (final entry in storage.values.entries) {
      // Exact match: random hex hash/salt may contain '4821' by chance.
      expect(entry.value, isNot('4821'), reason: entry.key);
      expect(entry.value, isNot(unsalted), reason: entry.key);
      expect(entry.key.contains('4821'), isFalse);
    }
    final hash = storage.values[MpinStore.hashKey(uid)]!;
    expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(storage.values[MpinStore.saltKey(uid)], hasLength(32));
  });

  test('same PIN for two uids gives different hashes (salt + uid)', () async {
    await store.setMpin('u1', '1234');
    await store.setMpin('u2', '1234');
    expect(
      storage.values[MpinStore.hashKey('u1')],
      isNot(storage.values[MpinStore.hashKey('u2')]),
    );
  });

  test('resetting the same PIN rotates the salt and hash', () async {
    await store.setMpin(uid, '1234');
    final h1 = storage.values[MpinStore.hashKey(uid)];
    await store.setMpin(uid, '1234');
    expect(storage.values[MpinStore.hashKey(uid)], isNot(h1));
  });

  test('6th attempt after lockout fails even with the right PIN', () async {
    await store.setMpin(uid, '2468');
    for (var i = 1; i <= 4; i++) {
      final r = await store.verify(uid, '0000');
      expect(r.remaining, 5 - i);
      expect(r.lockedOut, isFalse);
    }
    final fifth = await store.verify(uid, '0000');
    expect(fifth.lockedOut, isTrue);
    expect(await store.hasMpin(uid), isFalse);

    final sixth = await store.verify(uid, '2468');
    expect(sixth.ok, isFalse);
    expect(sixth.lockedOut, isTrue);
  });

  test('lockout of one uid does not affect another uid', () async {
    await store.setMpin('u1', '1111');
    await store.setMpin('u2', '2222');
    for (var i = 0; i < 5; i++) {
      await store.verify('u1', '0000');
    }
    expect(await store.hasMpin('u1'), isFalse);
    expect((await store.verify('u2', '2222')).ok, isTrue);
  });

  test('correct PIN resets the failure counter', () async {
    await store.setMpin(uid, '2468');
    await store.verify(uid, '0000');
    await store.verify(uid, '0000');
    expect((await store.verify(uid, '2468')).ok, isTrue);
    expect(await store.failedAttempts(uid), 0);
  });

  test('invalid PIN formats are rejected at setup', () async {
    for (final bad in <String>['123', '12345', 'abcd', '12 4', '']) {
      expect(() => store.setMpin(uid, bad), throwsArgumentError, reason: bad);
    }
    expect(await store.hasMpin(uid), isFalse);
  });
}
