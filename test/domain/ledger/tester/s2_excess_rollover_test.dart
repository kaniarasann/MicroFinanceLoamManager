// Tester (Sprint 2): excess collection and rollover maths.
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import '../ledger_fixtures.dart';

void main() {
  final c = makeContract();

  test('two offline payments over the balance -> excess 5k, outstanding 0', () {
    final p = project(c, [
      tx('c1', rs(95000), d(2023, 10, 31)),
      tx('c1', rs(5000), d(2023, 11, 7)), // device A, offline
      tx('c1', rs(5000), d(2023, 11, 7)), // device B, offline
    ], d(2023, 11, 8));
    expect(p.totalPaid, rs(105000));
    expect(p.outstanding, Money.zero);
    expect(p.excess, rs(5000));
    expect(p.isSettled, isTrue);
  });

  test('exactly sanctioned -> no excess', () {
    final p = project(c, [
      tx('c1', rs(100000), d(2023, 10, 31)),
    ], d(2023, 10, 31));
    expect(p.excess, Money.zero);
    expect(p.overdueCount, 0);
  });

  test('payment after rollover is excess on the old contract', () {
    final old = makeContract(status: ContractStatus.rolledOver);
    final p = project(old, [
      tx('c1', rs(40000), d(2023, 11, 20)),
      tx('c1', rs(60000), d(2023, 11, 25), type: TxType.rolloverSettlement),
      tx('c1', rs(10000), d(2023, 11, 28)), // offline collector, late sync
    ], d(2023, 11, 28));
    expect(p.outstanding, Money.zero);
    expect(p.excess, rs(10000));
  });

  group('rollover quote', () {
    ContractProjection oldWith60kOutstanding() =>
        project(c, [tx('c1', rs(40000), d(2023, 11, 20))], d(2023, 11, 21));

    test('1.5L new, flat 15k, old outstanding 60k -> net 75,000 valid', () {
      final q = computeRollover(
        oldProjection: oldWith60kOutstanding(),
        newSanctioned: rs(150000),
        upfrontMode: UpfrontMode.flat,
        upfrontInput: 1500000,
      );
      expect(q.settledOldOutstanding, rs(60000));
      expect(q.newUpfront, rs(15000));
      expect(q.netCash, rs(75000));
      expect(q.isValid, isTrue);
      expect(q.error, isNull);
    });

    test('net exactly 0 is allowed', () {
      final q = computeRollover(
        oldProjection: oldWith60kOutstanding(),
        newSanctioned: rs(66000),
        upfrontMode: UpfrontMode.flat,
        upfrontInput: 600000,
      );
      expect(q.netCash, Money.zero);
      expect(q.isValid, isTrue);
    });

    test('negative net is invalid with an error', () {
      final q = computeRollover(
        oldProjection: oldWith60kOutstanding(),
        newSanctioned: rs(50000),
        upfrontMode: UpfrontMode.flat,
        upfrontInput: 500000,
      );
      expect(q.netCash, rs(-15000));
      expect(q.isValid, isFalse);
      expect(q.error, isNotNull);
    });

    test('zero new sanctioned is invalid', () {
      final q = computeRollover(
        oldProjection: oldWith60kOutstanding(),
        newSanctioned: Money.zero,
        upfrontMode: UpfrontMode.flat,
        upfrontInput: 0,
      );
      expect(q.isValid, isFalse);
    });

    test('percent upfront > 100% is invalid', () {
      final q = computeRollover(
        oldProjection: oldWith60kOutstanding(),
        newSanctioned: rs(150000),
        upfrontMode: UpfrontMode.percent,
        upfrontInput: 10001,
      );
      expect(q.isValid, isFalse);
    });
  });
}
