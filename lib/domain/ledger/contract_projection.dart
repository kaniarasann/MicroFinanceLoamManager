import '../../core/money/money.dart';
import '../../core/time/civil_date.dart';
import '../models/contract.dart';
import '../models/enums.dart';
import '../models/installment.dart';
import '../models/ledger_transaction.dart';
import 'schedule_generator.dart';
import 'upfront.dart';

/// Rows due within this many days (after today) are [RowStatus.upcoming].
const int upcomingWindowDays = 7;

/// Derived status of one projected row. Never stored.
enum RowStatus {
  /// Fully covered by the paid pool.
  paid,

  /// dueDate < today and not fully paid (see [ProjectedRow.isPartial]).
  overdue,

  /// dueDate == today and not fully paid. Stays this until the day ends.
  dueToday,

  /// Due within the next [upcomingWindowDays] days.
  upcoming,

  /// Due later than that.
  planned,

  /// A base row whose whole amount was rescheduled away (effective due 0).
  /// Shown in the timeline, excluded from allocation, shortfall and counts.
  rescheduled,
}

/// The part of the shortfall of one overdue row that an extension row
/// carries.
final class ExtensionSource {
  const ExtensionSource({
    required this.seq,
    required this.dueDate,
    required this.amount,
    required this.wasPartial,
  });

  /// The overdue row's seq.
  final int seq;
  final CivilDate dueDate;

  /// Portion of that row's shortfall carried by the extension row.
  final Money amount;

  /// True when the source row had some (but not full) payment.
  final bool wasPartial;

  /// "missed on 15 Oct (Inst. 5)" / "partial on 8 Oct (Inst. 4)".
  String get label =>
      '${wasPartial ? 'partial' : 'missed'} on '
      '${formatCivilDateDayMonth(dueDate)} (Inst. $seq)';
}

/// One row of the effective schedule: a stored installment (base or
/// rescheduled) or a computed auto-extension.
final class ProjectedRow {
  const ProjectedRow({
    required this.installmentId,
    required this.seq,
    required this.kind,
    required this.dueDate,
    required this.scheduledAmount,
    required this.rescheduledOut,
    required this.due,
    required this.paid,
    required this.status,
    required this.isPartial,
    required this.daysOverdue,
    required this.isExtension,
    this.rescheduledFromId,
    this.sources = const <ExtensionSource>[],
  });

  /// Stored installment id; `null` for an extension row.
  final String? installmentId;
  final int seq;

  /// `null` for an extension row.
  final InstallmentKind? kind;
  final CivilDate dueDate;

  /// The stored `amountDue` (for an extension: same as [due]).
  final Money scheduledAmount;
  final Money rescheduledOut;

  /// Effective due: `amountDue − rescheduledOut` (never negative).
  final Money due;

  /// FIFO-allocated share of the paid pool.
  final Money paid;
  final RowStatus status;

  /// 0 < paid < due (on any not-fully-paid row, overdue or not).
  final bool isPartial;

  /// `today − dueDate` for overdue rows, else 0.
  final int daysOverdue;
  final bool isExtension;
  final String? rescheduledFromId;

  /// Extension rows only: which shortfall rows this row carries
  /// (chronological).
  final List<ExtensionSource> sources;

  /// Unpaid part of this row.
  Money get remaining => due - paid;

  bool get isRescheduledAway => status == RowStatus.rescheduled;

  /// Counted in cycles (everything except 0-due rescheduled rows).
  bool get countsAsCycle => !isRescheduledAway;

  /// Not fully paid and not rescheduled away.
  bool get isOpen => !isRescheduledAway && paid < due;

  /// Extension rows: the [sources] labels joined with " + ".
  String? get sourceLabel => sources.isEmpty
      ? null
      : sources.map((ExtensionSource s) => s.label).join(' + ');

  @override
  String toString() =>
      'ProjectedRow(#$seq $dueDate due=${due.paise} paid=${paid.paise} '
      '${status.name}${isExtension ? ' ext' : ''})';
}

/// Everything the UI shows for one contract, derived from its documents.
final class ContractProjection {
  const ContractProjection({
    required this.contract,
    required this.today,
    required this.rows,
    required this.totalPaid,
    required this.outstanding,
    required this.excess,
    required this.overdueAmount,
    required this.overdueCount,
    required this.maxDaysOverdue,
    required this.nextDue,
    required this.maturityDate,
    required this.cyclesTotal,
    required this.cyclesPaid,
    required this.clearedBps,
  });

  final Contract contract;
  final CivilDate today;

  /// Effective rows in (dueDate, seq) order, then the extension rows.
  final List<ProjectedRow> rows;

  /// P = Σ payment + Σ rolloverSettlement − Σ reversal.
  final Money totalPaid;

  /// max(sanctioned − P, 0).
  final Money outstanding;

  /// max(P − sanctioned, 0): "Excess collected".
  final Money excess;

