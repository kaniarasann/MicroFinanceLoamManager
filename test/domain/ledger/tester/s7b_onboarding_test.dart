import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import '../ledger_fixtures.dart';

/// Sprint 7b tester: onboarding domain (Task 18) end to end in pure Dart:
/// validate → spread → project → portfolio / chart / calendar.
///
/// Scenario W ("weekly"): ₹1,00,000 at ₹10,000 weekly on Tuesdays, first
/// due Tue 15 Sep 2026 (10 weeks before today), disbursed Tue 8 Sep 2026
/// with ₹5,000 upfront. Today is Tue 24 Nov 2026, so all 10 base rows are
/// in the past (15 Sep … 17 Nov). Opening total ₹55,000, cash.

final CivilDate _today = d(2026, 11, 24);
final CivilDate _disbursed = d(2026, 9, 8);
final CivilDate _firstDue = d(2026, 9, 15);

List<PlannedInstallment> _weeklySchedule({CivilDate? firstDue}) =>
    generateSchedule(
      sanctioned: rs(100000),
      installmentAmount: rs(10000),
      frequency: Frequency.weekly,
      firstDueDate: firstDue ?? _firstDue,
      preferredWeekday: 2,
    );

Contract _weeklyContract({
  int paidRs = 55000,
  int upfrontInput = 500000,
  CivilDate? firstDue,
  CivilDate? disbursedOn,
}) =>
    makeContract(
      id: 'onb',
      loanNo: 4,
      upfrontInput: upfrontInput,
      firstDue: firstDue ?? _firstDue,
      disbursedOn: disbursedOn ?? _disbursed,
    ).copyWith(
      origin: ContractOrigin.onboarded,
      onboardedOn: _today,
      totalPaid: rs(paidRs),
    );

/// Onboarding payment txs for [inputs] (as `planOnboarding` builds them).
List<LedgerTransaction> _txs(String cid, List<PastPaymentInput> inputs) =>
    <LedgerTransaction>[
      for (var i = 0; i < inputs.length; i++)
        tx(
          cid,
          inputs[i].amount,
          inputs[i].paidOn,
          id: '$cid-p$i',
          mode: inputs[i].mode,
        ).copyWith(
          origin: TxOrigin.onboarding,
          openingBalance: inputs[i].openingBalance,
          note: inputs[i].openingBalance ? openingBalanceNote : null,
        ),
    ];

List<PastPaymentInput> _spread(int rupees, {List<PlannedInstallment>? s}) =>
    spreadOpeningTotal(
      schedule: s ?? _weeklySchedule(),
      total: rs(rupees),
      mode: PaymentMode.cash,
      disbursedOn: _disbursed,
      today: _today,
    );

PortfolioMetrics _portfolio(
  Contract c,
  List<LedgerTransaction> txs, {
  CivilDate? today,
}) {
  final on = today ?? _today;
  final disb = tx(
    c.id,
    c.netDisbursed,
    c.disbursedOn,
    type: TxType.disbursement,
    id: '${c.id}-d',
  ).copyWith(origin: TxOrigin.onboarding);
  final all = <LedgerTransaction>[disb, ...txs];
  return computePortfolio(
    projections: <ContractProjection>[project(c, all, on)],
    allTransactions: all,
    today: on,
    contractsById: <String, Contract>{c.id: c},
  );
}

List<ValidationError> _validate({
  Money? sanctioned,
  CivilDate? disbursedOn,
  CivilDate? firstDue,
  List<PastPaymentInput> payments = const <PastPaymentInput>[],
  String? previousRef,
}) => validateOnboarding(
  termErrors: const <ValidationError>[],
  sanctioned: sanctioned ?? rs(100000),
  disbursedOn: disbursedOn ?? _disbursed,
  firstDueDate: firstDue ?? _firstDue,
  today: _today,
  payments: payments,
  previousRef: previousRef,
);

Set<String> _fields(List<ValidationError> errors) =>
    errors.map((ValidationError e) => e.field).toSet();

PastPaymentInput _pay(CivilDate on, int rupees, {PaymentMode? mode}) =>
    PastPaymentInput(
      paidOn: on,
      amount: rs(rupees),
      mode: mode ?? PaymentMode.cash,
    );

