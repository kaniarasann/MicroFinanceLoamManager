import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import 'ledger_fixtures.dart';

/// 1,000 active contracts × 52 weekly installments + ~20 payments each.
/// Asserts projections + portfolio fold (+ chart series and calendar) run in
/// under 500 ms in the test VM.
void main() {
  test('computePortfolio over 1,000 contracts < 500 ms', () {
    final today = d(2024, 3, 6);
    final contracts = <Contract>[];
    final installments = <String, List<Installment>>{};
    final transactions = <String, List<LedgerTransaction>>{};
    final all = <LedgerTransaction>[];

    for (var i = 0; i < 1000; i++) {
      final first = d(2023, 10, 2).addDays(i % 28);
      final c = makeContract(
        id: 'c$i',
        loanNo: i + 1,
        borrowerName: 'Borrower $i',
        sanctioned: rs(52000),
        installment: rs(1000),
        weekday: first.weekday,
        firstDue: first,
        disbursedOn: first.addDays(-7),
      );
      contracts.add(c);
      installments[c.id] = scheduleFor(c);
      final payments = 18 + i % 5; // ~20
      final list = <LedgerTransaction>[
        for (var k = 0; k < payments; k++)
          tx(c.id, rs(k.isEven ? 1000 : 900), first.addDays(7 * k)),
      ];
      transactions[c.id] = list;
      all.addAll(list);
    }
    final byId = <String, Contract>{for (final c in contracts) c.id: c};

    PortfolioMetrics run() {
      final projections = <ContractProjection>[
        for (final c in contracts)
          projectContract(
            contract: c,
            installments: installments[c.id]!,
            transactions: transactions[c.id]!,
            today: today,
          ),
      ];
      final m = computePortfolio(
        projections: projections,
        allTransactions: all,
        today: today,
        contractsById: byId,
      );
      m.collectionsSeries(ChartPeriod.weeks8);
      m.calendarBuckets(today.year, today.month);
      return m;
    }

    run(); // Warm-up (JIT).
    final sw = Stopwatch()..start();
    final m = run();
    sw.stop();

    // ignore: avoid_print
    print(
      'ledger benchmark: 1000 contracts × 52 installments, '
      '${all.length} payments → ${sw.elapsedMilliseconds} ms',
    );
    expect(m.overdueInstallmentCount, greaterThan(0));
    expect(m.sanctionedReceivable.isPositive, isTrue);
    expect(sw.elapsedMilliseconds, lessThan(500));
  });
}
