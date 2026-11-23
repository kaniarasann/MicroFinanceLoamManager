import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/firebase/chunked_batch.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/payments/application/payment_providers.dart';

import '../../domain/ledger/ledger_fixtures.dart';

void main() {
  group('ChunkedBatch', () {
    test('primary + spill within the limit is one batch', () {
      final b = ChunkedBatch(FakeFirebaseFirestore())..primary((_) {}, ops: 2);
      for (var i = 0; i < 448; i++) {
        b.spill((_) {});
      }
      expect(b.batchCount, 1);
      b.spill((_) {});
      expect(b.batchCount, 2);
    });

    test('commits every op across batches', () async {
      final db = FakeFirebaseFirestore();
      final b = ChunkedBatch(db, limit: 3)
        ..primary(
          (WriteBatch w) => w.set(db.doc('x/p'), <String, Object?>{'v': 1}),
        );
      for (var i = 0; i < 7; i++) {
        b.spill(
          (WriteBatch w) => w.set(db.doc('x/s$i'), <String, Object?>{'v': i}),
        );
      }
      expect(b.batchCount, 3);
      await b.commit();
      expect((await db.collection('x').get()).docs, hasLength(8));
    });

    test('an atomic part above the limit throws', () {
      final b = ChunkedBatch(FakeFirebaseFirestore(), limit: 2)
        ..primary((_) {}, ops: 3);
      expect(b.commit, throwsStateError);
    });
  });

  test('quick amounts: Full due = next remainder; Advance = next two '
      'installments capped at outstanding', () {
    final c = makeContract(); // 10 × ₹10,000 weekly
    var p = project(c, <LedgerTransaction>[
      tx('c1', rs(36000), d(2023, 10, 31)),
    ], d(2023, 11, 1));
    var q = QuickAmounts.of(p);
    expect(q.fullDue, rs(4000));
    expect(q.advance, rs(14000));

    p = project(c, <LedgerTransaction>[
      tx('c1', rs(95000), d(2023, 10, 31)),
    ], d(2023, 11, 1));
    q = QuickAmounts.of(p);
    expect(q.fullDue, rs(5000));
    expect(q.advance, rs(5000));
  });

  test('receipt message', () {
    expect(
      receiptMessage(
        amount: rs(4000),
        borrowerName: 'Anita Sharma',
        loanNo: 4,
        paidOn: d(2023, 12, 3),
        mode: PaymentMode.cash,
        balance: rs(60000),
        companyName: 'Sri Lakshmi Finance',
      ),
      'Received ₹4,000 from Anita Sharma for Loan #04 on 3 Dec 2023 via '
      'Cash. Balance: ₹60,000. — Sri Lakshmi Finance',
    );
  });

  test('record validation: rolled-over loans skip the outstanding cap', () {
    final c = makeContract(status: ContractStatus.rolledOver);
    expect(validateRecordAmount(rs(50000), c, rs(0)), isEmpty);
    expect(validateRecordAmount(null, c, rs(0)), hasLength(1));
    expect(validateRecordAmount(rs(2), makeContract(), rs(1)), hasLength(1));
  });
}
