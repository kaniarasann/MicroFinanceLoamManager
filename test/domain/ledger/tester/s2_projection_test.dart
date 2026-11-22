// Tester (Sprint 2): FIFO projection, overdue, auto-extension, reschedule.
// Base contract: 1L at 10k weekly Tue from 31 Oct 2023 (10 rows, last 2 Jan).
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import '../ledger_fixtures.dart';

List<ProjectedRow> ext(ContractProjection p) =>
    p.rows.where((r) => r.isExtension).toList();

void main() {
  final c = makeContract();

  test('due today is not overdue and creates no extension', () {
    final p = project(c, [], d(2023, 10, 31));
    expect(p.rows.first.status, RowStatus.dueToday);
    expect(p.overdueCount, 0);
    expect(p.overdueAmount, Money.zero);
    expect(ext(p), isEmpty);
  });

  test('partial 6k of 10k -> overdue partial + one 4k extension a week '
      'after the last due, labelled', () {
    final p = project(c, [tx('c1', rs(6000), d(2023, 10, 31))], d(2023, 11, 1));
    final r1 = p.rows.first;
    expect(r1.status, RowStatus.overdue);
    expect(r1.isPartial, isTrue);
    expect(r1.daysOverdue, 1);
    expect(r1.remaining, rs(4000));
    final e = ext(p);
    expect(e, hasLength(1));
    expect(e.single.due, rs(4000));
    expect(e.single.dueDate, d(2024, 1, 9));
    expect(e.single.seq, 11);
    expect(e.single.sourceLabel, 'partial on 31 Oct (Inst. 1)');
    expect(p.maturityDate, d(2024, 1, 9));
    expect(p.cyclesTotal, 11);
    // Receivable is sanctioned - paid; extension is not new debt.
    expect(p.outstanding, rs(94000));
  });

  test('two missed weeks -> two 10k extensions, labels latest-first', () {
    final p = project(c, [], d(2023, 11, 8));
    expect(p.overdueCount, 2);
    expect(p.overdueAmount, rs(20000));
    expect(p.maxDaysOverdue, 8);
    final e = ext(p);
    expect(e.map((r) => r.due).toList(), [rs(10000), rs(10000)]);
    expect(e.map((r) => r.dueDate).toList(), [d(2024, 1, 9), d(2024, 1, 16)]);
    expect(e[0].sourceLabel, 'missed on 7 Nov (Inst. 2)');
    expect(e[1].sourceLabel, 'missed on 31 Oct (Inst. 1)');
    expect(p.outstanding, rs(100000));
  });

  test('late payment of the 4k shortfall removes the extension', () {
    final p = project(c, [
      tx('c1', rs(6000), d(2023, 10, 31)),
      tx('c1', rs(4000), d(2023, 11, 3)),
    ], d(2023, 11, 3));
    expect(p.rows.first.status, RowStatus.paid);
    expect(ext(p), isEmpty);
    expect(p.maturityDate, d(2024, 1, 2));
    expect(p.cyclesTotal, 10);
  });

  test('late partial payment shrinks the extension', () {
    final p = project(c, [
      tx('c1', rs(6000), d(2023, 10, 31)),
      tx('c1', rs(2500), d(2023, 11, 3)),
    ], d(2023, 11, 3));
    expect(ext(p).single.due, rs(1500));
  });

  test('advance 30k on day one pays three rows; next due is row 4', () {
    final p = project(c, [
      tx('c1', rs(30000), d(2023, 10, 31)),
    ], d(2023, 10, 31));
    expect(p.rows.take(3).every((r) => r.status == RowStatus.paid), isTrue);
    expect(p.nextDue?.seq, 4);
    expect(p.overdueCount, 0);
    expect(ext(p), isEmpty);
    expect(p.cyclesPaid, 3);
  });

  test(
    'reschedule: moved amount excluded from extension (no double count)',
    () {
      final base = scheduleFor(c);
      final i1 = base.first;
      final moved = installment(
        c,
        11,
        d(2023, 11, 15),
        rs(10000),
        kind: InstallmentKind.rescheduled,
        rescheduledFromId: i1.id,
      );
      final list = [
        installment(c, 1, i1.dueDate, i1.amountDue, rescheduledOut: rs(10000)),
        ...base.skip(1),
        moved,
      ];
      final p = project(c, [], d(2023, 11, 8), installments: list);
      expect(
        p.rows.firstWhere((r) => r.seq == 1).status,
        RowStatus.rescheduled,
      );
      // Only Inst. 2 (7 Nov) is overdue; Inst. 1 was moved to 15 Nov.
      expect(p.overdueCount, 1);
      expect(p.overdueAmount, rs(10000));
      final e = ext(p);
      expect(e.single.due, rs(10000));
      expect(e.single.seq, 12);
      final nonExt = p.rows.where((r) => !r.isExtension);
      expect(Money.sum(nonExt.map((r) => r.due)), rs(100000));
      expect(p.outstanding, rs(100000));
    },
  );

  test('reversal reopens a settled contract', () {
    final pay = tx('c1', rs(100000), d(2023, 10, 31), id: 'p1');
    final settled = project(c, [pay], d(2023, 10, 31));
    expect(settled.isSettled, isTrue);
    final p = project(c, [
      pay,
      tx(
        'c1',
        rs(10000),
        d(2023, 11, 1),
        type: TxType.reversal,
        reversesTxId: 'p1',
      ),
    ], d(2023, 11, 1));
    expect(p.isSettled, isFalse);
    expect(p.outstanding, rs(10000));
    expect(p.totalPaid, rs(90000));
  });

  test('transactions for other contracts are ignored', () {
    final p = project(c, [
      tx('other', rs(50000), d(2023, 10, 31)),
    ], d(2023, 10, 31));
    expect(p.totalPaid, Money.zero);
  });
}