  /// Shortfall S over rows due before today.
  final Money overdueAmount;
  final int overdueCount;
  final int maxDaysOverdue;

  /// First row not fully paid (extensions included); `null` when settled.
  final ProjectedRow? nextDue;

  /// Last row's date (extensions included).
  final CivilDate maturityDate;

  /// Rows excluding 0-due rescheduled rows, extensions included.
  final int cyclesTotal;
  final int cyclesPaid;

  /// P as basis points of sanctioned, 0–10000.
  final int clearedBps;

  bool get isSettled => outstanding.isZero;
  bool get hasExcess => excess.isPositive;
  bool get hasOverdue => overdueAmount.isPositive;

  Iterable<ProjectedRow> get extensionRows =>
      rows.where((ProjectedRow r) => r.isExtension);

  Iterable<ProjectedRow> get overdueRows =>
      rows.where((ProjectedRow r) => r.status == RowStatus.overdue);
}

/// Net paid pool of [contractId] from [transactions]:
/// Σ payment + Σ rolloverSettlement − Σ reversal (others ignored).
Money paidPool(String contractId, Iterable<LedgerTransaction> transactions) {
  var pool = 0;
  for (final tx in transactions) {
    if (tx.contractId != contractId) continue;
    switch (tx.type) {
      case TxType.payment:
      case TxType.rolloverSettlement:
        pool += tx.amount.paise;
      case TxType.reversal:
        pool -= tx.amount.paise;
      case TxType.disbursement:
      case TxType.reschedule:
        break;
    }
  }
  return Money(pool);
}

/// Deterministic projection of one contract (Section 2, "Ledger engine").
///
/// Inputs for other contracts are ignored. Pure: same inputs, same output.
ContractProjection projectContract({
  required Contract contract,
  required List<Installment> installments,
  required List<LedgerTransaction> transactions,
  required CivilDate today,
}) {
  // (a) Effective schedule, sorted by (dueDate, seq).
  final own =
      installments
          .where((Installment i) => i.contractId == contract.id)
          .toList()
        ..sort((Installment a, Installment b) {
          final byDate = a.dueDate.compareTo(b.dueDate);
          return byDate != 0 ? byDate : a.seq.compareTo(b.seq);
        });

  // (b) Paid pool.
  final pool = paidPool(contract.id, transactions);
  var unallocated = pool.paise > 0 ? pool.paise : 0;

  // (c)–(e) FIFO allocation, statuses, shortfall.
  final rows = <ProjectedRow>[];
  final shortfalls = <ExtensionSource>[];
  var shortfall = 0;
  var overdueCount = 0;
  var maxDaysOverdue = 0;
  var maxSeq = 0;
  CivilDate? lastEffectiveDate;

  for (final inst in own) {
    if (inst.seq > maxSeq) maxSeq = inst.seq;
    final effective = inst.amountDue.paise - inst.rescheduledOut.paise;
    if (effective <= 0) {
      rows.add(
        ProjectedRow(
          installmentId: inst.id,
          seq: inst.seq,
          kind: inst.kind,
          dueDate: inst.dueDate,
          scheduledAmount: inst.amountDue,
          rescheduledOut: inst.rescheduledOut,
          due: Money.zero,
          paid: Money.zero,
          status: RowStatus.rescheduled,
          isPartial: false,
          daysOverdue: 0,
          isExtension: false,
          rescheduledFromId: inst.rescheduledFromId,
        ),
      );
      continue;
    }
    lastEffectiveDate = inst.dueDate;
    final paid = unallocated < effective ? unallocated : effective;
    unallocated -= paid;

    final RowStatus status;
    var daysOverdue = 0;
    if (paid >= effective) {
      status = RowStatus.paid;
    } else if (inst.dueDate.isBefore(today)) {
      status = RowStatus.overdue;
      daysOverdue = inst.dueDate.daysBetween(today);
      overdueCount++;
      if (daysOverdue > maxDaysOverdue) maxDaysOverdue = daysOverdue;
      final short = effective - paid;
      shortfall += short;
      shortfalls.add(
        ExtensionSource(
          seq: inst.seq,
          dueDate: inst.dueDate,
          amount: Money(short),
          wasPartial: paid > 0,
        ),
      );
    } else {
      status = _futureStatus(inst.dueDate, today);
    }

    rows.add(
      ProjectedRow(
        installmentId: inst.id,
        seq: inst.seq,
        kind: inst.kind,
        dueDate: inst.dueDate,
        scheduledAmount: inst.amountDue,
        rescheduledOut: inst.rescheduledOut,
        due: Money(effective),
        paid: Money(paid),
        status: status,
        isPartial: paid > 0 && paid < effective,
        daysOverdue: daysOverdue,
        isExtension: false,
        rescheduledFromId: inst.rescheduledFromId,
      ),
    );
  }

  // (f) Auto-extension (virtual, never stored).
  final step = contract.installmentAmount.paise;
  if (shortfall > 0 && step > 0) {
    rows.addAll(
      _extensionRows(
        contract: contract,
        today: today,
        shortfall: shortfall,
        step: step,
        sources: shortfalls,
        after: lastEffectiveDate!,
        firstSeq: maxSeq + 1,
      ),
    );
  }

  // (g) Totals.
  final sanctioned = contract.sanctioned.paise;
  final p = pool.paise;
  ProjectedRow? nextDue;
  CivilDate? maturity;
  var cyclesTotal = 0;
  var cyclesPaid = 0;
  for (final row in rows) {
    if (!row.countsAsCycle) continue;
    cyclesTotal++;
    if (row.status == RowStatus.paid) cyclesPaid++;
    if (nextDue == null && row.isOpen) nextDue = row;
    if (maturity == null || row.dueDate.isAfter(maturity)) {
      maturity = row.dueDate;
    }
  }
  final cleared = sanctioned <= 0 || p <= 0
      ? 0
      : (p * bpsScale ~/ sanctioned).clamp(0, bpsScale);

  return ContractProjection(
    contract: contract,
    today: today,
    rows: List<ProjectedRow>.unmodifiable(rows),
    totalPaid: pool,
    outstanding: Money(sanctioned - p > 0 ? sanctioned - p : 0),
    excess: Money(p - sanctioned > 0 ? p - sanctioned : 0),
    overdueAmount: Money(shortfall),
    overdueCount: overdueCount,
    maxDaysOverdue: maxDaysOverdue,
    nextDue: nextDue,
    maturityDate: maturity ?? contract.firstDueDate,
    cyclesTotal: cyclesTotal,
    cyclesPaid: cyclesPaid,
    clearedBps: cleared,
  );
}

