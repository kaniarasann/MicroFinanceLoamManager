import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/enums.dart';
import 'package:nordic_ledger/features/contracts/application/contract_draft.dart';

import '../../domain/ledger/ledger_fixtures.dart';

void main() {
  final today = d(2023, 11, 7); // Tue

  ContractDraft draft({
    Money? sanctioned,
    UpfrontMode mode = UpfrontMode.flat,
    int? upfront,
    Money? installment,
    Frequency frequency = Frequency.weekly,
  }) => ContractDraft(
    sanctioned: sanctioned,
    upfrontMode: mode,
    upfrontInput: upfront,
    installmentAmount: installment,
    frequency: frequency,
    weekday: 2,
    monthDay: 7,
    firstDueDate: d(2023, 11, 14),
    disbursedOn: today,
  );

  test('flat ₹7,000 of ₹1,00,000: net ₹93,000, 7.0%, 10 cycles', () {
    final x = draft(
      sanctioned: rs(100000),
      upfront: 700000,
      installment: rs(10000),
    );
    expect(x.upfront, rs(7000));
    expect(x.netDisbursed, rs(93000));
    expect(x.effectiveBps, 700);
    expect(formatBpsPercent(x.effectiveBps), '7.0%');
    expect(x.cycles, 10);
    expect(x.errors, isEmpty);
    expect(x.errorFor(LedgerFields.sanctioned), isNull);
    expect(x.schedule, hasLength(10));
    expect(x.schedule!.last.dueDate, d(2024, 1, 16));
  });

  test('percent 7.5%: ₹7,500 / ₹92,500', () {
    final x = draft(
      sanctioned: rs(100000),
      mode: UpfrontMode.percent,
      upfront: 750,
    );
    expect(x.upfront, rs(7500));
    expect(x.netDisbursed, rs(92500));
    expect(formatBpsPercent(x.effectiveBps), '7.5%');
  });

  test('empty form: zero figures, no cycles, errors, no schedule', () {
    final x = draft();
    expect(x.upfront, Money.zero);
    expect(x.netDisbursed, Money.zero);
    expect(x.effectiveBps, 0);
    expect(x.cycles, isNull);
    expect(x.errorFor(LedgerFields.sanctioned), isNotNull);
    expect(x.errorFor(LedgerFields.installmentAmount), isNotNull);
    expect(x.schedule, isNull);
  });

  test('the weekday / month day only count for their frequency', () {
    final daily = draft(
      sanctioned: rs(1000),
      upfront: 0,
      installment: rs(100),
      frequency: Frequency.daily,
    );
    expect(daily.errors, isEmpty);
    expect(daily.schedule!.first.dueDate, d(2023, 11, 14));
    final monthly = draft(
      sanctioned: rs(1000),
      upfront: 0,
      installment: rs(500),
      frequency: Frequency.monthly,
    );
    expect(monthly.schedule!.map((PlannedInstallment p) => p.dueDate), <Object>[
      d(2023, 12, 7),
      d(2024, 1, 7),
    ]);
  });

  test('defaultFirstDue: next matching day after today', () {
    expect(defaultFirstDue(today, Frequency.daily), d(2023, 11, 8));
    expect(
      defaultFirstDue(today, Frequency.weekly, weekday: 2),
      d(2023, 11, 14),
    );
    expect(
      defaultFirstDue(today, Frequency.weekly, weekday: 5),
      d(2023, 11, 10),
    );
    expect(
      defaultFirstDue(today, Frequency.monthly, monthDay: 7),
      d(2023, 12, 7),
    );
    expect(
      defaultFirstDue(today, Frequency.monthly, monthDay: 31),
      d(2023, 11, 30),
    );
  });

  test('parsePercentBps and formatBpsPercent', () {
    expect(parsePercentBps('7'), 700);
    expect(parsePercentBps('7.5'), 750);
    expect(parsePercentBps(' 12.25 '), 1225);
    expect(parsePercentBps('7.'), 700);
    expect(parsePercentBps(''), isNull);
    expect(parsePercentBps('7.255'), isNull);
    expect(parsePercentBps('abc'), isNull);
    expect(formatBpsPercent(725), '7.3%');
    expect(formatBpsPercent(10000), '100.0%');
    expect(formatBpsPercent(0), '0.0%');
  });
}
