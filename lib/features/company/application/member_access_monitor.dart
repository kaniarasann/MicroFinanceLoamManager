import 'dart:async';
import 'dart:developer' as developer;

import '../../../domain/models/models.dart';
import '../../onboarding/data/company_repository.dart';

/// Delay before re-attach attempt number [attempt] (0-based).
typedef RetryBackoff = Duration Function(int attempt);

/// 1 s, 2 s, 4 s, 8 s, 16 s, then 30 s for every later attempt.
Duration defaultMemberRetryBackoff(int attempt) {
  if (attempt >= 5) return const Duration(seconds: 30);
  return Duration(seconds: 1 << attempt);
}

/// One emission of the caller's member doc in company [cid].
final class MemberWatch {
  const MemberWatch(this.cid, this.member, {this.removed = false});

  /// Confirmed removal (see [watchMemberAccess]).
  const MemberWatch.removed(this.cid) : member = null, removed = true;

  final String cid;

  /// The member doc, or null while unknown (not loaded, pending register,
  /// re-attaching) or after a confirmed removal.
  final Member? member;

  /// True only for a confirmed removal. Never true for "unknown".
  final bool removed;
}

/// Watches the caller's member doc in [cid] and decides, conservatively,
/// whether they were removed.
///
/// The caller is treated as removed ONLY when, in this app session, the
/// server had already confirmed the member doc exists ([confirmed] holds
/// [cid]: a snapshot with `isFromCache == false`, no pending writes and
/// `exists == true`) AND a later server-confirmed snapshot says the doc is
/// gone or the listener fails with permission-denied.
///
/// Before that confirmation, permission-denied (e.g. the register batch is
/// not applied on the server yet) or any other listener error re-attaches
/// the listener after [backoff]; a "does not exist" snapshot (cache or
/// server) is ignored. The stream never emits removal for those cases, so
/// the app keeps running on cached data.
///
/// [confirmed] is the session-wide set of server-confirmed company ids; it
/// is shared between listeners so a confirmation survives re-attaches and
/// company switches.
Stream<MemberWatch> watchMemberAccess({
  required String cid,
  required Stream<MemberDocEvent> Function() attach,
  required Set<String> confirmed,
  RetryBackoff backoff = defaultMemberRetryBackoff,
}) {
  late final StreamController<MemberWatch> out;
  StreamSubscription<MemberDocEvent>? sub;
  Timer? retry;
  var attempt = 0;
  var generation = 0;
  var finished = false;

  void stop() {
    finished = true;
    retry?.cancel();
    retry = null;
    final s = sub;
    sub = null;
    unawaited(s?.cancel());
  }

  void confirmRemoval() {
    if (finished) return;
    out.add(MemberWatch.removed(cid));
    stop();
  }

  late void Function() listen;

  void scheduleRetry(int gen) {
    if (finished || gen != generation || retry != null) return;
    final s = sub;
    sub = null;
    unawaited(s?.cancel());
    final delay = backoff(attempt++);
    developer.log(
      'Member listener for $cid re-attaching in ${delay.inSeconds}s',
      name: 'company',
    );
    retry = Timer(delay, () {
      retry = null;
      listen();
    });
  }

  void onEvent(int gen, MemberDocEvent e) {
    if (finished || gen != generation) return;
    switch (e) {
      case MemberDocSnapshot(member: final Member m, :final serverConfirmed):
        if (serverConfirmed) {
          confirmed.add(cid);
          attempt = 0;
        }
        out.add(MemberWatch(cid, m));
      case MemberDocSnapshot(member: null, serverConfirmed: true):
        if (confirmed.contains(cid)) confirmRemoval();
      // Not yet confirmed: the server may not have applied our write yet.
      case MemberDocSnapshot(member: null, serverConfirmed: false):
        break; // cache-only "missing" is never evidence
      case MemberDocDenied():
        if (confirmed.contains(cid)) {
          confirmRemoval();
        } else {
          scheduleRetry(gen);
        }
    }
  }

  listen = () {
    if (finished) return;
    final gen = ++generation;
    sub = attach().listen(
      (MemberDocEvent e) => onEvent(gen, e),
      onError: (Object e, StackTrace st) {
        developer.log('Member listener error', name: 'company', error: e);
        scheduleRetry(gen);
      },
      // The SDK closes a listener after an error; re-attach unless we are
      // done or already re-attaching.
      onDone: () => scheduleRetry(gen),
      cancelOnError: false,
    );
  };

  out = StreamController<MemberWatch>(onListen: () => listen(), onCancel: stop);
  return out.stream;
}
