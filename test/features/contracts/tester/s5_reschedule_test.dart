// Tester — Sprint 5: reschedule batch, validation, projection integrity.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/features/contracts/data/contract_repository.dart';

import '../contract_test_support.dart';

/// ₹30,000 weekly ₹10,000 from Tue 31 Oct 2023, ₹4,000 paid on 31 Oct.
/// Today Tue 14 Nov: inst 1 partial-overdue (₹6,000 short), inst 2 missed,
/// inst 3 due today.
LedgerSeed missedSeed() {
  final c = contractFor(
    'b1',
    'm1',
    loanNo: 7,
    sanctionedRs: 30000,
    installmentRs: 10000,
    firstDue: d(2023, 10, 31),
    totalPaidRs: 4000,
  );
  return LedgerSeed()
    ..borrowers.add(anita())
    ..contracts.add(c)
    ..transactions.add(txFor(c, 'm1-p1', 4000, d(2023, 10, 31)));
}

final CivilDate kNow = d(2023, 11, 14);

void main() {
  late FakeFirebaseFirestore db;
  late ContractRepository repo;
  late TypedRefs refs;

  setUp(() async {
    db = FakeFirebaseFirestore();
    refs = TypedRefs(db);
    repo = ContractRepository(firestore: db, clock: clockAt(kNow));
    await seedCompany(db);
    await missedSeed().writeTo(db);
  });

  Future<ContractProjection> project() async {
    final c = (await refs.contract(kCid, 'm1').get()).data()!;
    final inst = (await refs.installments(kCid).get()).docs
        .map((s) => s.data())
        .toList();
    final txs = (await refs.transactions(kCid).get()).docs
        .map((s) => s.data())
        .toList();
    return projectContract(
      contract: c,
      installments: inst,
      transactions: txs,
      today: kNow,
    );
  }

  Future<RescheduleCommand> rc(String srcId, Money amt, CivilDate on) async {
    final p = await project();
    final src = (await refs.installment(kCid, srcId).get()).data()!;
    final row = p.rows.firstWhere((r) => r.installmentId == srcId);
    return RescheduleCommand(
      cid: kCid,
      source: src,
      amount: amt,
      newDueDate: on,
      remaining: row.due - row.paid,
      maxSeq: 3,
      today: kNow,
      actor: kActor,
    );
  }

  test('fixture: inst 1 partial ₹6,000 short, inst 2 missed', () async {
    final p = await project();
    final r1 = p.rows.firstWhere((r) => r.installmentId == 'm1-i1');
    expect(r1.due - r1.paid, rs(6000));
    expect(p.outstanding, rs(26000));
  });

  test('more than the unpaid remainder (₹6,001 of ₹6,000) rejected', () async {
    await expectLater(
      repo.reschedule(await rc('m1-i1', rs(6001), d(2023, 11, 20))),
      throwsA(isA<ValidationFailure>()),
    );
    final s = (await refs.installment(kCid, 'm1-i1').get()).data()!;
    expect(s.rescheduledOut, Money.zero);
    expect((await refs.installments(kCid).get()).docs, hasLength(3));
  });

  test('a past date (yesterday) rejected; today is allowed', () async {
    await expectLater(
      repo.reschedule(await rc('m1-i2', rs(10000), d(2023, 11, 13))),
      throwsA(isA<ValidationFailure>()),
    );
    await repo.reschedule(await rc('m1-i2', rs(10000), kNow));
    expect((await refs.installments(kCid).get()).docs, hasLength(4));
  });

  test('after a reschedule: outstanding unchanged, no double count', () async {
    final before = await project();
    await repo.reschedule(await rc('m1-i2', rs(10000), d(2023, 11, 25)));
    final after = await project();
    expect(after.outstanding, before.outstanding);
    expect(after.outstanding, rs(26000));
    expect(after.totalPaid, rs(4000));
    // Real (non-extension) rows sum to the sanctioned amount exactly once.
    final owed = after.rows
        .where((r) => r.status != RowStatus.rescheduled && !r.isExtension)
        .fold<Money>(Money.zero, (a, r) => a + r.due);
    expect(owed, rs(30000));
    // inst 2 is no longer missed, so it is not auto-extended.
    final ext = after.rows.where((r) => r.isExtension).toList();
    final extBefore = before.rows.where((r) => r.isExtension).toList();
    expect(ext.length, extBefore.length - 1);
    expect(after.overdueAmount, rs(6000));
  });

  test('partial reschedule ₹6,000 of inst 1 leaves no overdue on it', () async {
    await repo.reschedule(await rc('m1-i1', rs(6000), d(2023, 11, 21)));
    final p = await project();
    expect(p.outstanding, rs(26000));
    expect(p.overdueAmount, rs(10000)); // only inst 2 still missed
  });
}
