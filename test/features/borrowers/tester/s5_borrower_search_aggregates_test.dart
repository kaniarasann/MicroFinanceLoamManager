// Tester — Sprint 5: borrower search, duplicate phone, aggregates.
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/validation/borrower_validators.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/borrowers/application/borrower_providers.dart';

import '../../../domain/ledger/ledger_fixtures.dart';
import '../borrower_test_support.dart';

Contract _c(
  String id, {
  required int sanctionedRs,
  required int installmentRs,
  required DateTime first,
  ContractStatus status = ContractStatus.active,
  int paidRs = 0,
}) => makeContract(
  id: id,
  loanNo: id.hashCode % 50,
  sanctioned: rs(sanctionedRs),
  installment: rs(installmentRs),
  firstDue: d(first.year, first.month, first.day),
  status: status,
  upfrontInput: 0,
).copyWith(borrowerId: 'b1', totalPaid: rs(paidRs));

void main() {
  group('search', () {
    final b = borrowerDoc('b1', 'Anita Sharma', '+919845012890');
    final other = borrowerDoc('b2', 'Ravi Kumar', '+919000011111');

    test('"98450" and "+91 98450" both find the same borrower only', () {
      for (final q in <String>['98450', '+91 98450', ' +91-98450 ']) {
        expect(matchesBorrowerQuery(b, q), isTrue, reason: q);
        expect(matchesBorrowerQuery(other, q), isFalse, reason: q);
      }
    });

    test('name search is case-insensitive; unrelated digits miss', () {
      expect(matchesBorrowerQuery(b, 'ANITA'), isTrue);
      expect(matchesBorrowerQuery(b, '77777'), isFalse);
    });
  });

  group('duplicate phone', () {
    final phones = <String, String>{'b1': '+919845012890'};

    test('same number in any format is a duplicate of b1', () {
      for (final input in <String>[
        '9845012890',
        '+91 98450 12890',
        '098450-12890',
      ]) {
        expect(
          BorrowerValidators.duplicateOf(input, phones),
          'b1',
          reason: input,
        );
      }
      expect(
        BorrowerValidators.duplicatePhone('Anita Sharma'),
        'This mobile is already saved for Anita Sharma.',
      );
    });

    test('editing b1 itself is not a duplicate; a new number is not', () {
      expect(
        BorrowerValidators.duplicateOf('9845012890', phones, selfId: 'b1'),
        isNull,
      );
      expect(BorrowerValidators.duplicateOf('9845012891', phones), isNull);
    });
  });

  test('aggregates: 2 active + 1 closed', () {
    final today = d(2023, 11, 7);
    final a1 = _c(
      'a1',
      sanctionedRs: 20000,
      installmentRs: 5000,
      first: DateTime(2023, 10, 31),
      paidRs: 5000,
    );
    final a2 = _c(
      'a2',
      sanctionedRs: 10000,
      installmentRs: 2000,
      first: DateTime(2023, 10, 24),
      paidRs: 2000,
    );
    final cl = _c(
      'cl',
      sanctionedRs: 6000,
      installmentRs: 3000,
      first: DateTime(2023, 9, 5),
      status: ContractStatus.closed,
      paidRs: 6000,
    );
    final txs = <LedgerTransaction>[
      txFor(a1, 'a1-d', 20000, d(2023, 10, 24), type: TxType.disbursement),
      txFor(a1, 'a1-p', 5000, d(2023, 10, 31)),
      txFor(a2, 'a2-p', 2000, d(2023, 10, 24)),
      txFor(cl, 'cl-p1', 3000, d(2023, 9, 5)),
      txFor(cl, 'cl-p2', 3000, d(2023, 9, 12)),
    ];
    ContractProjection p(Contract c) => projectContract(
      contract: c,
      installments: scheduleFor(c),
      transactions: txs.where((t) => t.contractId == c.id).toList(),
      today: today,
    );
    final s = summarizeBorrower(
      active: <ContractProjection>[p(a1), p(a2)],
      contracts: <Contract>[a1, a2, cl],
      transactions: txs,
      today: today,
    );
    expect(s.activeExposure, rs(23000)); // 15,000 + 8,000
    expect(s.lifetimeLent, rs(36000));
    expect(s.collected, rs(13000)); // disbursement excluded
    expect(s.active, hasLength(2));
    expect(s.closed.map((c) => c.id), <String>['cl']);
    expect(s.stats.activeCount, 2);
    expect(s.stats.outstanding, rs(23000));
    expect(s.stats.standing, Standing.overdue); // a2 missed 31 Oct
    expect(s.stats.maxDaysOverdue, 7);
  });
}
