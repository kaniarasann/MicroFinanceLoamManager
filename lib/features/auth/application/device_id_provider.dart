import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import 'auth_providers.dart';

part 'device_id_provider.g.dart';

/// Secure-storage key of this installation's id.
const String deviceIdKey = 'device_id';

/// A random per-installation id (uuid v4), created on first use and kept in
/// secure storage. Stamped as `deviceId` on every ledger transaction so an
/// owner can tell which phone recorded an entry.
@Riverpod(keepAlive: true)
Future<String> deviceId(Ref ref) async {
  final store = ref.watch(secureKeyValueStoreProvider);
  final existing = await store.read(deviceIdKey);
  if (existing != null && existing.isNotEmpty) return existing;
  final id = const Uuid().v4();
  await store.write(deviceIdKey, id);
  return id;
}
