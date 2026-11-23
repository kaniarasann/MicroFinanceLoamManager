import 'package:cloud_firestore/cloud_firestore.dart';

/// Ops per batch we allow ourselves (Firestore's hard limit is 500).
const int maxOpsPerBatch = 450;

/// Adds one or more writes to a batch.
typedef BatchOp = void Function(WriteBatch batch);

/// A ledger write that must stay atomic (the primary ops) plus bookkeeping
/// writes that may spill over (spill ops, e.g. `contractActive` flips).
///
/// The first batch holds every primary op and as many spill ops as fit in
/// [limit]; the remaining spill ops go into follow-up batches of at most
/// [limit]. All batches are committed at once, so each lands in the
/// offline cache immediately and queues independently.
final class ChunkedBatch {
  ChunkedBatch(this._db, {this.limit = maxOpsPerBatch});

  final FirebaseFirestore _db;
  final int limit;
  final List<BatchOp> _primary = <BatchOp>[];
  final List<BatchOp> _spill = <BatchOp>[];
  int _primaryOps = 0;

  /// Adds an atomic op that writes [ops] operations (default 1).
  void primary(BatchOp op, {int ops = 1}) {
    _primary.add(op);
    _primaryOps += ops;
  }

  /// Adds one non-atomic single-write op.
  void spill(BatchOp op) => _spill.add(op);

  int get primaryCount => _primaryOps;

  int get spillCount => _spill.length;

  /// How many batches [commit] will write.
  int get batchCount {
    final room = limit - _primaryOps;
    final rest = _spill.length - (room > 0 ? room : 0);
    return 1 + (rest <= 0 ? 0 : (rest + limit - 1) ~/ limit);
  }

  /// Commits everything; completes when the server acknowledged every
  /// batch. The first batch (the money fields) is committed first.
  Future<void> commit() {
    if (_primaryOps > limit) {
      throw StateError('Atomic part has $_primaryOps ops (limit $limit).');
    }
    final batches = <WriteBatch>[];
    var current = _db.batch();
    for (final op in _primary) {
      op(current);
    }
    var count = _primaryOps;
    for (final op in _spill) {
      if (count >= limit) {
        batches.add(current);
        current = _db.batch();
        count = 0;
      }
      op(current);
      count++;
    }
    batches.add(current);
    return Future.wait(<Future<void>>[
      for (final b in batches) b.commit(),
    ]).then((_) {});
  }
}
