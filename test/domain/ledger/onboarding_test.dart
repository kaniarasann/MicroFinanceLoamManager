import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import 'ledger_fixtures.dart';

/// Onboarding "today": Mon 24 Nov 2026.
final CivilDate _today = d(2026, 11, 24);

PastPaymentInput _pay(
  CivilDate on,
  int rupees, {
  PaymentMode? mode = PaymentMode.cash,
  bool opening = false,
}) => PastPaymentInput(
  paidOn: on,
  amount: rs(rupees),
  mode: mode,
  openingBalance: opening,
);

List<ValidationError> _validate({
  List<ValidationError> termErrors = const <ValidationError>[],
  Money? sanctioned,
  CivilDate? disbursedOn,
  CivilDate? firstDue,
  List<PastPaymentInput> payments = const <PastPaymentInput>[],
  String? previousRef,
}) => validateOnboarding(
  termErrors: termErrors,
  sanctioned: sanctioned ?? rs(100000),
  disbursedOn: disbursedOn ?? d(2026, 8, 25),
  firstDueDate: firstDue ?? d(2026, 9, 1),
  today: _today,
  payments: payments,
  previousRef: previousRef,
);

Set<String> _fields(List<ValidationError> errors) =>
    errors.map((ValidationError e) => e.field).toSet();

/// ₹1,00,000 weekly at ₹10,000 on Tuesdays from 1 Sep 2026: rows on
/// 1, 8, 15, 22, 29 Sep, 6, 13, 20, 27 Oct, 3 Nov (all before today).
List<PlannedInstallment> _pastWeekly() => generateSchedule(
  sanctioned: rs(100000),
  installmentAmount: rs(10000),
  frequency: Frequency.weekly,
  firstDueDate: d(2026, 9, 1),
  preferredWeekday: 2,
);

/// ₹1,00,000 weekly at ₹10,000 on Tuesdays from 4 Nov 2026: 3 rows due by
/// Mon 24 Nov (4, 11, 18 Nov) and 7 still to come.
List<PlannedInstallment> _runningWeekly() => generateSchedule(
  sanctioned: rs(100000),
  installmentAmount: rs(10000),
  frequency: Frequency.weekly,
  firstDueDate: d(2026, 11, 4),
  preferredWeekday: 3,
);