RowStatus _futureStatus(CivilDate dueDate, CivilDate today) {
  final ahead = today.daysBetween(dueDate);
  if (ahead <= 0) return RowStatus.dueToday;
  if (ahead <= upcomingWindowDays) return RowStatus.upcoming;
  return RowStatus.planned;
}

/// ⌈S / step⌉ rows of `step` (last = remainder), dated by the frequency
/// stepper after [after] and rolled forward to today or later, so that an
/// extension is never itself overdue.
///
/// Attribution: a late payment is allocated FIFO, so it clears the
/// *earliest* shortfall first, and a smaller S shrinks the *last* extension
/// row first. The tail rows are therefore attributed to the earliest
/// shortfall rows: sources are laid across the rows latest-first. This keeps
/// each label stable as late payments arrive and reproduces the Stitch mock
/// (Inst. 11 = missed Inst. 5, Inst. 12 = partial Inst. 4).
List<ProjectedRow> _extensionRows({
  required Contract contract,
  required CivilDate today,
  required int shortfall,
  required int step,
  required List<ExtensionSource> sources,
  required CivilDate after,
  required int firstSeq,
}) {
  final prefs = SchedulePrefs(
    weekday: contract.preferredWeekday,
    monthDay: contract.preferredMonthDay,
  );
  final count = (shortfall + step - 1) ~/ step;
  var date = nextDueDate(after, contract.frequency, prefs);
  while (date.isBefore(today)) {
    date = nextDueDate(date, contract.frequency, prefs);
  }

  // Latest shortfall first; each entry's remaining amount is consumed
  // across consecutive rows.
  final queue = sources.reversed.toList();
  final left = queue.map((ExtensionSource s) => s.amount.paise).toList();
  var qi = 0;

  final rows = <ProjectedRow>[];
  for (var k = 0; k < count; k++) {
    if (k > 0) date = nextDueDate(date, contract.frequency, prefs);
    final amount = k == count - 1 ? shortfall - step * (count - 1) : step;

    final carried = <ExtensionSource>[];
    var need = amount;
    while (need > 0 && qi < queue.length) {
      final take = left[qi] < need ? left[qi] : need;
      final src = queue[qi];
      carried.add(
        ExtensionSource(
          seq: src.seq,
          dueDate: src.dueDate,
          amount: Money(take),
          wasPartial: src.wasPartial,
        ),
      );
      left[qi] -= take;
      need -= take;
      if (left[qi] == 0) qi++;
    }
    // Chronological label order inside one row.
    final ordered = carried.reversed.toList(growable: false);

    rows.add(
      ProjectedRow(
        installmentId: null,
        seq: firstSeq + k,
        kind: null,
        dueDate: date,
        scheduledAmount: Money(amount),
        rescheduledOut: Money.zero,
        due: Money(amount),
        paid: Money.zero,
        status: _futureStatus(date, today),
        isPartial: false,
        daysOverdue: 0,
        isExtension: true,
        sources: List<ExtensionSource>.unmodifiable(ordered),
      ),
    );
  }
  return rows;
}
