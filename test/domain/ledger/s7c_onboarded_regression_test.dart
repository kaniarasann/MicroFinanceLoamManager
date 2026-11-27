import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/contracts/application/contract_draft.dart';
import 'package:nordic_ledger/features/contracts/application/onboarding_draft.dart';
import 'package:nordic_ledger/features/contracts/data/contract_repository.dart';
import 'package:uuid/uuid.dart';

import 'ledger_fixtures.dart';

/// Sprint 7c, Task 22: onboarded loans through every dashboard figure,
/// built with the real write planner (`planOnboarding`), plus the preview
/// benchmark.
///
/// Today is Tue 24 Nov 2026.
/// - W: weekly ₹1,00,000 at ₹10,000 on Tuesdays, first due 15 Sep 2026,
///   disbursed 8 Sep with ₹5,000 upfront, ₹55,000 opening total (spread).
/// - D: daily ₹36,600 at ₹100 (366 rows), disbursed 400 days ago (20 Oct
///   2025), 300 itemised payments of ₹100 on rows 1–300, so the oldest
///   cash is older than the 12-month chart window.
final CivilDate _today = d(2026, 11, 24);

const LedgerActor _actor = LedgerActor(
  uid: 'uid-owner',
  name: 'Ravi',
  deviceId: 'dev-1',
);

OnboardContractCommand _cmd({
  required Money sanctioned,
  required int upfrontPaise,
  required Money installment,
  required Frequency frequency,
  required CivilDate firstDue,
  required CivilDate disbursedOn,
  int? weekday,
}) => OnboardContractCommand(
  cid: 'co-1',
  borrower: Borrower(
    id: 'b1',
    name: 'Anita Sharma',
    nameLower: 'anita sharma',
    phoneE164: '+919845012890',
    createdBy: 'uid-owner',
    createdAt: DateTime.utc(2025),
    updatedAt: DateTime.utc(2025),
  ),
  sanctioned: sanctioned,
  upfrontMode: UpfrontMode.flat,
  upfrontInput: upfrontPaise,
  installmentAmount: installment,
  frequency: frequency,
  preferredWeekday: weekday,
  firstDueDate: firstDue,
  disbursedOn: disbursedOn,
  cachedNextLoanNo: 3,
  actor: _actor,
  role: Role.owner,
  today: _today,
  pastPayments: const <PastPaymentInput>[],
);

OnboardingPlan _plan(
  OnboardContractCommand c,
  List<PastPaymentInput> past,
  String id,
) => planOnboarding(
  terms: c,
  pastPayments: past,
  today: _today,
  contractId: id,
  borrowerId: 'b1',
  borrowerName: 'Anita Sharma',
  borrowerPhoneE164: '+919845012890',
  now: DateTime.utc(2026, 11, 24),
  uuid: const Uuid(),
);

final OnboardContractCommand _weeklyCmd = _cmd(
  sanctioned: rs(100000),
  upfrontPaise: 500000,
  installment: rs(10000),
  frequency: Frequency.weekly,
  weekday: 2,
  firstDue: d(2026, 9, 15),
  disbursedOn: d(2026, 9, 8),
);

final OnboardContractCommand _dailyCmd = _cmd(
  sanctioned: rs(36600),
  upfrontPaise: 0,
  installment: rs(100),
  frequency: Frequency.daily,
  firstDue: _today.addDays(-399),
  disbursedOn: _today.addDays(-400),
);

List<PlannedInstallment> _schedule(OnboardContractCommand c) =>
    generateSchedule(
      sanctioned: c.sanctioned,
      installmentAmount: c.installmentAmount,
      frequency: c.frequency,
      firstDueDate: c.firstDueDate,
      preferredWeekday: c.preferredWeekday,
    );

OnboardingPlan _weekly() => _plan(
  _weeklyCmd,
  spreadOpeningTotal(
    schedule: _schedule(_weeklyCmd),
    total: rs(55000),
    mode: PaymentMode.cash,
    disbursedOn: _weeklyCmd.disbursedOn,
    today: _today,
  ),
  'W',
);

