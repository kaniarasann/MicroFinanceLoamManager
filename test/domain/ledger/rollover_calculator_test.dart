import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import 'ledger_fixtures.dart';

void main() {
  // Old contract: ₹1,00,000 with ₹82,000 paid → ₹18,000 outstanding.
  final old = project(makeContract(), <LedgerTransaction>[
    tx('c1', rs(82000), d(2023, 12, 26)),
  ], d(2023, 12, 27));

  RolloverQuote quote(Money sanctioned, UpfrontMode mode, int input) =>
      computeRollover(
        oldProjection: old,
        newSanctioned: sanctioned,
        upfrontMode: mode,
        upfrontInput: input,
      );

  test('₹18,000 outstanding, new ₹1,00,000 at flat ₹7,000 → ₹75,000', () {
    expect(old.outstanding, rs(18000));
    final q = quote(rs(100000), UpfrontMode.flat, 700000);
    expect(q.isValid, isTrue);
    expect(q.error, isNull);
    expect(q.settledOldOutstanding, rs(18000));
    expect(q.newUpfront, rs(7000));
    expect(q.netCash, rs(75000));
  });

  test('percent upfront', () {
    final q = quote(rs(100000), UpfrontMode.percent, 750);
    expect(q.newUpfront, rs(7500));
    expect(q.netCash, rs(74500));
    expect(q.isValid, isTrue);
  });

  test('net cash exactly 0 is valid', () {
    final q = quote(rs(25000), UpfrontMode.flat, 700000);
    expect(q.netCash, Money.zero);
    expect(q.isValid, isTrue);
  });

  test('negative net cash → invalid with a clear message', () {
    final q = quote(rs(20000), UpfrontMode.flat, 700000);
    expect(q.netCash, rs(-5000));
    expect(q.isValid, isFalse);
    expect(
      q.error,
      'The new loan of ₹20,000 minus upfront ₹7,000 does not cover the old '
      'outstanding ₹18,000. Increase the new amount by at least ₹5,000.',
    );
  });

  test('invalid terms', () {
    expect(quote(Money.zero, UpfrontMode.flat, 0).error, contains('more than'));
    expect(
      quote(rs(100000), UpfrontMode.percent, 10001).error,
      contains('100%'),
    );
    expect(quote(rs(100000), UpfrontMode.percent, -1).isValid, isFalse);
    expect(quote(rs(100000), UpfrontMode.flat, -1).error, contains('negative'));
    expect(
      quote(rs(100000), UpfrontMode.flat, 10000000).error,
      contains('less than'),
    );
  });

  test('settled old contract → full new amount minus upfront', () {
    final settled = project(makeContract(), <LedgerTransaction>[
      tx('c1', rs(100000), d(2023, 12, 26)),
    ], d(2023, 12, 27));
    final q = computeRollover(
      oldProjection: settled,
      newSanctioned: rs(50000),
      upfrontMode: UpfrontMode.flat,
      upfrontInput: 300000,
    );
    expect(q.settledOldOutstanding, Money.zero);
    expect(q.netCash, rs(47000));
  });
}
