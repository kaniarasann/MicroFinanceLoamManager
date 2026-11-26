import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/ledger/onboarding.dart' show balancedChunkSizes;
import '../money/money.dart';
import 'chunked_batch.dart';

export 'chunked_batch.dart' show BatchOp, maxOpsPerBatch;

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
///   items as fit in [limit].
/// - Batches 2…m: up to `limit − 1` items plus the [laterBalance] op.
/// - [spill] ops (non-money bookkeeping such as `contractActive` flips)
///   fill the room left in the last batch, then further batches.
///
/// All batches are committed at once, in order, like [ChunkedBatch]: each
/// lands in the offline cache immediately and queues in submission order.
final class BalancedChunks {
  BalancedChunks(
    this._db, {
    required this.firstBalance,
    required this.laterBalance,
    this.limit = maxOpsPerBatch,
  });

  final FirebaseFirestore _db;
  final BalanceOp firstBalance;
  final BalanceOp laterBalance;
  final int limit;

  final List<BatchOp> _fixed = <BatchOp>[];
  final List<({BatchOp op, Money amount})> _items =
      <({BatchOp op, Money amount})>[];
  final List<BatchOp> _spill = <BatchOp>[];

  /// Adds one single-write op that goes in batch 1 only.
  void fixed(BatchOp op) => _fixed.add(op);

  /// Adds one single-write money item of [amount].
  void item(BatchOp op, Money amount) => _items.add((op: op, amount: amount));

  /// Adds one single-write, non-money op.
  void spill(BatchOp op) => _spill.add(op);

  int get fixedOps => _fixed.length;

  int get itemCount => _items.length;

  /// Items per batch.
  List<int> get chunkSizes => balancedChunkSizes(
    items: _items.length,
    firstRoom: limit - fixedOps - 1,
    laterRoom: limit - 1,
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
        for (final e in _items.skip(at).take(sizes[c])) e.op,
      ];
      at += sizes[c];
      out.add(ops);
    }
    // Spill into the room left in the last batch, then new batches.
    var count = out.last.length;
    for (final op in _spill) {
      if (count >= limit) {
        out.add(<BatchOp>[]);
        count = 0;
      }
      out.last.add(op);
      count++;
    }
    return out;
  }

  /// Commits every batch; completes when the server acknowledged all.
  Future<void> commit() {
    final batches = <WriteBatch>[];
    for (final ops in _layout()) {
      final b = _db.batch();
      for (final op in ops) {
        op(b);
      }
      batches.add(b);
    }
    return Future.wait(<Future<void>>[
      for (final b in batches) b.commit(),
    ]).then((_) {});
  }
}
