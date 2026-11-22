import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key/value seam over device secure storage, so the MPIN store can
/// be unit-tested with an in-memory fake.
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// [SecureKeyValueStore] backed by `flutter_secure_storage`.
///
/// Android: flutter_secure_storage v10+ removed the old
/// `encryptedSharedPreferences` flag. Its default [AndroidOptions] is the
/// replacement: values are AES-GCM encrypted in SharedPreferences with the key
/// wrapped by the Android Keystore (RSA-OAEP), which is what that flag meant.
final class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage(aOptions: _android);

  static const AndroidOptions _android = AndroidOptions(
    storageNamespace: 'nordic_ledger_lock',
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// In-memory [SecureKeyValueStore] for tests and previews.
final class InMemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
