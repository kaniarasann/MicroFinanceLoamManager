import 'dart:async';
import 'dart:developer' as developer;

import '../errors/app_failure.dart';

/// What happened to a write once the call returned.
enum WriteOutcome {
  /// The server acknowledged it.
  synced,

  /// Applied to the local cache and queued; it syncs when back online.
  queued,
}

/// Waits up to [grace] for [write]'s server ack. A write that is still
/// pending by then is already in the local cache and queued, so it counts
/// as [WriteOutcome.queued]. Firebase errors are mapped to [AppFailure].
Future<WriteOutcome> awaitServerAck(
  Future<void> write,
  Duration grace,
  String what,
) async {
  try {
    await write.timeout(grace);
    return WriteOutcome.synced;
  } on TimeoutException {
    developer.log('$what queued (no server ack yet)', name: 'ledger.writes');
    return WriteOutcome.queued;
  } on Object catch (e, st) {
    throw mapFirebaseException(e, st);
  }
}
