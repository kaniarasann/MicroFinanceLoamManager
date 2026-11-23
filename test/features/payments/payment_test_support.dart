import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/payments/data/payment_repository.dart';

import '../contracts/contract_test_support.dart';

export '../contracts/contract_test_support.dart';

/// Writes [contract], its base schedule (or [installments]) and [txs] to
/// [db] under [kCid], plus the company doc.
Future<void> seedLoan(
  FakeFirebaseFirestore db,
  Contract contract, {
  List<Installment>? installments,
  List<LedgerTransaction> txs = const <LedgerTransaction>[],
  int nextLoanNo = 3,
}) async {
  final refs = TypedRefs(db);
  await seedCompany(db, nextLoanNo: nextLoanNo);
  await refs.contract(kCid, contract.id).set(contract);
  for (final i in installments ?? scheduleFor(contract)) {
    await refs.installment(kCid, i.id).set(i);
  }
  for (final t in txs) {
    await refs.transaction(kCid, t.id).set(t);
  }
}

/// Reads [contractId]'s docs back from [db], as the live listeners would.
Future<ContractSnapshot> readSnapshot(
  FakeFirebaseFirestore db,
  String contractId,
) async {
  final refs = TypedRefs(db);
  final c = (await refs.contract(kCid, contractId).get()).data()!;
  final inst = await refs
      .installments(kCid)
      .where('contractId', isEqualTo: contractId)
      .get();
  final txs = await refs
      .transactions(kCid)
      .where('contractId', isEqualTo: contractId)
      .get();
  return ContractSnapshot(
    contract: c,
    installments: <Installment>[for (final d in inst.docs) d.data()],
    transactions: <LedgerTransaction>[for (final d in txs.docs) d.data()],
  );
}

/// Raw docs of [col] for [contractId].
Future<List<Map<String, dynamic>>> rawDocs(
  FakeFirebaseFirestore db,
  String col,
  String contractId,
) async => <Map<String, dynamic>>[
  for (final d
      in (await db
              .collection('companies/$kCid/$col')
              .where('contractId', isEqualTo: contractId)
              .get())
          .docs)
    <String, dynamic>{...d.data(), 'id': d.id},
];

/// Raw contract doc.
Future<Map<String, dynamic>> rawContract(
  FakeFirebaseFirestore db,
  String id,
) async => (await db.doc('companies/$kCid/contracts/$id').get()).data()!;

/// A ₹30,000 weekly contract (3 × ₹10,000 from Tue 31 Oct 2023) with
/// [paidRs] already paid in one payment `tx-p1`.
({Contract contract, List<LedgerTransaction> txs}) smallLoan({
  int paidRs = 0,
  int sanctionedRs = 30000,
  ContractStatus status = ContractStatus.active,
}) {
  final c = makeContract(
    sanctioned: rs(sanctionedRs),
    upfrontInput: 0,
    status: status,
  ).copyWith(totalPaid: rs(paidRs));
  return (
    contract: c,
    txs: <LedgerTransaction>[
      tx(
        'c1',
        rs(sanctionedRs),
        d(2023, 10, 24),
        type: TxType.disbursement,
        id: 'tx-d',
      ),
      if (paidRs > 0) tx('c1', rs(paidRs), d(2023, 10, 31), id: 'tx-p1'),
    ],
  );
}
