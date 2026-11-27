import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/ledger/onboarding.dart' show balancedChunkSizes;
import '../money/money.dart';
import 'chunked_batch.dart';

export 'chunked_batch.dart' show BatchOp, maxOpsPerBatch;

/// Most money items (onboarding payments or reversals) one balanced batch
/// may carry, whatever the op limit.
///
/// History (Sprint 7c device smoke tests): attempt 3 added this cap after
/// a batch of 215 onboarding payments was denied while one of 113 passed.
/// That diagnosis was **wrong**: with caps of 100 and then 10, every later
/// batch was still denied. The real cause is ordering. Production evaluated
/// the later batches before batch 1 (the contract) had landed, so the
/// contract update and `getAfter(contract)` failed. Waiting for batch 1's
/// ack before sending anything else synced all 328 payments. That is now
/// the sync-list design (`OnboardingPlan.firstBatch` + `resumeOnboarding`).
/// The 100 cap stays as a conservative per-batch size: it keeps each
/// resumed batch small and quick to retry. Installments and
/// `contractActive` flips still fill a batch up to [maxOpsPerBatch].
const int maxLedgerItemsPerBatch = 100;

int _min(int a, int b) => a < b ? a : b;

/// Writes the contract aggregate for one chunk: [sum] is Σ of the amounts
/// of the items in that same chunk.
typedef BalanceOp = void Function(WriteBatch batch, Money sum);

/// A ledger write too big for one batch, split so that **every batch
/// balances itself**: the Σ of the money items (payments or reversals) in
/// a batch equals the aggregate increment that batch applies to the
/// contract. Whatever subset of batches lands, `totalPaidPaise` stays equal
/// to Σ of the landed items.
///
/// - Batch 1: the [fixed] ops, the [firstBalance] op (1 op) and as many
///   items as fit in [limit], at most [maxItems].
/// - Batches 2…m: up to `min(limit − 1, maxItems)` items plus the
///   [laterBalance] op.
/// - [early] ops (non-money, but best kept atomic with batch 1, such as a
///   new contract's installments) take the room in batch 1 ahead of the
///   items. Only what does not fit (a small [limit]) overflows like spill.
/// - [spill] ops (non-money bookkeeping such as `contractActive` flips)
///   fill the room left in the last batch, then further batches.
///
/// [commit] sends the batches through [commitInOrder]: one at a time, each
/// waiting (up to a short grace) for its server ack before the next is
/// sent. If one is not acknowledged in time (offline), the rest are
/// committed right away and queue in the cache in submission order.
/// Production may evaluate queued batches out of order, so this is only
/// for writes whose batches don't depend on each other (the contract
/// already exists: opening-balance reversal). A new onboarded contract's
/// later batches never go through here; they wait for batch 1 via the
/// sync list and the resumer.
final class BalancedChunks {
  BalancedChunks(
    this._db, {
    required this.firstBalance,
    required this.laterBalance,
    this.limit = maxOpsPerBatch,
    this.maxItems = maxLedgerItemsPerBatch,
  });

  final FirebaseFirestore _db;
  final BalanceOp firstBalance;
  final BalanceOp laterBalance;
  final int limit;

  /// Most money items (payments / reversals) in one batch, separate from
  /// the op [limit]. See [maxLedgerItemsPerBatch].
  final int maxItems;

  final List<BatchOp> _fixed = <BatchOp>[];
  final List<({BatchOp op, Money amount})> _items =
      <({BatchOp op, Money amount})>[];
  final List<BatchOp> _spill = <BatchOp>[];
  final List<BatchOp> _early = <BatchOp>[];

  /// Adds one single-write op that goes in batch 1 only.
  void fixed(BatchOp op) => _fixed.add(op);

  /// Adds one single-write money item of [amount].
  void item(BatchOp op, Money amount) => _items.add((op: op, amount: amount));

  /// Adds one single-write, non-money op.
  void spill(BatchOp op) => _spill.add(op);

  /// Adds one single-write, non-money op that goes in batch 1 ahead of the
  /// items while it fits, else overflows like [spill].
  void early(BatchOp op) => _early.add(op);

