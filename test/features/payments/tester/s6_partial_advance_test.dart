import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/payments/data/payment_repository.dart';

import '../payment_test_support.dart';

/// Tester S6: a ₹1,00,000 loan with ₹10,000 weekly installments
/// (10 rows from Tue 31 Oct 2023).
void main() {
  late FakeFirebaseFirestore db;
  late PaymentRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = PaymentRepository(firestore: db, clock: clockAt(d(2023, 10, 31)));
    final c = makeContract(); // ₹1,00,000, 10 × ₹10,000, upfront ₹7,000
    await seedLoan(
      db,
      c,
      txs: <LedgerTransaction>[
        tx(
          'c1',
          rs(93000),
          d(2023, 10, 24),
          type: TxType.disbursement,
          id: 'tx-d',
        ),
      ],
    );
  });

  Future<PaymentWriteResult> pay(int rupees, {CivilDate? on}) async =>
      repo.recordPayment(
        RecordPaymentCommand(
          cid: kCid,
          snapshot: await readSnapshot(db, 'c1'),
          amount: rs(rupees),
          paidOn: on ?? d(2023, 10, 31),
          mode: PaymentMode.cash,
          actor: kActor,
        ),
      );

  Future<ContractProjection> projectAt(CivilDate today) async {
    final s = await readSnapshot(db, 'c1');
    return projectContract(
      contract: s.contract,
      installments: s.installments,
      transactions: s.transactions,
      today: today,
    );
  }

  test('₹6,000 on installment 1 → partial, outstanding ₹94,000', () async {
    final r = await pay(6000);
    expect(r.closed, isFalse);
    expect(r.balanceAfter, rs(94000));
    final p = await projectAt(d(2023, 10, 31));
    expect(p.rows.first.isPartial, isTrue);
    expect(p.rows.first.paid, rs(6000));
    expect(p.outstanding, rs(94000));
  });

  test('after the due date the extension row is ₹4,000; paying ₹4,000 late '
      'removes it', () async {
    await pay(6000);
    var p = await projectAt(d(2023, 11, 1));
    expect(p.rows.first.status, RowStatus.overdue);
    expect(p.extensionRows, hasLength(1));
    expect(p.extensionRows.single.due, rs(4000));
    expect(p.extensionRows.single.dueDate.isAfter(d(2024, 1, 1)), isTrue);

    await pay(4000, on: d(2023, 11, 1));
    p = await projectAt(d(2023, 11, 1));
    expect(p.extensionRows, isEmpty);
    expect(p.rows.first.status, RowStatus.paid);
    expect(p.hasOverdue, isFalse);
    expect(p.outstanding, rs(90000));
  });

  test(
    'an advance of ₹30,000 covers installments 1–3; next due is #4',
    () async {
      await pay(30000);
      final p = await projectAt(d(2023, 10, 31));
      for (final row in p.rows.take(3)) {
        expect(row.status, RowStatus.paid, reason: 'row ${row.seq}');
      }
      expect(p.rows[3].status, isNot(RowStatus.paid));
      expect(p.nextDue?.seq, 4);
      expect(p.nextDue?.dueDate, d(2023, 11, 21));
      expect(p.outstanding, rs(70000));
    },
  );
}