void main() {
  test('W0: today is a Tuesday and the 10 rows are 15 Sep … 17 Nov', () {
    expect(_today.weekday, DateTime.tuesday);
    final s = _weeklySchedule();
    expect(s, hasLength(10));
    expect(s.first.dueDate, d(2026, 9, 15));
    expect(s.last.dueDate, d(2026, 11, 17));
    expect(_firstDue.daysBetween(_today), 70);
  });

  group('W: weekly ₹55,000 opening total', () {
    test(
      'W1 spread: rows 1–5 on their due dates + ₹5,000 partial on row 6',
      () {
        final spread = _spread(55000);
        expect(
          spread.map((PastPaymentInput p) => (p.paidOn, p.amount)),
          <(CivilDate, Money)>[
            (d(2026, 9, 15), rs(10000)),
            (d(2026, 9, 22), rs(10000)),
            (d(2026, 9, 29), rs(10000)),
            (d(2026, 10, 6), rs(10000)),
            (d(2026, 10, 13), rs(10000)),
            (d(2026, 10, 20), rs(5000)),
          ],
        );
        for (final p in spread) {
          expect(p.openingBalance, isTrue);
          expect(p.mode, PaymentMode.cash);
        }
        expect(pastPaymentsTotal(spread), rs(55000));
        expect(spread.any((PastPaymentInput p) => p.paidOn == _today), isFalse);
        expect(
          _validate(payments: spread),
          isEmpty,
          reason: 'a valid onboarding',
        );
      },
    );

    test('W2 as of today: rows 6–10 partial/overdue with days late, '
        'extensions at the end, outstanding ₹45,000', () {
      final c = _weeklyContract();
      final p = project(c, _txs('onb', _spread(55000)), _today);
      final base = p.rows.where((ProjectedRow r) => !r.isExtension).toList();
      expect(base, hasLength(10));
      for (final r in base.take(5)) {
        expect(r.status, RowStatus.paid, reason: 'row ${r.seq}');
      }
      final row6 = base[5];
      expect(row6.status, RowStatus.overdue);
      expect(row6.isPartial, isTrue);
      expect(row6.paid, rs(5000));
      expect(row6.remaining, rs(5000));
      expect(row6.daysOverdue, 35);
      expect(
        base.skip(6).map((ProjectedRow r) => (r.status, r.paid, r.daysOverdue)),
        <(RowStatus, Money, int)>[
          (RowStatus.overdue, Money.zero, 28),
          (RowStatus.overdue, Money.zero, 21),
          (RowStatus.overdue, Money.zero, 14),
          (RowStatus.overdue, Money.zero, 7),
        ],
      );
      final ext = p.rows.where((ProjectedRow r) => r.isExtension).toList();
      expect(ext, isNotEmpty);
      expect(p.rows.indexOf(ext.first), greaterThan(p.rows.indexOf(base.last)));
      for (final r in ext) {
        expect(r.dueDate.isBefore(_today), isFalse, reason: 'ext ${r.seq}');
        expect(r.dueDate.isAfter(base.last.dueDate), isTrue);
      }
      expect(Money.sum(ext.map((ProjectedRow r) => r.remaining)), rs(45000));
      expect(p.totalPaid, rs(55000));
      expect(p.outstanding, rs(45000));
      expect(p.overdueAmount, rs(45000));
      expect(p.overdueCount, 5);
      expect(p.maxDaysOverdue, 35);
    });

    test('W3 portfolio: Total collected includes ₹55,000, net ₹95,000, '
        'received today and this month unchanged', () {
      final m = _portfolio(_weeklyContract(), _txs('onb', _spread(55000)));
      expect(m.totalCollected, rs(55000));
      expect(m.totalNetDisbursed, rs(95000));
      expect(m.sanctionedReceivable, rs(45000));
      expect(m.totalOverdue, rs(45000));
      expect(m.overdueInstallmentCount, 5);
      expect(m.overdueLoanCount, 1);
      expect(m.todayDue.received, Money.zero);
      expect(m.receivableBreakdown.collectedThisMonth.amount, Money.zero);
      expect(m.overdueList.first.daysOverdue, 35);
    });

    test('W4 chart: 6M and 8W buckets hold the cash on the original dates', () {
      final m = _portfolio(_weeklyContract(), _txs('onb', _spread(55000)));
      final months = m.collectionsSeries(ChartPeriod.months6);
      Money collectedIn(int month) => months
          .firstWhere((CollectionBucket b) => b.start.month == month)
          .collected;
      expect(collectedIn(9), rs(30000));
      expect(collectedIn(10), rs(25000));
      expect(collectedIn(11), Money.zero);
      expect(months.last.isCurrent, isTrue);
      expect(months.last.collected, Money.zero);
      final sep = months.firstWhere((CollectionBucket b) => b.start.month == 9);
      expect(sep.due, rs(30000));
      expect(sep.rateBps, 10000);
      for (final b in months) {
        expect(b.rateBps, lessThanOrEqualTo(10000), reason: b.label);
      }

      final weeks = m.collectionsSeries(ChartPeriod.weeks8);
      expect(weeks.first.start, d(2026, 10, 5));
      expect(weeks.map((CollectionBucket b) => b.collected), <Money>[
        rs(10000), // 6 Oct
        rs(10000), // 13 Oct
        rs(5000), // 20 Oct
        Money.zero,
        Money.zero,
        Money.zero,
        Money.zero,
        Money.zero, // current week: nothing today
      ]);
      expect(
        SeriesTotals.of(months).collected,
        rs(55000),
        reason: 'all of the cash is inside the 6-month window',
      );
    });

    test('W5 calendar: cash lands on 15/22/29 Sep and 6/13/20 Oct', () {
      final m = _portfolio(_weeklyContract(), _txs('onb', _spread(55000)));
      final sep = m.calendarBuckets(2026, 9);
      for (final day in <int>[15, 22, 29]) {
        expect(sep[day - 1].collected, rs(10000), reason: 'Sep $day');
        expect(sep[day - 1].collectedCount, 1);
        expect(sep[day - 1].hasCollectedDot, isTrue);
      }
      expect(Money.sum(sep.map((CalendarDay x) => x.collected)), rs(30000));
      final oct = m.calendarBuckets(2026, 10);
      expect(oct[5].collected, rs(10000));
      expect(oct[12].collected, rs(10000));
      expect(oct[19].collected, rs(5000));
      expect(oct[19].settled, rs(5000));
      expect(oct[19].overdue, rs(5000));
      expect(oct[19].hasOverdueDot, isTrue);
      expect(oct[26].overdue, rs(10000));
      final nov = m.calendarBuckets(2026, 11);
      expect(
        Money.sum(nov.map((CalendarDay x) => x.collected)),
        Money.zero,
        reason: 'no cash in November',
      );
      expect(nov[16].overdue, rs(10000)); // 17 Nov, 7 days late
    });

    test('W6 the spread projects exactly like one ₹55,000 payment', () {
      final c = _weeklyContract();
      final spread = project(c, _txs('onb', _spread(55000)), _today);
      final single = project(c, <LedgerTransaction>[
        tx('onb', rs(55000), _today, id: 'one'),
      ], _today);
      expect(
        spread.rows.map(
          (ProjectedRow r) => (r.dueDate, r.paid, r.status, r.daysOverdue),
        ),
        single.rows.map(
          (ProjectedRow r) => (r.dueDate, r.paid, r.status, r.daysOverdue),
        ),
      );
      expect(spread.outstanding, single.outstanding);
    });

    test('W7 reversing one spread row (29 Sep) on its own date: outstanding '
        '+₹10,000, received today unchanged, September bucket −₹10,000', () {
      final txs = _txs('onb', _spread(55000));
      final original = txs[2];
      expect(original.paidOn, d(2026, 9, 29));
      final rev = tx(
        'onb',
        original.amount,
        original.paidOn,
        id: 'rev',
        type: TxType.reversal,
        reversesTxId: original.id,
        mode: original.mode,
      ).copyWith(origin: TxOrigin.onboarding);
      final c = _weeklyContract(paidRs: 45000);
      final m = _portfolio(c, <LedgerTransaction>[...txs, rev]);
      expect(m.sanctionedReceivable, rs(55000));
      expect(m.totalCollected, rs(45000));
      expect(m.todayDue.received, Money.zero);
      expect(m.receivableBreakdown.collectedThisMonth.amount, Money.zero);
      final sep = m
          .collectionsSeries(ChartPeriod.months6)
          .firstWhere((CollectionBucket b) => b.start.month == 9);
      expect(sep.collected, rs(20000));
      expect(m.calendarBuckets(2026, 9)[28].collected, Money.zero);
    });

    test('W8 a live ₹45,000 payment today settles it and counts today', () {
      final txs = <LedgerTransaction>[
        ..._txs('onb', _spread(55000)),
        tx('onb', rs(45000), _today, id: 'live', mode: PaymentMode.upi),
      ];
      final c = _weeklyContract(paidRs: 100000);
      final p = project(c, txs, _today);
      expect(p.isSettled, isTrue);
      expect(p.overdueAmount, Money.zero);
      expect(p.rows.where((ProjectedRow r) => r.isExtension), isEmpty);
      final m = _portfolio(c, txs);
      expect(m.todayDue.received, rs(45000));
      expect(m.totalCollected, rs(100000));
    });
  });

  group('Spread edges', () {
    test('E1 ₹0 opening total → no payments; whole schedule overdue', () {
      expect(_spread(0), isEmpty);
      final p = project(
        _weeklyContract(paidRs: 0),
        const <LedgerTransaction>[],
        _today,
      );
      expect(p.overdueCount, 10);
      expect(p.outstanding, rs(100000));
    });

    test('E2 advance beyond the dues up to today is dated on the last past '
        'due date, never today', () {
      // Wednesdays from 11 Nov: 11 Nov and 18 Nov are due by today.
      final s = generateSchedule(
        sanctioned: rs(100000),
        installmentAmount: rs(10000),
        frequency: Frequency.weekly,
        firstDueDate: d(2026, 11, 11),
        preferredWeekday: 3,
      );
      final out = spreadOpeningTotal(
        schedule: s,
        total: rs(25000),
        mode: PaymentMode.upi,
        disbursedOn: d(2026, 11, 4),
        today: _today,
      );
      expect(
        out.map((PastPaymentInput p) => (p.paidOn, p.amount)),
        <(CivilDate, Money)>[
          (d(2026, 11, 11), rs(10000)),
          (d(2026, 11, 18), rs(10000)),
          (d(2026, 11, 18), rs(5000)),
        ],
      );
    });

    test('E3 no row due yet → the whole total is dated disbursedOn', () {
      final s = generateSchedule(
        sanctioned: rs(100000),
        installmentAmount: rs(10000),
        frequency: Frequency.weekly,
        firstDueDate: d(2026, 12, 1),
        preferredWeekday: 2,
      );
      final out = spreadOpeningTotal(
        schedule: s,
        total: rs(7000),
        mode: PaymentMode.cash,
        disbursedOn: d(2026, 11, 20),
        today: _today,
      );
      expect(out.single.paidOn, d(2026, 11, 20));
      expect(out.single.amount, rs(7000));
    });

    test('E4 (design note) a row due today is covered on today, so it does '
        'reach received-today', () {
      // Tuesdays from 10 Nov: 10 Nov, 17 Nov, 24 Nov (today).
      final s = _weeklySchedule(firstDue: d(2026, 11, 10));
      final out = spreadOpeningTotal(
        schedule: s,
        total: rs(30000),
        mode: PaymentMode.cash,
        disbursedOn: d(2026, 11, 3),
        today: _today,
      );
      expect(out.last.paidOn, _today);
    });
  });

  group('Validation (each blocks the save)', () {
    test('F1 opening total == sanctioned: "already fully repaid" on '
        'openingTotal', () {
      final spread = _spread(100000);
      final e = _validate(payments: spread);
      expect(_fields(e), <String>{LedgerFields.openingTotal});
      expect(e.single.message, contains('already fully repaid'));
    });

    test('F2 total > sanctioned (itemised) on pastPayments', () {
      final e = _validate(
        payments: <PastPaymentInput>[
          _pay(d(2026, 9, 15), 60000),
          _pay(d(2026, 9, 22), 40001),
        ],
      );
      expect(_fields(e), <String>{LedgerFields.pastPayments});
      expect(e.single.message, contains('₹1,00,000'));
    });

    test('F3 payment before disbursedOn / F4 future payment, per row', () {
      final e = _validate(
        payments: <PastPaymentInput>[
          _pay(_disbursed, 100), // edge: on disbursedOn is fine
          _pay(_disbursed.addDays(-1), 100),
          _pay(_today, 100), // edge: today is fine
          _pay(_today.addDays(1), 100),
        ],
      );
      expect(_fields(e), <String>{
        LedgerFields.pastPayment(1),
        LedgerFields.pastPayment(3),
      });
    });

    test('F5 disbursedOn more than 3 years back (1096 ok, 1097 not); '
        'future disbursedOn', () {
      final ok = _today.addDays(-1096);
      expect(_validate(disbursedOn: ok, firstDue: ok.addDays(7)), isEmpty);
      final old = _today.addDays(-1097);
      expect(
        _fields(_validate(disbursedOn: old, firstDue: old.addDays(7))),
        <String>{LedgerFields.disbursedOn},
      );
      expect(
        _fields(
          _validate(
            disbursedOn: _today.addDays(1),
            firstDue: _today.addDays(8),
          ),
        ),
        <String>{LedgerFields.disbursedOn},
      );
    });

    test('F6 firstDueDate before disbursedOn or > 366 days after', () {
      expect(
        _validate(firstDue: _disbursed), // edge: same day ok
        isEmpty,
      );
      expect(_validate(firstDue: _disbursed.addDays(366)), isEmpty);
      expect(_fields(_validate(firstDue: _disbursed.addDays(-1))), <String>{
        LedgerFields.firstDueDate,
      });
      expect(_fields(_validate(firstDue: _disbursed.addDays(367))), <String>{
        LedgerFields.firstDueDate,
      });
    });

    test('F7 a missing mode', () {
      final e = _validate(
        payments: <PastPaymentInput>[
          PastPaymentInput(paidOn: _firstDue, amount: rs(100), mode: null),
        ],
      );
      expect(e.single.field, LedgerFields.pastPayment(0));
      expect(e.single.message, 'Choose a payment mode.');
    });

    test('F8 previousRef longer than 40 characters (40 ok, trimmed)', () {
      expect(_validate(previousRef: 'x' * 40), isEmpty);
      expect(_validate(previousRef: '  ${'x' * 40}  '), isEmpty);
      expect(_fields(_validate(previousRef: 'x' * 41)), <String>{
        LedgerFields.previousRef,
      });
    });

    test('F9 1,101 itemised payments (1,100 ok)', () {
      List<PastPaymentInput> n(int count) => <PastPaymentInput>[
        for (var i = 0; i < count; i++)
          _pay(_disbursed.addDays(1 + i % 70), 10),
      ];
      expect(_validate(payments: n(1100)), isEmpty);
      final e = _validate(payments: n(1101));
      expect(_fields(e), <String>{LedgerFields.pastPayments});
      expect(e.single.message, contains('1,100'));
    });

    test('F10 a zero amount row', () {
      final e = _validate(payments: <PastPaymentInput>[_pay(_firstDue, 0)]);
      expect(e.single.field, LedgerFields.pastPayment(0));
    });
  });

  test('U1 upfront ₹0 is allowed: net disbursed = sanctioned', () {
    final c = _weeklyContract(upfrontInput: 0);
    expect(c.upfront, Money.zero);
    expect(c.netDisbursed, rs(100000));
    expect(
      validateContractTerms(
        sanctioned: c.sanctioned,
        upfrontMode: UpfrontMode.flat,
        upfrontInput: 0,
        installmentAmount: c.installmentAmount,
        frequency: Frequency.weekly,
        preferredWeekday: 2,
        firstDueDate: c.firstDueDate,
        disbursedOn: c.disbursedOn,
      ),
      isEmpty,
    );
    expect(
      _portfolio(c, const <LedgerTransaction>[]).totalNetDisbursed,
      rs(100000),
    );
  });

  group('Chunk planner', () {
    test('C1 daily 366 rows: 300 → [81, 219]; 1,100 → [81, 449, 449, 121]; '
        '6 → [6]; 0 → [0]', () {
      // 450 − (contract + 366 rows + disbursement + company).
      const first = 450 - 369;
      expect(
        balancedChunkSizes(items: 300, firstRoom: first, laterRoom: 449),
        <int>[81, 219],
      );
      expect(
        balancedChunkSizes(items: 1100, firstRoom: first, laterRoom: 449),
        <int>[81, 449, 449, 121],
      );
      expect(
        balancedChunkSizes(items: 6, firstRoom: 450 - 13, laterRoom: 449),
        <int>[6],
      );
      expect(
        balancedChunkSizes(items: 0, firstRoom: first, laterRoom: 449),
        <int>[0],
      );
    });
  });
}
