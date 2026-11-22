import '../../auth/data/secure_key_value_store.dart';

/// Device-local "clear the Firestore cache on the next cold start" flag.
///
/// Set when the user loses access to a company, so that company's cached
/// documents do not linger on the device. `bootstrap()` checks it before
/// Firestore is used and calls `clearPersistence()`.
class CacheResetFlag {
  const CacheResetFlag(this._store);

  static const String key = 'firestore_clear_persistence_pending';

  final SecureKeyValueStore _store;

  Future<void> schedule() => _store.write(key, '1');

  Future<bool> isPending() async => (await _store.read(key)) == '1';

  Future<void> clear() => _store.delete(key);
}