OnboardingPlan _daily({int n = 300, int rupees = 100}) =>
    _plan(_dailyCmd, <PastPaymentInput>[
      for (var i = 0; i < n; i++)
        PastPaymentInput(
          paidOn: _dailyCmd.firstDueDate.addDays(i % 366),
          amount: rs(rupees),
          mode: PaymentMode.values[i % 3],
        ),
    ], 'D');

ContractProjection _project(
  OnboardingPlan p, {
  List<LedgerTransaction>? extra,
}) => projectContract(
  contract: p.contract,
  installments: p.installments,
  transactions: <LedgerTransaction>[...p.transactions, ...?extra],
  today: _today,
);

PortfolioMetrics _portfolio(
  List<OnboardingPlan> plans, {
  List<LedgerTransaction> extra = const <LedgerTransaction>[],
}) {
  final all = <LedgerTransaction>[
    for (final p in plans) ...p.transactions,
    ...extra,
  ];
  return computePortfolio(
    projections: <ContractProjection>[
      for (final p in plans)
        projectContract(
          contract: p.contract,
          installments: p.installments,
          transactions: <LedgerTransaction>[
            ...p.transactions,
            for (final e in extra)
              if (e.contractId == p.contract.id) e,
          ],
          today: _today,
        ),
    ],
    allTransactions: all,
    today: _today,
    contractsById: <String, Contract>{
      for (final p in plans) p.contract.id: p.contract,
    },
  );
}

/// Σ of cash payments − reversals dated in [from, to].
Money _cashBetween(
  Iterable<LedgerTransaction> txs,
  CivilDate from,
  CivilDate to,
) {
  var paise = 0;
  for (final t in txs) {
    if (t.paidOn.isBefore(from) || t.paidOn.isAfter(to)) continue;
    if (t.type == TxType.payment) paise += t.amount.paise;
    if (t.type == TxType.reversal) paise -= t.amount.paise;
  }
  return Money(paise);
}

LedgerTransaction _reversalOf(LedgerTransaction original, String id) =>
    original.copyWith(
      id: id,
      type: TxType.reversal,
      reversesTxId: original.id,
      openingBalance: false,
      note: 'Correction',
    );

