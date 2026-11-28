import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Inputs of the Settings sync-status card. A seam so widget tests can drive
/// it without platform channels.
abstract interface class SyncSignals {
  /// Whether the device has a network connection (emits the current value
  /// first).
  Stream<bool> online();

  /// Fires whenever every active Firestore listener is in sync (after a
  /// local write or a server change).
  Stream<void> inSync();

  /// Completes once every local write has reached the server.
  Future<void> waitForPendingWrites();
}

/// [SyncSignals] over connectivity_plus and Firestore.
final class FirestoreSyncSignals implements SyncSignals {
  FirestoreSyncSignals(this._db, [Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final FirebaseFirestore _db;
  final Connectivity _connectivity;

  static bool _isOnline(List<ConnectivityResult> r) =>
      r.any((ConnectivityResult c) => c != ConnectivityResult.none);

  @override
  Stream<bool> online() async* {
    try {
      yield _isOnline(await _connectivity.checkConnectivity());
    } on Object {
      yield true; // unknown: assume online, the pending state still shows
    }
    yield* _connectivity.onConnectivityChanged.map(_isOnline);
  }

  @override
  Stream<void> inSync() => _db.snapshotsInSync();

  @override
  Future<void> waitForPendingWrites() => _db.waitForPendingWrites();
}

/// Fixed [SyncSignals] for tests and previews.
final class FakeSyncSignals implements SyncSignals {
  FakeSyncSignals({this.isOnline = true, this.pending = false});

  bool isOnline;
  bool pending;
  final StreamController<bool> _online = StreamController<bool>.broadcast();
  final StreamController<void> _sync = StreamController<void>.broadcast();
  Completer<void>? _writes;

  @override
  Stream<bool> online() async* {
    yield isOnline;
    yield* _online.stream;
  }

  void setOnline({required bool value}) {
    isOnline = value;
    _online.add(value);
  }

  @override
  Stream<void> inSync() => _sync.stream;

  /// Marks writes as pending (until [flush]).
  void addPending() {
    pending = true;
    _sync.add(null);
  }

  /// Delivers every pending write.
  void flush() {
    pending = false;
    _writes?.complete();
    _writes = null;
    _sync.add(null);
  }

  @override
  Future<void> waitForPendingWrites() {
    if (!pending) return Future<void>.value();
    return (_writes ??= Completer<void>()).future;
  }
}