  /// How many [early] ops batch 1 holds.
  int get _earlyInFirst {
    final room = limit - fixedOps - 1;
    if (room <= 0) return 0;
    return _early.length < room ? _early.length : room;
  }

  int get fixedOps => _fixed.length;

  int get itemCount => _items.length;

  /// Items per batch.
  List<int> get chunkSizes => balancedChunkSizes(
    items: _items.length,
    firstRoom: _min(limit - fixedOps - 1 - _earlyInFirst, maxItems),
    laterRoom: _min(limit - 1, maxItems),
  );

  /// Σ of the item amounts per batch (each is that batch's increment).
  List<Money> get chunkSums {
    final sums = <Money>[];
    var at = 0;
    for (final n in chunkSizes) {
      sums.add(Money.sum(_items.skip(at).take(n).map((e) => e.amount)));
      at += n;
    }
    return sums;
  }

  /// How many batches [commit] will write.
  int get batchCount => _layout().length;

  /// Ops per batch, in commit order.
  List<int> get opsPerBatch => <int>[for (final b in _layout()) b.length];

  List<List<BatchOp>> _layout() {
    if (fixedOps + 1 > limit) {
      throw StateError('Fixed part has ${fixedOps + 1} ops (limit $limit).');
    }
    final sizes = chunkSizes;
    final sums = chunkSums;
    final out = <List<BatchOp>>[];
    var at = 0;
    for (var c = 0; c < sizes.length; c++) {
      final sum = sums[c];
      final ops = <BatchOp>[
        // The aggregate op goes first, so the contract doc exists before
        // anything that reads it back (getAfter) in this or a later batch.
        if (c == 0)
          (WriteBatch b) => firstBalance(b, sum)
        else
          (WriteBatch b) => laterBalance(b, sum),
        if (c == 0) ..._fixed,
        if (c == 0) ..._early.take(_earlyInFirst),
        for (final e in _items.skip(at).take(sizes[c])) e.op,
      ];
      at += sizes[c];
      out.add(ops);
    }
    // Spill into the room left in the last batch, then new batches.
    var count = out.last.length;
    for (final op in <BatchOp>[..._early.skip(_earlyInFirst), ..._spill]) {
      if (count >= limit) {
        out.add(<BatchOp>[]);
        count = 0;
      }
      out.last.add(op);
      count++;
    }
    return out;
  }

  /// Commits the batches in order with [commitInOrder]: each waits for its
  /// server ack (up to [perBatchGrace]) before the next is sent. Only for
  /// writes on a contract that already exists (opening-balance reversal,
  /// cancel); a new contract's later batches are never sent this way.
  Future<void> commit({Duration perBatchGrace = defaultPerBatchGrace}) {
    final batches = <WriteBatch>[];
    for (final ops in _layout()) {
      final b = _db.batch();
      for (final op in ops) {
        op(b);
      }
      batches.add(b);
    }
    return commitInOrder(batches, perBatchGrace: perBatchGrace);
  }
}

/// How long [commitInOrder] waits for one batch's ack before it stops
/// waiting.
const Duration defaultPerBatchGrace = Duration(seconds: 3);

/// Commits [batches] one at a time: each waits for its server ack (up to
/// [perBatchGrace]) before the next is sent, so the server sees them in
/// order. If one is not acknowledged in time (offline), the rest are
/// committed right away without waiting: they queue in the cache in
/// submission order. Only for batches whose rules do not depend on an
/// earlier batch of the same call (the contract already exists). Completes
/// when every batch is acknowledged; a later failure is rethrown.
Future<void> commitInOrder(
  List<WriteBatch> batches, {
  Duration perBatchGrace = defaultPerBatchGrace,
}) async {
  for (var i = 0; i < batches.length; i++) {
    final f = batches[i].commit();
    try {
      await f.timeout(perBatchGrace);
    } on TimeoutException {
      final rest = <Future<void>>[
        f,
        for (final b in batches.skip(i + 1)) b.commit(),
      ];
      await Future.wait(rest);
      return;
    }
  }
}
