import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import 'ledger_fixtures.dart';

void main() {
  final c = makeContract(); // 10 × ₹10,000 weekly from Tue 31 Oct 2023

  LedgerTransaction pay(
    String id,
    int rupees,
    int month,
    int day, {
    TxType type = TxType.payment,
    PaymentMode? mode = PaymentMode.cash,
    DateTime? recordedAt,
  }) => tx(
    'c1',
    rs(rupees),
    d(2023, month, day),
    type: type,
    id: id,
  ).copyWith(mode: mode, recordedAt: recordedAt);

  group('rowSettlements', () {
    test('a row is cleared by the payment that completes it', () {
      final txs = <LedgerTransaction>[
        pay('a', 6000, 10, 31, mode: PaymentMode.upi),
        pay('b', 14000, 11, 7, mode: PaymentMode.bank),
        pay('x', 93000, 10, 24, type: TxType.disbursement, mode: null),
        pay('r', 0, 11, 8, type: TxType.reschedule, mode: null),
        tx('other', rs(50000), d(2023, 10, 31)),
      ];
      final p = project(c, txs, d(2023, 11, 20));
      final s = rowSettlements(p, txs);
      expect(s.keys, unorderedEquals(<String>['c1-i1', 'c1-i2']));
      expect(
        s['c1-i1'],
        RowSettlement(clearedOn: d(2023, 11, 7), mode: PaymentMode.bank),
      );
      expect(s['c1-i2']!.clearedOn, d(2023, 11, 7));
      expect(s['c1-i1'] == s['c1-i2'], isTrue);
      expect(s['c1-i1'].hashCode, s['c1-i2'].hashCode);
      expect(s['c1-i1'].toString(), contains('bank'));
    });

    test('a reversal un-clears; the next payment clears again', () {
      final txs = <LedgerTransaction>[
        pay('a', 10000, 10, 31),
        pay('rev', 10000, 11, 1, type: TxType.reversal, mode: null),
        pay('c', 10000, 11, 3, mode: PaymentMode.upi),
      ];
      final p = project(c, txs, d(2023, 11, 5));
      final s = rowSettlements(p, txs);
      expect(
        s['c1-i1'],
        RowSettlement(clearedOn: d(2023, 11, 3), mode: PaymentMode.upi),
      );
    });

    test(
      'same-day ties order by recorded time, then id; settlement has no mode',
      () {
        final t0 = DateTime.utc(2023, 10, 31, 4);
        final txs = <LedgerTransaction>[
          pay('z', 5000, 10, 31, recordedAt: t0),
          pay(
            'b',
            5000,
            10,
            31,
            type: TxType.rolloverSettlement,
            mode: null,
            recordedAt: t0.add(const Duration(hours: 1)),
          ),
          pay(
            'a',
            10000,
            10,
            31,
            mode: PaymentMode.upi,
            recordedAt: t0.add(const Duration(hours: 1)),
          ),
        ];
        final p = project(c, txs, d(2023, 11, 1));
        final s = rowSettlements(p, txs);
        // 'z' (5k) then 'a' (id order at the same time) completes inst 1.
        expect(s['c1-i1']!.mode, PaymentMode.upi);
        // 'b' (settlement) completes inst 2.
        expect(s['c1-i2']!.mode, isNull);
      },
    );

    test('rescheduled-away rows and extension rows are skipped', () {
      final base = scheduleFor(c);
      final moved = <Installment>[
        base[0].copyWith(rescheduledOut: rs(10000)),
        ...base.skip(1),
        installment(
          c,
          11,
          d(2023, 11, 9),
          rs(10000),
          kind: InstallmentKind.rescheduled,
          rescheduledFromId: 'c1-i1',
          id: 'm1',
        ),
      ];
      final txs = <LedgerTransaction>[pay('a', 10000, 11, 7)];
      final p = project(c, txs, d(2023, 11, 20), installments: moved);
      expect(p.extensionRows, isNotEmpty);
      final s = rowSettlements(p, txs);
      expect(s.keys, <String>['c1-i2']);
    });
  });

  group('validateReschedule', () {
    final today = d(2023, 12, 3);
    test('valid move', () {
      expect(
        validateReschedule(
          amount: rs(4000),
          remaining: rs(4000),
          newDueDate: today,
          today: today,
        ),
        isEmpty,
      );
    });
    test('amount 0, above remaining, and a past date', () {
      expect(
        validateReschedule(
          amount: Money.zero,
          remaining: rs(4000),
          newDueDate: today,
          today: today,
        ).single.field,
        LedgerFields.amount,
      );
      expect(
        validateReschedule(
          amount: rs(4001),
          remaining: rs(4000),
          newDueDate: today,
          today: today,
        ).single.message,
        'Amount cannot exceed the unpaid ₹4,000.',
      );
      expect(
        validateReschedule(
          amount: rs(1000),
          remaining: rs(4000),
          newDueDate: d(2023, 12, 2),
          today: today,
        ).single.field,
        LedgerFields.newDueDate,
      );
    });
  });
}
