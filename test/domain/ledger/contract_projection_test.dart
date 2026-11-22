import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import 'ledger_fixtures.dart';

/// Stitch contract: ₹1,00,000, 10 weekly ₹10,000 on Tuesdays from
/// Tue 31 Oct 2023 (1: 31 Oct, 4: 21 Nov, 5: 28 Nov, 10: 2 Jan 2024).
final Contract stitch = makeContract();

List<LedgerTransaction> _pays(
  List<(int, CivilDate)> list, [
  String id = 'c1',
]) => <LedgerTransaction>[for (final (r, on) in list) tx(id, rs(r), on)];

List<LedgerTransaction> get _first3Plus6k => _pays(<(int, CivilDate)>[
  (10000, d(2023, 10, 31)),
  (10000, d(2023, 11, 7)),
  (10000, d(2023, 11, 14)),
  (6000, d(2023, 11, 21)),
]);

ProjectedRow _row(ContractProjection p, int seq) =>
    p.rows.firstWhere((ProjectedRow r) => r.seq == seq);

void main() {
  group('paid pool', () {
    test(
      'Σ payment + settlement − reversal; ignores other types/contracts',
      () {
        final pool = paidPool('c1', <LedgerTransaction>[
          tx('c1', rs(10000), d(2023, 10, 31)),
          tx('c1', rs(5000), d(2023, 11, 1), type: TxType.rolloverSettlement),
          tx('c1', rs(2000), d(2023, 11, 2), type: TxType.reversal),
          tx('c1', rs(93000), d(2023, 10, 24), type: TxType.disbursement),
          tx('c1', Money.zero, d(2023, 11, 3), type: TxType.reschedule),
          tx('other', rs(99999), d(2023, 11, 3)),
        ]);
        expect(pool, rs(13000));
      },
    );
  });

  group('FIFO allocation', () {
    test('no payments, before first due → all planned/upcoming', () {
      final p = project(stitch, const <LedgerTransaction>[], d(2023, 10, 25));
      expect(p.totalPaid, Money.zero);
      expect(p.outstanding, rs(100000));
      expect(_row(p, 1).status, RowStatus.upcoming); // 6 days ahead
      expect(_row(p, 2).status, RowStatus.planned); // 13 days ahead
      expect(p.overdueAmount, Money.zero);
      expect(p.extensionRows, isEmpty);
      expect(p.nextDue!.seq, 1);
      expect(p.cyclesTotal, 10);
      expect(p.cyclesPaid, 0);
      expect(p.maturityDate, d(2024, 1, 2));
      expect(p.clearedBps, 0);
    });

    test('upcoming boundary: exactly 7 days ahead is upcoming, 8 planned', () {
      final p = project(stitch, const <LedgerTransaction>[], d(2023, 10, 24));
      expect(_row(p, 1).status, RowStatus.upcoming); // 7
      final q = project(stitch, const <LedgerTransaction>[], d(2023, 10, 23));
      expect(_row(q, 1).status, RowStatus.planned); // 8
    });

    test('exact payments → paid rows, nothing overdue', () {
      final p = project(
        stitch,
        _pays(<(int, CivilDate)>[
          (10000, d(2023, 10, 31)),
          (10000, d(2023, 11, 7)),
          (10000, d(2023, 11, 14)),
        ]),
        d(2023, 11, 15),
      );
      expect(<RowStatus>[
        for (var i = 1; i <= 3; i++) _row(p, i).status,
      ], everyElement(RowStatus.paid));
      expect(_row(p, 4).status, RowStatus.upcoming);
      expect(p.overdueAmount, Money.zero);
      expect(p.overdueCount, 0);
      expect(p.cyclesPaid, 3);
      expect(p.nextDue!.seq, 4);
      expect(p.outstanding, rs(70000));
      expect(p.clearedBps, 3000);
      expect(p.isSettled, isFalse);
      expect(p.hasOverdue, isFalse);
    });

    test('partial ₹6,000 of ₹10,000 → partial + overdue, ext ₹4,000', () {
      final pays = _pays(<(int, CivilDate)>[
        (10000, d(2023, 10, 31)),
        (10000, d(2023, 11, 7)),
        (10000, d(2023, 11, 14)),
        (6000, d(2023, 11, 21)),
      ]);
      // On the due date itself: dueToday, partial, not overdue.
      final onDay = project(stitch, pays, d(2023, 11, 21));
      final r4 = _row(onDay, 4);
      expect(r4.status, RowStatus.dueToday);
      expect(r4.isPartial, isTrue);
      expect(r4.paid, rs(6000));
      expect(onDay.extensionRows, isEmpty);

      // The day after: overdue partial, extension ₹4,000.
      final p = project(stitch, pays, d(2023, 11, 22));
      final r = _row(p, 4);
      expect(r.status, RowStatus.overdue);
      expect(r.isPartial, isTrue);
      expect(r.daysOverdue, 1);
      expect(r.remaining, rs(4000));
      expect(p.overdueAmount, rs(4000));
      final ext = p.extensionRows.single;
      expect(ext.due, rs(4000));
      expect(ext.seq, 11);
      expect(ext.isExtension, isTrue);
      expect(ext.installmentId, isNull);
      expect(ext.kind, isNull);
      expect(ext.dueDate, d(2024, 1, 9));
      expect(ext.sourceLabel, 'partial on 21 Nov (Inst. 4)');
      expect(ext.status, RowStatus.planned);
      expect(p.cyclesTotal, 11);
      expect(p.maturityDate, d(2024, 1, 9));
      expect(p.nextDue!.seq, 4);
    });

    test('missed installment → overdue 5 days, ext ₹10,000 "missed on"', () {
      final pays = _pays(<(int, CivilDate)>[
        (10000, d(2023, 10, 31)),
        (10000, d(2023, 11, 7)),
        (10000, d(2023, 11, 14)),
        (10000, d(2023, 11, 21)),
      ]);
      final p = project(stitch, pays, d(2023, 12, 3));
      final r5 = _row(p, 5);
      expect(r5.status, RowStatus.overdue);
      expect(r5.isPartial, isFalse);
      expect(r5.paid, Money.zero);
      expect(r5.daysOverdue, 5);
      expect(p.maxDaysOverdue, 5);
      expect(p.overdueCount, 1);
      final ext = p.extensionRows.single;
      expect(ext.due, rs(10000));
      expect(ext.sourceLabel, 'missed on 28 Nov (Inst. 5)');
      expect(ext.sources.single.amount, rs(10000));
      expect(ext.sources.single.wasPartial, isFalse);
      expect(_row(p, 6).status, RowStatus.upcoming);
    });

    test('two shortfalls → two extensions, tail attributed to earliest', () {
      final p = project(
        stitch,
        _pays(<(int, CivilDate)>[(10000, d(2023, 10, 31))]),
        d(2023, 11, 15),
      );
      expect(p.overdueCount, 2);
      expect(p.overdueAmount, rs(20000));
      expect(p.maxDaysOverdue, 8); // Inst 2, 7 Nov
      final ext = p.extensionRows.toList();
      expect(ext.map((ProjectedRow r) => r.seq), <int>[11, 12]);
      expect(ext.map((ProjectedRow r) => r.dueDate), <CivilDate>[
        d(2024, 1, 9),
        d(2024, 1, 16),
      ]);
      // Later shortfall first; the tail row (cleared first by a late FIFO
      // payment) carries the earliest shortfall.
      expect(ext[0].sourceLabel, 'missed on 14 Nov (Inst. 3)');
      expect(ext[1].sourceLabel, 'missed on 7 Nov (Inst. 2)');
    });

    test(
      'an extension row can carry several sources (chronological label)',
      () {
        // ₹1,00,000 at ₹30,000 → 30k, 30k, 30k, 10k (weekly Tue).
        final c = makeContract(installment: rs(30000));
        final p = project(
          c,
          _pays(<(int, CivilDate)>[(35000, d(2023, 10, 31))]),
          d(2023, 11, 22),
        );
        // Inst 2 short 25k (partial), 3 short 30k, 4 short 10k → S = 65k.
        expect(p.overdueAmount, rs(65000));
        final ext = p.extensionRows.toList();
        expect(ext.map((ProjectedRow r) => r.due), <Money>[
          rs(30000),
          rs(30000),
          rs(5000),
        ]);
        expect(
          ext[0].sourceLabel,
          'missed on 14 Nov (Inst. 3) + missed on 21 Nov (Inst. 4)',
        );
        expect(ext[0].sources.map((ExtensionSource s) => s.amount), <Money>[
          rs(20000),
          rs(10000),
        ]);
        expect(
          ext[1].sourceLabel,
          'partial on 7 Nov (Inst. 2) + missed on 14 Nov (Inst. 3)',
        );
        expect(ext[2].sourceLabel, 'partial on 7 Nov (Inst. 2)');
        expect(ext[2].sources.single.amount, rs(5000));
        // Extensions after 21 Nov, weekly Tue.
        expect(ext.first.dueDate, d(2023, 11, 28));
        expect(ext.first.status, RowStatus.upcoming);
      },
    );

    test('advance payment covers the next 2 installments', () {
      final p = project(
        stitch,
        _pays(<(int, CivilDate)>[(30000, d(2023, 10, 31))]),
        d(2023, 10, 31),
      );
      expect(_row(p, 1).status, RowStatus.paid);
      expect(_row(p, 2).status, RowStatus.paid);
      expect(_row(p, 3).status, RowStatus.paid);
      expect(_row(p, 4).status, RowStatus.planned);
      expect(p.cyclesPaid, 3);
      expect(p.nextDue!.seq, 4);
      expect(p.nextDue!.dueDate, d(2023, 11, 21));
    });

    test('advance partial on a future row is flagged partial, not overdue', () {
      final p = project(
        stitch,
        _pays(<(int, CivilDate)>[(15000, d(2023, 10, 31))]),
        d(2023, 11, 1),
      );
      final r2 = _row(p, 2);
      expect(r2.status, RowStatus.upcoming);
      expect(r2.isPartial, isTrue);
      expect(r2.daysOverdue, 0);
      expect(p.overdueAmount, Money.zero);
    });

    test('late payment that clears the shortfall → extension disappears', () {
      final before = project(stitch, _first3Plus6k, d(2023, 12, 3));
      expect(before.extensionRows, hasLength(2));
      final after = project(stitch, <LedgerTransaction>[
        ..._first3Plus6k,
        tx('c1', rs(14000), d(2023, 12, 3)),
      ], d(2023, 12, 3));
      expect(after.extensionRows, isEmpty);
      expect(after.overdueAmount, Money.zero);
      expect(after.cyclesTotal, 10);
      expect(after.maturityDate, d(2024, 1, 2));
      expect(_row(after, 4).status, RowStatus.paid);
      expect(_row(after, 5).status, RowStatus.paid);
    });

    test('partial late payment → extension shrinks, labels stay stable', () {
      final p1 = project(stitch, <LedgerTransaction>[
        ..._first3Plus6k,
        tx('c1', rs(4000), d(2023, 12, 3)),
      ], d(2023, 12, 3));
      final e1 = p1.extensionRows.single;
      expect(e1.due, rs(10000));
      expect(e1.sourceLabel, 'missed on 28 Nov (Inst. 5)');

      final p2 = project(stitch, <LedgerTransaction>[
        ..._first3Plus6k,
        tx('c1', rs(3000), d(2023, 12, 3)),
      ], d(2023, 12, 3));
      final e2 = p2.extensionRows.toList();
      expect(e2.map((ProjectedRow r) => r.due), <Money>[rs(10000), rs(1000)]);
      expect(e2[0].sourceLabel, 'missed on 28 Nov (Inst. 5)');
      expect(e2[1].sourceLabel, 'partial on 21 Nov (Inst. 4)');

      final p3 = project(stitch, <LedgerTransaction>[
        ..._first3Plus6k,
        tx('c1', rs(9000), d(2023, 12, 3)),
      ], d(2023, 12, 3));
      final e3 = p3.extensionRows.single;
      expect(e3.due, rs(5000));
      expect(e3.sourceLabel, 'partial on 28 Nov (Inst. 5)');
    });

    test('due today stays dueToday until the day ends', () {
      final pays = _pays(<(int, CivilDate)>[(10000, d(2023, 10, 31))]);
      final today = project(stitch, pays, d(2023, 11, 7));
      expect(_row(today, 2).status, RowStatus.dueToday);
      expect(_row(today, 2).daysOverdue, 0);
      expect(today.overdueAmount, Money.zero);
      expect(today.extensionRows, isEmpty);
      final tomorrow = project(stitch, pays, d(2023, 11, 8));
      expect(_row(tomorrow, 2).status, RowStatus.overdue);
      expect(_row(tomorrow, 2).daysOverdue, 1);
    });

    test('paid wins over overdue/dueToday when fully covered', () {
      final p = project(
        stitch,
        _pays(<(int, CivilDate)>[(20000, d(2023, 11, 7))]),
        d(2023, 11, 7),
      );
      expect(_row(p, 1).status, RowStatus.paid);
      expect(_row(p, 2).status, RowStatus.paid);
    });
  });

  group('Stitch reproduction', () {
    test('inst 4 paid ₹6,000, inst 5 missed → inst 11/12 extensions', () {
      final p = project(stitch, _first3Plus6k, d(2023, 12, 3));
      expect(p.totalPaid, rs(36000));
      expect(p.outstanding, rs(64000));
      expect(p.overdueAmount, rs(14000));
      expect(p.overdueCount, 2);
      expect(p.maxDaysOverdue, 12);
      expect(_row(p, 4).status, RowStatus.overdue);
      expect(_row(p, 4).isPartial, isTrue);
      expect(_row(p, 5).daysOverdue, 5);

      final ext = p.extensionRows.toList();
      expect(ext, hasLength(2));
      expect(ext[0].seq, 11);
      expect(ext[0].due, rs(10000));
      expect(ext[0].sourceLabel, 'missed on 28 Nov (Inst. 5)');
      expect(ext[0].dueDate, d(2024, 1, 9));
      expect(ext[1].seq, 12);
      expect(ext[1].due, rs(4000));
      expect(ext[1].sourceLabel, 'partial on 21 Nov (Inst. 4)');
      expect(ext[1].dueDate, d(2024, 1, 16));
      expect(p.cyclesTotal, 12);
      expect(p.cyclesPaid, 3);
      expect(p.maturityDate, d(2024, 1, 16));
      expect(p.nextDue!.seq, 4);
      expect(p.clearedBps, 3600);
      // Rows are effective rows then extensions.
      expect(p.rows.map((ProjectedRow r) => r.seq), <int>[
        for (var i = 1; i <= 12; i++) i,
      ]);
      expect(_row(p, 1).toString(), contains('paid'));
      expect(ext[0].toString(), contains('ext'));
    });
  });

  group('reschedule', () {
    test('full reschedule of inst 5 → 0-due row, new row by date', () {
      final base = scheduleFor(stitch);
      final rows = <Installment>[
        for (final i in base)
          if (i.seq == 5)
            i.copyWith(
              rescheduledOut: rs(10000),
              rescheduledToIds: <String>['c1-i11'],
            )
          else
            i,
        installment(
          stitch,
          11,
          d(2023, 12, 8),
          rs(10000),
          kind: InstallmentKind.rescheduled,
          rescheduledFromId: 'c1-i5',
        ),
      ];
      final pays = _pays(<(int, CivilDate)>[(40000, d(2023, 11, 21))]);
      final p = project(stitch, pays, d(2023, 12, 6), installments: rows);

      final r5 = _row(p, 5);
      expect(r5.status, RowStatus.rescheduled);
      expect(r5.isRescheduledAway, isTrue);
      expect(r5.due, Money.zero);
      expect(r5.scheduledAmount, rs(10000));
      expect(r5.rescheduledOut, rs(10000));
      expect(r5.countsAsCycle, isFalse);
      expect(r5.isOpen, isFalse);

      // Inst 6 (5 Dec) missed: the only shortfall; no double counting.
      expect(_row(p, 6).status, RowStatus.overdue);
      expect(p.overdueAmount, rs(10000));
      expect(p.overdueCount, 1);
      final r11 = _row(p, 11);
      expect(r11.kind, InstallmentKind.rescheduled);
      expect(r11.rescheduledFromId, 'c1-i5');
      expect(r11.status, RowStatus.upcoming);

      final ext = p.extensionRows.single;
      expect(ext.seq, 12);
      expect(ext.due, rs(10000));
      expect(ext.sourceLabel, 'missed on 5 Dec (Inst. 6)');
      expect(ext.dueDate, d(2024, 1, 9));
      // 10 base − 1 rescheduled-away + 1 rescheduled + 1 extension.
      expect(p.cyclesTotal, 11);
      // Order: … 6 (5 Dec), 11 (8 Dec), 7 (12 Dec) …
      final order = p.rows.map((ProjectedRow r) => r.seq).toList();
      expect(order.indexOf(11), order.indexOf(6) + 1);
      expect(order.indexOf(7), order.indexOf(11) + 1);

      // ₹20,000 more: allocated to 6 then 11 (date order), not 7.
      final q = project(
        stitch,
        <LedgerTransaction>[...pays, tx('c1', rs(20000), d(2023, 12, 6))],
        d(2023, 12, 6),
        installments: rows,
      );
      expect(_row(q, 6).status, RowStatus.paid);
      expect(_row(q, 11).status, RowStatus.paid);
      expect(_row(q, 7).paid, Money.zero);
      expect(q.extensionRows, isEmpty);
      expect(q.outstanding, rs(40000));
      expect(q.cyclesTotal, 10);
    });

    test('partial reschedule: source keeps the rest', () {
      final base = scheduleFor(stitch);
      final rows = <Installment>[
        for (final i in base)
          if (i.seq == 5) i.copyWith(rescheduledOut: rs(4000)) else i,
        installment(
          stitch,
          11,
          d(2024, 1, 5),
          rs(4000),
          kind: InstallmentKind.rescheduled,
        ),
      ];
      final p = project(
        stitch,
        _pays(<(int, CivilDate)>[(40000, d(2023, 11, 21))]),
        d(2023, 11, 30),
        installments: rows,
      );
      final r5 = _row(p, 5);
      expect(r5.due, rs(6000));
      expect(r5.status, RowStatus.overdue);
      expect(p.overdueAmount, rs(6000));
      final ext = p.extensionRows.single;
      expect(ext.due, rs(6000));
      // After the last effective row (rescheduled Fri 5 Jan) → next Tue.
      expect(ext.dueDate, d(2024, 1, 9));
      expect(p.maturityDate, d(2024, 1, 9));
    });

    test('rescheduled-out beyond amountDue clamps to 0', () {
      final rows = <Installment>[
        for (final i in scheduleFor(stitch))
          if (i.seq == 10) i.copyWith(rescheduledOut: rs(20000)) else i,
      ];
      final p = project(
        stitch,
        const <LedgerTransaction>[],
        d(2023, 10, 1),
        installments: rows,
      );
      expect(_row(p, 10).due, Money.zero);
      expect(p.maturityDate, d(2023, 12, 26));
    });
  });

  group('reversal and excess', () {
    test('reversal reduces P and reopens a settled contract', () {
      final pays = <LedgerTransaction>[
        for (var i = 0; i < 10; i++)
          tx('c1', rs(10000), d(2023, 10, 31).addDays(7 * i), id: 'p$i'),
      ];
      final settled = project(stitch, pays, d(2024, 1, 3));
      expect(settled.isSettled, isTrue);
      expect(settled.outstanding, Money.zero);
      expect(settled.nextDue, isNull);
      expect(settled.clearedBps, 10000);
      expect(settled.cyclesPaid, 10);

      final reopened = project(stitch, <LedgerTransaction>[
        ...pays,
        tx(
          'c1',
          rs(10000),
          d(2024, 1, 3),
          type: TxType.reversal,
          reversesTxId: 'p9',
        ),
      ], d(2024, 1, 3));
      expect(reopened.totalPaid, rs(90000));
      expect(reopened.outstanding, rs(10000));
      expect(reopened.isSettled, isFalse);
      // Inst 10 (2 Jan) now overdue → extension.
      expect(_row(reopened, 10).status, RowStatus.overdue);
      expect(reopened.extensionRows.single.due, rs(10000));
    });

    test('two concurrent ₹10,000 payments on the last ₹10,000 → excess', () {
      final pays = <LedgerTransaction>[
        tx('c1', rs(90000), d(2023, 12, 26)),
        tx('c1', rs(10000), d(2024, 1, 2)),
        tx('c1', rs(10000), d(2024, 1, 2)),
      ];
      final p = project(stitch, pays, d(2024, 1, 2));
      expect(p.totalPaid, rs(110000));
      expect(p.outstanding, Money.zero);
      expect(p.excess, rs(10000));
      expect(p.hasExcess, isTrue);
      expect(p.isSettled, isTrue);
      expect(p.clearedBps, 10000);
      expect(p.extensionRows, isEmpty);
    });

    test('payment after a rollover settlement → excess', () {
      final c = makeContract(status: ContractStatus.rolledOver);
      final p = project(c, <LedgerTransaction>[
        tx('c1', rs(60000), d(2023, 12, 5)),
        tx('c1', rs(40000), d(2023, 12, 6), type: TxType.rolloverSettlement),
        tx('c1', rs(10000), d(2023, 12, 12)),
      ], d(2023, 12, 13));
      expect(p.outstanding, Money.zero);
      expect(p.excess, rs(10000));
      expect(p.overdueAmount, Money.zero);
      expect(p.contract.status, ContractStatus.rolledOver);
    });

    test('closed contract with exact payment: settled, no excess', () {
      final c = makeContract(status: ContractStatus.closed);
      final p = project(c, <LedgerTransaction>[
        tx('c1', rs(100000), d(2023, 11, 1)),
      ], d(2024, 3, 1));
      expect(p.isSettled, isTrue);
      expect(p.excess, Money.zero);
      expect(p.overdueRows, isEmpty);
    });
  });

  group('extension dating and edge cases', () {
    test('extensions roll forward so they are never overdue', () {
      final c = makeContract(
        sanctioned: rs(30000),
        installment: rs(1000),
        frequency: Frequency.daily,
        weekday: null,
        firstDue: d(2024, 1, 1),
      );
      final p = project(c, const <LedgerTransaction>[], d(2024, 2, 15));
      expect(p.overdueAmount, rs(30000));
      final ext = p.extensionRows.toList();
      expect(ext, hasLength(30));
      expect(ext.first.dueDate, d(2024, 2, 15));
      expect(ext.first.status, RowStatus.dueToday);
      expect(ext[1].status, RowStatus.upcoming);
      expect(ext.last.status, RowStatus.planned);
      expect(
        ext.every((ProjectedRow r) => r.status != RowStatus.overdue),
        isTrue,
      );
      expect(p.maturityDate, d(2024, 3, 15));
    });

    test('monthly 31st extension clamps across February', () {
      final c = makeContract(
        sanctioned: rs(20000),
        installment: rs(10000),
        frequency: Frequency.monthly,
        weekday: null,
        monthDay: 31,
        firstDue: d(2023, 12, 31),
      );
      final p = project(c, <LedgerTransaction>[
        tx('c1', rs(10000), d(2023, 12, 31)),
      ], d(2024, 2, 1));
      // Rows: 31 Dec (paid), 31 Jan (missed) → extension 29 Feb 2024.
      final ext = p.extensionRows.single;
      expect(ext.dueDate, d(2024, 2, 29));
      expect(ext.sourceLabel, 'missed on 31 Jan (Inst. 2)');
    });

    test('1-paise remainder: last extension takes the remainder', () {
      final c = makeContract(sanctioned: const Money(10000001));
      final p = project(c, const <LedgerTransaction>[], d(2024, 1, 10));
      expect(p.cyclesTotal, 11 + 11);
      expect(p.overdueAmount, const Money(10000001));
      expect(p.extensionRows.last.due, const Money(1));
      expect(p.extensionRows.last.sourceLabel, startsWith('missed on'));
    });

    test('ignores installments/transactions of other contracts', () {
      final other = makeContract(id: 'c2');
      final p = projectContract(
        contract: stitch,
        installments: <Installment>[
          ...scheduleFor(stitch),
          ...scheduleFor(other),
        ],
        transactions: <LedgerTransaction>[tx('c2', rs(50000), d(2023, 11, 1))],
        today: d(2023, 10, 30),
      );
      expect(p.rows, hasLength(10));
      expect(p.totalPaid, Money.zero);
    });

    test('no installments → maturity falls back to firstDueDate', () {
      final p = projectContract(
        contract: stitch,
        installments: const <Installment>[],
        transactions: const <LedgerTransaction>[],
        today: d(2023, 10, 30),
      );
      expect(p.rows, isEmpty);
      expect(p.maturityDate, stitch.firstDueDate);
      expect(p.nextDue, isNull);
      expect(p.cyclesTotal, 0);
    });

    test('zero installment amount → no extensions (guard)', () {
      final c = makeContract(installment: Money.zero);
      final p = projectContract(
        contract: c,
        installments: <Installment>[
          installment(c, 1, d(2023, 10, 31), rs(100000)),
        ],
        transactions: const <LedgerTransaction>[],
        today: d(2023, 11, 5),
      );
      expect(p.overdueAmount, rs(100000));
      expect(p.extensionRows, isEmpty);
    });

    test('zero sanctioned → clearedBps 0', () {
      final c = makeContract(sanctioned: Money.zero, upfrontInput: 0);
      final p = projectContract(
        contract: c,
        installments: const <Installment>[],
        transactions: <LedgerTransaction>[tx('c1', rs(10), d(2023, 11, 1))],
        today: d(2023, 11, 5),
      );
      expect(p.clearedBps, 0);
      expect(p.excess, rs(10));
    });

    test('negative pool (bad data) allocates nothing', () {
      final p = project(stitch, <LedgerTransaction>[
        tx('c1', rs(5000), d(2023, 11, 1), type: TxType.reversal),
      ], d(2023, 10, 30));
      expect(p.totalPaid, rs(-5000));
      expect(p.rows.every((ProjectedRow r) => r.paid.isZero), isTrue);
      expect(p.clearedBps, 0);
    });

    test('deterministic: same inputs → same output', () {
      final a = project(stitch, _first3Plus6k, d(2023, 12, 3));
      final b = project(
        stitch,
        _first3Plus6k.reversed.toList(),
        d(2023, 12, 3),
      );
      expect(
        a.rows.map((ProjectedRow r) => r.toString()).toList(),
        b.rows.map((ProjectedRow r) => r.toString()).toList(),
      );
      expect(
        a.extensionRows.map((ProjectedRow r) => r.sourceLabel).toList(),
        b.extensionRows.map((ProjectedRow r) => r.sourceLabel).toList(),
      );
    });

    test('regular rows have no sourceLabel', () {
      final p = project(stitch, const <LedgerTransaction>[], d(2023, 10, 30));
      expect(p.rows.first.sourceLabel, isNull);
      expect(p.rows.first.sources, isEmpty);
    });
  });
}
