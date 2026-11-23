import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/payments/data/payment_repository.dart';

import 'payment_test_support.dart';

/// Repository writes → read back → projection (what the screens render).
void main() {
  late FakeFirebaseFirestore db;
  late PaymentRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = PaymentRepository(firestore: db, clock: clockAt(d(2023, 10, 31)));
    final l = smallLoan(); // 3 × ₹10,000 on 31 Oct, 7 Nov, 14 Nov
    await seedLoan(db, l.contract, txs: l.txs);
  });

  Future<void> pay(
    int rupees, {
    ContractSnapshot? snap,
    LedgerActor actor = kActor,
  }) async {
    await repo.recordPayment(
      RecordPaymentCommand(
        cid: kCid,
        snapshot: snap ?? await readSnapshot(db, 'c1'),
        amount: rs(rupees),
        paidOn: d(2023, 10, 31),
        mode: PaymentMode.cash,
        actor: actor,
      ),
    );
  }

  Future<ContractProjection> projectAt(CivilDate today) async {
    final s = await readSnapshot(db, 'c1');
    return projectContract(
      contract: s.contract,
      installments: s.installments,
      transactions: s.transactions,
      today: today,
    );
  }

  test('after a partial payment the first row shows partial', () async {
    await pay(6000);
    final p = await projectAt(d(2023, 10, 31));
    final first = p.rows.first;
    expect(first.paid, rs(6000));
    expect(first.isPartial, isTrue);
    expect(first.status, RowStatus.dueToday);
    expect(p.extensionRows, isEmpty);
    expect(p.outstanding, rs(24000));
  });

  test('after the due date the ₹4,000 shortfall is added at the end, and a '
      'late payment removes it', () async {
    await pay(6000);
    var p = await projectAt(d(2023, 11, 1));
    expect(p.rows.first.status, RowStatus.overdue);
    final ext = p.extensionRows.toList();
    expect(ext, hasLength(1));
    expect(ext.single.due, rs(4000));
    expect(ext.single.dueDate, d(2023, 11, 21));

    await pay(4000);
    p = await projectAt(d(2023, 11, 1));
    expect(p.extensionRows, isEmpty);
    expect(p.rows.first.status, RowStatus.paid);
    expect(p.hasOverdue, isFalse);
  });

  test('two devices, both offline on the same snapshot, together exceed the '
      'balance → excess collected', () async {
    final stale = await readSnapshot(db, 'c1');
    await pay(20000, snap: stale);
    await pay(
      20000,
      snap: stale,
      actor: const LedgerActor(
        uid: 'uid-col',
        name: 'Suresh',
        deviceId: 'dev-2',
      ),
    );
    final p = await projectAt(d(2023, 11, 1));
    expect(p.hasExcess, isTrue);
    expect(p.excess, rs(10000));
    expect(p.outstanding, rs(0));
    expect((await rawContract(db, 'c1'))['totalPaidPaise'], 4000000);
  });
}
