// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_id_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A random per-installation id (uuid v4), created on first use and kept in
/// secure storage. Stamped as `deviceId` on every ledger transaction so an
/// owner can tell which phone recorded an entry.

@ProviderFor(deviceId)
final deviceIdProvider = DeviceIdProvider._();

/// A random per-installation id (uuid v4), created on first use and kept in
/// secure storage. Stamped as `deviceId` on every ledger transaction so an
/// owner can tell which phone recorded an entry.

final class DeviceIdProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// A random per-installation id (uuid v4), created on first use and kept in
  /// secure storage. Stamped as `deviceId` on every ledger transaction so an
  /// owner can tell which phone recorded an entry.
  DeviceIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceIdHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return deviceId(ref);
  }
}

String _$deviceIdHash() => r'b412bd3a84e1c085da3a0e21b7b2bbf0febddf0b';
