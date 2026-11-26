import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/firebase/balanced_chunks.dart';
import 'package:nordic_ledger/core/money/money.dart';

void main() {
  late FakeFirebaseFirestore db;

  /// Per batch (by identity): Σ of item amounts and the balance written.
  late Map<WriteBatch, int> itemSums;
  late Map<WriteBatch, int> balances;
  late List<WriteBatch> order;

  setUp(() {
    db = FakeFirebaseFirestore();
    itemSums = <WriteBatch, int>{};
    balances = <WriteBatch, int>{};
    order = <WriteBatch>[];
  });

  void seen(WriteBatch b) {
    if (!order.contains(b)) order.add(b);
  }

  BalancedChunks chunks({int limit = 5}) => BalancedChunks(
    db,
    limit: limit,
    firstBalance: (WriteBatch b, Money sum) {
      seen(b);
      balances[b] = sum.paise;
      b.set(db.doc('c/agg'), <String, Object?>{
        'total': FieldValue.increment(sum.paise),
      });
    },
    laterBalance: (WriteBatch b, Money sum) {
      seen(b);
      balances[b] = sum.paise;
      b.update(db.doc('c/agg'), <String, Object?>{
        'total': FieldValue.increment(sum.paise),
      });
    },
  );

  void addItems(BalancedChunks out, int n) {
    for (var i = 1; i <= n; i++) {
      out.item((WriteBatch b) {
        seen(b);
        itemSums[b] = (itemSums[b] ?? 0) + i;
        b.set(db.doc('t/$i'), <String, Object?>{'amount': i});
      }, Money(i));
    }
  }

  test('fixed + balance + items fill batch 1, later batches balance', () async {
    final out = chunks();
    out.fixed((WriteBatch b) => b.set(db.doc('f/1'), <String, Object?>{}));
    addItems(out, 10); // room: 5 − 1 fixed − 1 balance = 3, then 4 each
    expect(out.fixedOps, 1);
    expect(out.itemCount, 10);
    expect(out.chunkSizes, <int>[3, 4, 3]);
    expect(out.chunkSums, <Money>[
      const Money(6),
      const Money(22),
      const Money(27),
    ]);
    expect(out.batchCount, 3);
    expect(out.opsPerBatch, <int>[5, 5, 4]);

    await out.commit();
    expect(order, hasLength(3));
    for (final b in order) {
      expect(balances[b], itemSums[b], reason: 'each batch balances itself');
    }
    final agg = (await db.doc('c/agg').get()).data()!;
    expect(agg['total'], 55);
    expect((await db.collection('t').get()).docs, hasLength(10));
    expect((await db.doc('f/1').get()).exists, isTrue);
  });

  test('no items: one batch with a zero balance', () async {
    final out = chunks();
    expect(out.chunkSizes, <int>[0]);
    expect(out.chunkSums, <Money>[Money.zero]);
    expect(out.batchCount, 1);
    await out.commit();
    expect((await db.doc('c/agg').get()).data()!['total'], 0);
  });

  test('spill ops fill the last batch, then new batches', () async {
    final out = chunks();
    addItems(out, 2); // batch 1: balance + 2 items = 3 ops
    for (var i = 0; i < 5; i++) {
      out.spill(
        (WriteBatch b) => b.set(db.doc('s/$i'), <String, Object?>{'i': i}),
      );
    }
    expect(out.opsPerBatch, <int>[5, 3]);
    expect(out.batchCount, 2);
    await out.commit();
    expect((await db.collection('s').get()).docs, hasLength(5));
    expect((await db.doc('c/agg').get()).data()!['total'], 3);
  });

  test('a fixed part that cannot fit throws', () {
    final out = chunks(limit: 2);
    out
      ..fixed((WriteBatch b) {})
      ..fixed((WriteBatch b) {});
    expect(() => out.batchCount, throwsStateError);
    expect(out.commit, throwsStateError);
  });

  test('default limit is maxOpsPerBatch', () {
    final out = BalancedChunks(
      db,
      firstBalance: (WriteBatch b, Money s) {},
      laterBalance: (WriteBatch b, Money s) {},
    );
    expect(out.limit, maxOpsPerBatch);
  });
}