void main() {
  late OnboardingPlan w;
  late OnboardingPlan dly;
  late PortfolioMetrics m;

  setUp(() {
    w = _weekly();
    dly = _daily();
    m = _portfolio(<OnboardingPlan>[w, dly]);
  });

  group('dashboard KPIs', () {
    test('Total collected includes every past payment, even older than the '
        '12-month window', () {
      final windowStart = chartWindowStart(_today);
      expect(
        dly.payments.any(
          (LedgerTransaction t) => t.paidOn.isBefore(windowStart),
        ),
        isTrue,
      );
      expect(m.totalCollected, rs(55000) + rs(30000));
    });

    test('Total net disbursed includes the net cash of both loans', () {
      expect(m.totalNetDisbursed, rs(95000) + rs(36600));
    });

    test('received today and collected this month are untouched (nothing is '
        'dated in them)', () {
      expect(m.todayDue.received, Money.zero);
      expect(m.receivableBreakdown.collectedThisMonth.amount, Money.zero);
    });

    test('a payment dated today does count today and this month', () {
      final live = tx('W', rs(2000), _today, id: 'live-today');
      final m2 = _portfolio(
        <OnboardingPlan>[w, dly],
        extra: <LedgerTransaction>[live],
      );
      expect(m2.todayDue.received, rs(2000));
      expect(m2.receivableBreakdown.collectedThisMonth.amount, rs(2000));
    });

    test('a row due today stays open: the spread never dates cash today', () {
      // Weekly from 13 Oct: rows 13 Oct … 15 Dec, the 7th (24 Nov) is today.
      final cmd = _cmd(
        sanctioned: rs(100000),
        upfrontPaise: 0,
        installment: rs(10000),
        frequency: Frequency.weekly,
        weekday: 2,
        firstDue: d(2026, 10, 13),
        disbursedOn: d(2026, 10, 6),
      );
      final spread = spreadOpeningTotal(
        schedule: _schedule(cmd),
        total: rs(65000),
        mode: PaymentMode.cash,
        disbursedOn: cmd.disbursedOn,
        today: _today,
      );
      final p = _plan(cmd, spread, 'T');
      expect(
        p.payments.any((LedgerTransaction t) => t.paidOn == _today),
        isFalse,
      );
      final pm = _portfolio(<OnboardingPlan>[p]);
      expect(pm.todayDue.received, Money.zero);
      final todayRow = _project(
        p,
      ).rows.firstWhere((ProjectedRow r) => r.dueDate == _today);
      // ₹65,000 covers rows 1–6 (₹60,000) + ₹5,000 of today's row.
      expect(todayRow.status, RowStatus.dueToday);
      expect(todayRow.remaining, rs(5000));
    });
  });

  group('chart and calendar', () {
    test('every chart bucket holds the cash of its own dates; collection '
        'rate ≤ 100%', () {
      final all = <LedgerTransaction>[...w.transactions, ...dly.transactions];
      for (final period in ChartPeriod.values) {
        for (final b in m.collectionsSeries(period)) {
          expect(
            b.collected,
            _cashBetween(all, b.start, b.end),
            reason: '${period.name} ${b.label}',
          );
          expect(
            b.collected <= b.due,
            isTrue,
            reason: '${period.name} ${b.label}: collected above due',
          );
        }
      }
    });

    test('12M chart total is below Total collected: older cash is outside '
        'the window only', () {
      final totals = SeriesTotals.of(m.collectionsSeries(ChartPeriod.months12));
      expect(totals.collected < m.totalCollected, isTrue);
      expect(
        totals.collected,
        _cashBetween(
          <LedgerTransaction>[...w.transactions, ...dly.transactions],
          chartWindowStart(_today),
          _today,
        ),
      );
    });

    test('calendar days show the cash on its own dates (Sep and Oct 2026)', () {
      final all = <LedgerTransaction>[...w.transactions, ...dly.transactions];
      for (final (year, month) in <(int, int)>[(2026, 9), (2026, 10)]) {
        for (final day in m.calendarBuckets(year, month)) {
          expect(
            day.collected,
            _cashBetween(all, day.date, day.date),
            reason: '${day.date}',
          );
        }
      }
      final sep15 = m
          .calendarBuckets(2026, 9)
          .firstWhere((CalendarDay x) => x.date == d(2026, 9, 15));
      expect(sep15.collected, rs(10000));
    });
  });

  group('overdue', () {
    test('Total overdue, the tracker and extension rows', () {
      final pw = _project(w);
      final pd = _project(dly);
      expect(pw.overdueAmount, rs(45000));
      expect(pw.overdueCount, 5);
      expect(m.totalOverdue, pw.overdueAmount + pd.overdueAmount);
      expect(m.overdueInstallmentCount, pw.overdueCount + pd.overdueCount);
      final loans = groupOverdueByLoan(m.overdueList);
      expect(loans.map((OverdueLoan l) => l.contractId).toSet(), <String>{
        'W',
        'D',
      });
      // The whole weekly schedule is past: its extensions carry the shortfall.
      final ext = Money.sum(
        pw.extensionRows.map((ProjectedRow r) => r.remaining),
      );
      expect(ext, rs(45000));
      expect(
        pw.extensionRows.every((ProjectedRow r) => !r.dueDate.isBefore(_today)),
        isTrue,
      );
    });

    test('the reminder feed (upcoming dues) holds no past rows; the overdue '
        'nudge feed holds the onboarded shortfall', () {
      // Sprint 8 builds the scheduler on these two feeds.
      final upcoming = m.dueItemsBetween(_today, _today.addDays(30));
      expect(
        upcoming.every((DueRowItem i) => !i.dueDate.isBefore(_today)),
        isTrue,
      );
      expect(
        m.overdueList.where((OverdueItem i) => i.contractId == 'W'),
        hasLength(5),
      );
    });
  });

  group('reversals', () {
    test('an onboarding reversal moves cash on the original date only', () {
      final original = w.payments[2]; // 29 Sep
      final rev = _reversalOf(original, 'rev-1');
      final m2 = _portfolio(
        <OnboardingPlan>[w, dly],
        extra: <LedgerTransaction>[rev],
      );
      expect(m2.totalCollected, m.totalCollected - rs(10000));
      expect(m2.todayDue.received, Money.zero);
      expect(m2.receivableBreakdown.collectedThisMonth.amount, Money.zero);
      final day = m2
          .calendarBuckets(2026, 9)
          .firstWhere((CalendarDay x) => x.date == original.paidOn);
      expect(day.collected, Money.zero);
      final pw = projectContract(
        contract: w.contract,
        installments: w.installments,
        transactions: <LedgerTransaction>[...w.transactions, rev],
        today: _today,
      );
      expect(pw.outstanding, rs(55000));
    });

    test('an opening-balance reversal restores the full outstanding', () {
      final revs = <LedgerTransaction>[
        for (final p in w.payments)
          if (p.openingBalance) _reversalOf(p, 'rev-${p.id}'),
      ];
      final pw = projectContract(
        contract: w.contract,
        installments: w.installments,
        transactions: <LedgerTransaction>[...w.transactions, ...revs],
        today: _today,
      );
      expect(pw.outstanding, rs(100000));
      expect(pw.overdueAmount, rs(100000));
      final m2 = _portfolio(<OnboardingPlan>[w], extra: revs);
      expect(m2.totalCollected, Money.zero);
      expect(m2.todayDue.received, Money.zero);
    });
  });

  group('performance (daily loan, 366 rows × 1,100 payments)', () {
    test('plan + project and the form preview stay within budget', () {
      // Warm up the JIT, then time several runs and take the median.
      final heavy = _daily(n: 1100, rupees: 10);
      final projectTimes = <int>[];
      final planTimes = <int>[];
      final previewTimes = <int>[];
      final terms = ContractDraft(
        sanctioned: _dailyCmd.sanctioned,
        upfrontInput: 0,
        installmentAmount: _dailyCmd.installmentAmount,
        frequency: Frequency.daily,
        firstDueDate: _dailyCmd.firstDueDate,
        disbursedOn: _dailyCmd.disbursedOn,
      );
      final rows = <PastPaymentInput>[
        for (var i = 0; i < 1100; i++)
          PastPaymentInput(
            paidOn: _dailyCmd.firstDueDate.addDays(i % 366),
            amount: rs(10),
            mode: PaymentMode.cash,
          ),
      ];
      for (var run = 0; run < 25; run++) {
        final sw = Stopwatch()..start();
        _project(heavy);
        projectTimes.add(sw.elapsedMicroseconds);

        sw
          ..reset()
          ..start();
        _project(_daily(n: 1100, rupees: 10));
        planTimes.add(sw.elapsedMicroseconds);

        sw
          ..reset()
          ..start();
        final preview = OnboardingDraft(
          terms: terms,
          today: _today,
          mode: PastPaymentsMode.itemised,
          rows: rows,
        ).preview;
        previewTimes.add(sw.elapsedMicroseconds);
        expect(preview, isNotNull);
      }
      int median(List<int> xs) => (xs..sort())[xs.length ~/ 2];
      final project = median(projectTimes);
      final plan = median(planTimes);
      final preview = median(previewTimes);
      // ignore: avoid_print
      print(
        'Onboarding benchmark (JIT, median of 25): projectContract '
        '$project µs; planOnboarding + projectContract $plan µs; '
        'OnboardingDraft.preview (validate + spread + plan + project) '
        '$preview µs',
      );
      expect(project, lessThan(16000), reason: 'projection ≤ 16 ms');
      expect(plan, lessThan(50000), reason: 'plan + project ≤ 50 ms');
      expect(preview, lessThan(50000), reason: 'form preview ≤ 50 ms');
      expect(_project(heavy).totalPaid, rs(11000));
    });
  });
}
