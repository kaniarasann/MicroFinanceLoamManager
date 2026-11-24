import 'package:nordic_ledger/domain/models/models.dart';

import '../dashboard_test_support.dart';

/// Sprint 7 tester seed (today Tue 7 Nov 2023). aggregatesFixture plus:
/// - c1 Loan #04 pays its ₹10,000 7 Nov row today (UPI) → collected row;
/// - c7 Loan #07 closed early: ₹10,000, ₹9,000 cash on 6 Nov + ₹1,000
///   waiver (net ₹3,000);
/// - c8 Loan #08 rolled over: ₹20,000, ₹12,000 cash on 3 Nov + ₹8,000
///   rollover settlement on 4 Nov (net ₹13,000). [lateRs] adds a payment
///   that landed after the rollover (excess).
///
/// Hand-computed:
/// - Total collected ₹76,000 = 45,000 (aggregates) + 10,000 + 9,000 + 12,000
///   (+ lateRs);
/// - Net disbursed ₹1,75,000 = 1,59,000 + 3,000 + 13,000;
/// - Receivable ₹1,25,000 (c1 ₹80,000 + c2 ₹45,000); overdue ₹5,000;
/// - Today ₹15,000 due, ₹10,000 received (66%).
LedgerSeed s7Seed({int lateRs = 0}) {
  final seed = aggregatesFixture();
  final c1 = seed.contracts.firstWhere((Contract c) => c.id == 'c1');
  seed.transactions.add(
    txFor(c1, 't-c1-p2', 10000, d(2023, 11, 7), mode: PaymentMode.upi),
  );
  final c7 = contractFor(
    'b1',
    'c7',
    loanNo: 7,
    sanctionedRs: 10000,
    installmentRs: 5000,
    firstDue: d(2023, 10, 24),
    status: ContractStatus.closed,
    totalPaidRs: 9000,
  ).copyWith(totalWaived: inr(1000));
  final c8 = contractFor(
    'b1',
    'c8',
    loanNo: 8,
    sanctionedRs: 20000,
    installmentRs: 10000,
    firstDue: d(2023, 10, 24),
    status: ContractStatus.rolledOver,
    totalPaidRs: 20000 + lateRs,
  ).copyWith(rolloverSettled: inr(8000));
  seed.contracts.addAll(<Contract>[c7, c8]);
  seed.transactions.addAll(<LedgerTransaction>[
    txFor(c7, 't-c7-p1', 9000, d(2023, 11, 6)),
    txFor(c7, 't-c7-w1', 1000, d(2023, 11, 6), type: TxType.waiver),
    txFor(c8, 't-c8-p1', 12000, d(2023, 11, 3)),
    txFor(c8, 't-c8-s1', 8000, d(2023, 11, 4), type: TxType.rolloverSettlement),
    if (lateRs > 0) txFor(c8, 't-c8-late', lateRs, d(2023, 11, 6)),
  ]);
  return seed;
}