void main() {
  group('limits and helpers', () {
    test('constants match the design', () {
      expect(maxOnboardBackdateDays, 1096);
      expect(maxFirstDueAfterDisbursalDays, 366);
      expect(maxPastPayments, 1100);
      expect(maxPreviousRefLength, 40);
      expect(openingBalanceNote, 'Opening balance');
    });

    test('window helpers', () {
      expect(earliestOnboardDisbursal(_today), d(2023, 11, 24));
      expect(latestOnboardFirstDue(d(2026, 1, 1)), d(2027, 1, 2));
    });

    test('pastPaymentsTotal sums the amounts', () {
      expect(pastPaymentsTotal(const <PastPaymentInput>[]), Money.zero);
      expect(
        pastPaymentsTotal(<PastPaymentInput>[
          _pay(_today, 100),
          _pay(_today, 250),
        ]),
        rs(350),
      );
    });

    test('LedgerFields row helpers round-trip', () {
      expect(LedgerFields.pastPayment(3), 'pastPayments.3');
      expect(LedgerFields.pastPaymentIndex('pastPayments.3'), 3);
      expect(LedgerFields.pastPaymentIndex(LedgerFields.pastPayments), isNull);
      expect(LedgerFields.pastPaymentIndex('pastPayments.x'), isNull);
      expect(LedgerFields.pastPaymentIndex(LedgerFields.amount), isNull);
    });
  });

  group('PastPaymentInput', () {
    test('value equality, hashCode and toString', () {
      final a = _pay(_today, 100);
      final b = _pay(_today, 100);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == _pay(_today, 101), isFalse);
      expect(a == _pay(_today, 100, mode: PaymentMode.upi), isFalse);
      expect(a == _pay(_today, 100, opening: true), isFalse);
      expect(a == _pay(_today.addDays(-1), 100), isFalse);
      expect(a == a.copyWith(reference: 'R1'), isFalse);
      // ignore: unrelated_type_equality_checks
      expect(a == 'x', isFalse);
      expect(a.toString(), 'PastPaymentInput(2026-11-24, 10000, cash)');
      expect(
        _pay(_today, 1, mode: null, opening: true).toString(),
        'PastPaymentInput(2026-11-24, 100, null, opening)',
      );
    });

    test('copyWith keeps unspecified fields and the opening flag', () {
      final a = PastPaymentInput(
        paidOn: _today,
        amount: rs(5),
        mode: PaymentMode.bank,
        reference: 'R',
        openingBalance: true,
      );
      expect(a.copyWith(), a);
      final b = a.copyWith(
        paidOn: d(2026, 1, 1),
        amount: rs(6),
        mode: PaymentMode.upi,
        reference: 'S',
      );
      expect(b.paidOn, d(2026, 1, 1));
      expect(b.amount, rs(6));
      expect(b.mode, PaymentMode.upi);
      expect(b.reference, 'S');
      expect(b.openingBalance, isTrue);
    });
  });

  group('validateOnboarding', () {
    test('a valid backdated loan with payments → no errors', () {
      expect(
        _validate(
          payments: <PastPaymentInput>[
            _pay(d(2026, 9, 1), 10000),
            _pay(d(2026, 9, 8), 10000),
          ],
          previousRef: 'Book 3 / 117',
        ),
        isEmpty,
      );
    });

    test('nothing collected (₹0) is allowed', () {
      expect(_validate(), isEmpty);
    });

    test('term errors are passed through first', () {
      const term = ValidationError(LedgerFields.sanctioned, 'x');
      final errors = _validate(termErrors: const <ValidationError>[term]);
      expect(errors.first, term);
    });

    group('disbursedOn window [today − 1096, today]', () {
      test('today and exactly 1096 days back are allowed', () {
        expect(
          _validate(disbursedOn: _today, firstDue: _today.addDays(7)),
          isEmpty,
        );
        final oldest = _today.addDays(-1096);
        expect(
          _validate(disbursedOn: oldest, firstDue: oldest.addDays(7)),
          isEmpty,
        );
      });

      test('tomorrow is in the future', () {
        final errors = _validate(
          disbursedOn: _today.addDays(1),
          firstDue: _today.addDays(8),
        );
        expect(errors.single.field, LedgerFields.disbursedOn);
        expect(errors.single.message, 'Disbursed on cannot be in the future.');
      });

      test('1097 days back is too old', () {
        final tooOld = _today.addDays(-1097);
        final errors = _validate(
          disbursedOn: tooOld,
          firstDue: tooOld.addDays(7),
        );
        expect(errors.single.field, LedgerFields.disbursedOn);
        expect(errors.single.message, contains('3 years'));
      });
    });

    group('firstDueDate window [disbursedOn, disbursedOn + 366]', () {
      test('both edges are allowed (past or future)', () {
        expect(_validate(firstDue: d(2026, 8, 25)), isEmpty);
        expect(_validate(firstDue: d(2027, 8, 26)), isEmpty);
      });

      test('before disbursement is an error', () {
        final errors = _validate(firstDue: d(2026, 8, 24));
        expect(errors.single.field, LedgerFields.firstDueDate);
      });

      test('a term error on firstDueDate is not duplicated', () {
        const term = ValidationError(LedgerFields.firstDueDate, 'term');
        final errors = _validate(
          termErrors: const <ValidationError>[term],
          firstDue: d(2026, 8, 24),
        );
        expect(errors, const <ValidationError>[term]);
      });

      test('367 days after disbursement is an error', () {
        final errors = _validate(firstDue: d(2027, 8, 27));
        expect(errors.single.field, LedgerFields.firstDueDate);
        expect(errors.single.message, contains('366 days'));
      });
    });

    group('past payments', () {
      test('each row: amount, mode, [disbursedOn, today]', () {
        final errors = _validate(
          payments: <PastPaymentInput>[
            _pay(d(2026, 8, 25), 100), // 0: on disbursedOn, ok
            _pay(_today, 100), // 1: today, ok
            _pay(d(2026, 9, 1), 0), // 2: zero amount
            PastPaymentInput(
              paidOn: d(2026, 9, 1),
              amount: const Money(-1),
              mode: PaymentMode.upi,
            ), // 3: negative
            _pay(d(2026, 9, 1), 100, mode: null), // 4: missing mode
            _pay(d(2026, 8, 24), 100), // 5: before disbursement
            _pay(_today.addDays(1), 100), // 6: future
          ],
        );
        expect(
          <String, String>{for (final e in errors) e.field: e.message},
          <String, String>{
            LedgerFields.pastPayment(2): 'Each payment must be more than ₹0.',
            LedgerFields.pastPayment(3): 'Each payment must be more than ₹0.',
            LedgerFields.pastPayment(4): 'Choose a payment mode.',
            LedgerFields.pastPayment(5):
                'A payment cannot be dated before the disbursement date.',
            LedgerFields.pastPayment(6): 'A payment cannot be in the future.',
          },
        );
      });

      test('at most 1,100 rows', () {
        final rows = List<PastPaymentInput>.filled(
          maxPastPayments,
          PastPaymentInput(
            paidOn: d(2026, 9, 1),
            amount: const Money(1),
            mode: PaymentMode.cash,
          ),
        );
        expect(_validate(payments: rows), isEmpty);
        final errors = _validate(
          payments: <PastPaymentInput>[...rows, rows[0]],
        );
        expect(errors.single.field, LedgerFields.pastPayments);
        expect(errors.single.message, contains('1,100'));
      });

      test('Σ == sanctioned is "already fully repaid"', () {
        final errors = _validate(
          payments: <PastPaymentInput>[
            _pay(d(2026, 9, 1), 60000),
            _pay(d(2026, 9, 8), 40000),
          ],
        );
        expect(errors.single.field, LedgerFields.pastPayments);
        expect(errors.single.message, contains('already fully repaid'));
      });

      test('Σ > sanctioned is an error', () {
        final errors = _validate(
          payments: <PastPaymentInput>[_pay(d(2026, 9, 1), 100001)],
        );
        expect(errors.single.field, LedgerFields.pastPayments);
        expect(errors.single.message, contains('₹1,00,000'));
      });

      test('Σ one paisa under sanctioned is allowed', () {
        expect(
          _validate(
            payments: <PastPaymentInput>[
              PastPaymentInput(
                paidOn: d(2026, 9, 1),
                amount: const Money(9999999),
                mode: PaymentMode.cash,
              ),
            ],
          ),
          isEmpty,
        );
      });

      test('total errors go on openingTotal for a spread', () {
        final errors = _validate(
          payments: <PastPaymentInput>[
            _pay(d(2026, 9, 1), 50000, opening: true),
            _pay(d(2026, 9, 8), 50000, opening: true),
          ],
        );
        expect(errors.single.field, LedgerFields.openingTotal);
        // A mix of opening and itemised rows reports on pastPayments.
        final mixed = _validate(
          payments: <PastPaymentInput>[
            _pay(d(2026, 9, 1), 50000, opening: true),
            _pay(d(2026, 9, 8), 50000),
          ],
        );
        expect(mixed.single.field, LedgerFields.pastPayments);
      });

      test('no total check when sanctioned is not positive', () {
        final errors = _validate(
          sanctioned: Money.zero,
          payments: <PastPaymentInput>[_pay(d(2026, 9, 1), 100)],
        );
        expect(errors, isEmpty);
      });
    });

    test('previousRef at most 40 characters (trimmed)', () {
      expect(_validate(previousRef: 'A' * 40), isEmpty);
      expect(_validate(previousRef: '  ${'A' * 40}  '), isEmpty);
      final errors = _validate(previousRef: 'A' * 41);
      expect(errors.single.field, LedgerFields.previousRef);
    });

    test('every failure is reported together', () {
      final errors = _validate(
        disbursedOn: _today.addDays(2),
        firstDue: _today.addDays(1),
        payments: <PastPaymentInput>[_pay(_today, 0)],
        previousRef: 'B' * 41,
      );
      expect(_fields(errors), <String>{
        LedgerFields.disbursedOn,
        LedgerFields.firstDueDate,
        LedgerFields.pastPayment(0),
        LedgerFields.previousRef,
      });
    });
  });

  group('spreadOpeningTotal', () {
    List<PastPaymentInput> spread(
      int totalRs, {
      List<PlannedInstallment>? schedule,
      CivilDate? disbursedOn,
      CivilDate? today,
    }) => spreadOpeningTotal(
      schedule: schedule ?? _runningWeekly(),
      total: rs(totalRs),
      mode: PaymentMode.bank,
      disbursedOn: disbursedOn ?? d(2026, 10, 28),
      today: today ?? _today,
    );

    test('₹0 or negative → no payments', () {
      expect(spread(0), isEmpty);
      expect(spread(-5), isEmpty);
    });

    test('exact: one payment per covered row, on its due date', () {
      final out = spread(30000);
      expect(out.map((PastPaymentInput p) => p.paidOn), <CivilDate>[
        d(2026, 11, 4),
        d(2026, 11, 11),
        d(2026, 11, 18),
      ]);
      expect(out.every((PastPaymentInput p) => p.amount == rs(10000)), isTrue);
      expect(out.every((PastPaymentInput p) => p.openingBalance), isTrue);
      expect(
        out.every((PastPaymentInput p) => p.mode == PaymentMode.bank),
        isTrue,
      );
      expect(pastPaymentsTotal(out), rs(30000));
    });

    test('partial: the last covered row takes the rest', () {
      final out = spread(25000);
      expect(out.map((PastPaymentInput p) => p.amount), <Money>[
        rs(10000),
        rs(10000),
        rs(5000),
      ]);
      expect(out.last.paidOn, d(2026, 11, 18));
    });

    test('advance: the excess is dated on the last due date, not today', () {
      final out = spread(42000);
      expect(out, hasLength(4));
      expect(out.last.amount, rs(12000));
      expect(out.last.paidOn, d(2026, 11, 18));
      expect(out.any((PastPaymentInput p) => p.paidOn == _today), isFalse);
    });

    test('no row due yet: the whole total is dated on disbursedOn', () {
      final out = spread(15000, today: d(2026, 11, 1));
      expect(out, <PastPaymentInput>[
        PastPaymentInput(
          paidOn: d(2026, 10, 28),
          amount: rs(15000),
          mode: PaymentMode.bank,
          openingBalance: true,
        ),
      ]);
    });

    test('advance is never dated before disbursedOn', () {
      // A synthetic row due before disbursement.
      final out = spread(
        150,
        schedule: <PlannedInstallment>[
          PlannedInstallment(seq: 1, dueDate: d(2026, 10, 1), amount: rs(100)),
        ],
      );
      expect(out.last.paidOn, d(2026, 10, 28));
      expect(out.last.amount, rs(50));
    });

    test('a row due today stays open: the advance is dated on the last '
        'due date before today (user decision 2026-11-26)', () {
      // Rows 4, 11, 18 Nov before today; 25 Nov is due today.
      final out = spread(40000, today: d(2026, 11, 25));
      expect(
        out.any((PastPaymentInput p) => p.paidOn == d(2026, 11, 25)),
        isFalse,
      );
      expect(out, hasLength(4));
      expect(out.last.paidOn, d(2026, 11, 18));
      expect(out.last.amount, rs(10000));
    });

    test('a loan disbursed today with an opening total dates it today', () {
      final out = spread(
        5000,
        today: d(2026, 10, 28),
        disbursedOn: d(2026, 10, 28),
      );
      expect(out.single.paidOn, d(2026, 10, 28));
    });

    test('a first row due on disbursedOn before today is covered and the '
        'advance lands on that same day', () {
      final out = spread(
        150,
        schedule: <PlannedInstallment>[
          PlannedInstallment(seq: 1, dueDate: d(2026, 10, 28), amount: rs(100)),
        ],
      );
      expect(out.map((PastPaymentInput p) => p.paidOn).toSet(), <CivilDate>{
        d(2026, 10, 28),
      });
    });

    test('whole schedule in the past, partly paid', () {
      final out = spread(
        75000,
        schedule: _pastWeekly(),
        disbursedOn: d(2026, 8, 25),
      );
      expect(out, hasLength(8));
      expect(out.first.paidOn, d(2026, 9, 1));
      expect(out.last.paidOn, d(2026, 10, 20));
      expect(out.last.amount, rs(5000));
    });

    test('rows are taken by due date, then seq, whatever the input order', () {
      final out = spread(
        150,
        schedule: <PlannedInstallment>[
          PlannedInstallment(seq: 3, dueDate: d(2026, 11, 5), amount: rs(100)),
          PlannedInstallment(seq: 2, dueDate: d(2026, 11, 1), amount: rs(70)),
          PlannedInstallment(seq: 1, dueDate: d(2026, 11, 1), amount: rs(60)),
        ],
      );
      expect(out.map((PastPaymentInput p) => (p.paidOn, p.amount)), <Object>[
        (d(2026, 11, 1), rs(60)),
        (d(2026, 11, 1), rs(70)),
        (d(2026, 11, 5), rs(20)),
      ]);
    });

    test('projection over the spread equals one payment of the total', () {
      for (final totalRs in <int>[0, 5000, 25000, 30000, 42000, 99999]) {
        final c = makeContract(
          id: 'c-$totalRs',
          firstDue: d(2026, 11, 4),
          weekday: 3,
          disbursedOn: d(2026, 10, 28),
        );
        final spreadTxs = <LedgerTransaction>[
          for (final p in spread(totalRs)) tx(c.id, p.amount, p.paidOn),
        ];
        final single = <LedgerTransaction>[
          if (totalRs > 0) tx(c.id, rs(totalRs), _today),
        ];
        final a = project(c, spreadTxs, _today);
        final b = project(c, single, _today);
        expect(a.totalPaid, b.totalPaid, reason: '$totalRs');
        expect(a.outstanding, b.outstanding);
        expect(a.overdueAmount, b.overdueAmount);
        expect(a.overdueCount, b.overdueCount);
        expect(a.maxDaysOverdue, b.maxDaysOverdue);
        expect(a.maturityDate, b.maturityDate);
        expect(
          a.rows.map((ProjectedRow r) => (r.dueDate, r.paid, r.status)),
          b.rows.map((ProjectedRow r) => (r.dueDate, r.paid, r.status)),
        );
      }
    });

    test('spread over a past schedule shows overdue rows and extensions', () {
      final c = makeContract(
        firstDue: d(2026, 9, 1),
        disbursedOn: d(2026, 8, 25),
      );
      final p = project(c, <LedgerTransaction>[
        for (final pay in spread(
          75000,
          schedule: _pastWeekly(),
          disbursedOn: d(2026, 8, 25),
        ))
          tx(c.id, pay.amount, pay.paidOn),
      ], _today);
      expect(p.totalPaid, rs(75000));
      expect(p.outstanding, rs(25000));
      expect(p.overdueAmount, rs(25000));
      expect(p.overdueCount, 3); // 20 Oct partial, 27 Oct, 3 Nov
      expect(p.maxDaysOverdue, 35); // 20 Oct → 24 Nov
      expect(p.rows.where((ProjectedRow r) => r.isExtension), isNotEmpty);
      expect(
        p.rows
            .where((ProjectedRow r) => r.isExtension)
            .every((ProjectedRow r) => !r.dueDate.isBefore(_today)),
        isTrue,
      );
    });
  });

  group('fillFromSchedule', () {
    test('one row per installment due up to the date, oldest first', () {
      final out = fillFromSchedule(
        schedule: _pastWeekly(),
        upTo: d(2026, 9, 15),
        mode: PaymentMode.upi,
      );
      expect(out, <PastPaymentInput>[
        _pay(d(2026, 9, 1), 10000, mode: PaymentMode.upi),
        _pay(d(2026, 9, 8), 10000, mode: PaymentMode.upi),
        _pay(d(2026, 9, 15), 10000, mode: PaymentMode.upi),
      ]);
    });

    test('nothing due yet → empty', () {
      expect(
        fillFromSchedule(
          schedule: _pastWeekly(),
          upTo: d(2026, 8, 31),
          mode: PaymentMode.cash,
        ),
        isEmpty,
      );
    });
  });

  group('balancedChunkSizes', () {
    test('no items → one empty first chunk', () {
      expect(balancedChunkSizes(items: 0, firstRoom: 10, laterRoom: 5), <int>[
        0,
      ]);
    });

    test('fits in the first chunk', () {
      expect(balancedChunkSizes(items: 10, firstRoom: 10, laterRoom: 5), <int>[
        10,
      ]);
    });

    test('spills into later chunks, the last one partial', () {
      expect(balancedChunkSizes(items: 21, firstRoom: 10, laterRoom: 5), <int>[
        10,
        5,
        5,
        1,
      ]);
    });

    test('a full first chunk (room 0) still exists', () {
      expect(balancedChunkSizes(items: 3, firstRoom: 0, laterRoom: 5), <int>[
        0,
        3,
      ]);
    });

    test('worst onboarding: 366 installments + 1,100 payments → 4', () {
      // 450 − (366 inst + disbursement + company + contract) = 81.
      expect(
        balancedChunkSizes(items: 1100, firstRoom: 81, laterRoom: 449),
        <int>[81, 449, 449, 121],
      );
    });

    test('bad arguments throw', () {
      expect(
        () => balancedChunkSizes(items: -1, firstRoom: 1, laterRoom: 1),
        throwsArgumentError,
      );
      expect(
        () => balancedChunkSizes(items: 1, firstRoom: -1, laterRoom: 1),
        throwsArgumentError,
      );
      expect(
        () => balancedChunkSizes(items: 1, firstRoom: 1, laterRoom: 0),
        throwsArgumentError,
      );
    });
  });
}
