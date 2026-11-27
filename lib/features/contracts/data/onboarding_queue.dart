import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/money/money.dart';
import '../../../core/time/civil_date.dart';
import '../../../domain/models/enums.dart';

/// Lifecycle of an onboarding sync list.
enum OnboardingQueueStatus {
  /// Some queued payments may not be on the server yet.
  pending,

  /// Every queued payment landed.
  complete,

  /// The onboarded loan was cancelled; nothing more is written.
  cancelled,
}

/// One payment the onboarding writes after batch 1. Stored with compact
/// keys (`i`, `d`, `a`, `m`, `r`, `o`) so 1,100 entries stay far below the
/// 1 MiB document limit (about 100 bytes each).
final class QueuedPayment {
  const QueuedPayment({
    required this.id,
    required this.paidOn,
    required this.amount,
    required this.mode,
    this.reference,
    this.openingBalance = false,
  });

  factory QueuedPayment.fromMap(Map<String, Object?> m) => QueuedPayment(
    id: m['i']! as String,
    paidOn: CivilDate.parse(m['d']! as String),
    amount: Money(m['a']! as int),
    mode: PaymentMode.values.byName(m['m']! as String),
    reference: m['r'] as String?,
    openingBalance: (m['o'] as bool?) ?? false,
  );

  /// The pre-generated transaction id (client uuid v4).
  final String id;
  final CivilDate paidOn;
  final Money amount;
  final PaymentMode mode;
  final String? reference;
  final bool openingBalance;

  Map<String, Object?> toMap() => <String, Object?>{
    'i': id,
    'd': paidOn.toString(),
    'a': amount.paise,
    'm': mode.name,
    if (reference != null) 'r': reference,
    'o': openingBalance,
  };
}

/// `companies/{cid}/onboardingQueues/{contractId}`: the durable sync list
/// of an onboarding. Batch 1 writes it next to the contract, so the plan
/// for every later payment survives going offline or an app kill. The
/// resumer writes those payments only once batch 1 is on the server.
/// Entries are immutable; only [status] and `updatedAt` change.
final class OnboardingQueue {
  const OnboardingQueue({
    required this.contractId,
    required this.status,
    required this.entries,
    required this.createdBy,
  });

  factory OnboardingQueue.fromFirestore(Map<String, Object?> m) =>
      OnboardingQueue(
        contractId: m['contractId']! as String,
        status: OnboardingQueueStatus.values.firstWhere(
          (OnboardingQueueStatus s) => s.name == m['status'],
          orElse: () => OnboardingQueueStatus.pending,
        ),
        entries: <QueuedPayment>[
          for (final e in (m['entries'] as List<Object?>?) ?? <Object?>[])
            QueuedPayment.fromMap((e! as Map<Object?, Object?>).cast()),
        ],
        createdBy: (m['createdBy'] as String?) ?? '',
      );

  final String contractId;
  final OnboardingQueueStatus status;
  final List<QueuedPayment> entries;
  final String createdBy;

  bool get isPending => status == OnboardingQueueStatus.pending;

  Money get total => Money.sum(entries.map((QueuedPayment e) => e.amount));

  /// The create payload (batch 1). Server timestamps for both audit times.
  Map<String, Object?> toFirestore() => <String, Object?>{
    'contractId': contractId,
    'status': status.name,
    'entries': <Map<String, Object?>>[for (final e in entries) e.toMap()],
    'count': entries.length,
    'totalPaise': total.paise,
    'createdBy': createdBy,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'schemaVersion': 1,
  };
}

/// One emission of the pending sync lists: their contract ids and whether
/// the snapshot still has local writes not yet on the server.
final class PendingQueues {
  const PendingQueues(this.ids, {required this.hasPendingWrites});

  final Set<String> ids;
  final bool hasPendingWrites;
}

/// Whether [next] should trigger the resumer after [prev] (F5): the first
/// emission, a changed id set, or local writes that just reached the
/// server (`hasPendingWrites` true → false). Other metadata flips are
/// ignored.
bool resumeTriggerChanged(PendingQueues? prev, PendingQueues next) {
  if (prev == null) return true;
  if (prev.hasPendingWrites && !next.hasPendingWrites) return true;
  return prev.ids.length != next.ids.length || !prev.ids.containsAll(next.ids);
}

/// [source] filtered by [resumeTriggerChanged], as id lists.
Stream<List<String>> resumeTriggers(Stream<PendingQueues> source) async* {
  PendingQueues? prev;
  await for (final next in source) {
    if (resumeTriggerChanged(prev, next)) yield next.ids.toList();
    prev = next;
  }
}
