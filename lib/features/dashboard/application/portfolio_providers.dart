import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/time/civil_date.dart';
import '../../../core/time/today_provider.dart';
import '../../../domain/ledger/ledger.dart';
import '../../../domain/models/models.dart';
import '../../company/application/company_providers.dart'
    show activeCompanyIdProvider;
import '../../contracts/application/ledger_providers.dart';

part 'portfolio_providers.g.dart';

/// First day of the dashboard's history window (changes once a month).
@Riverpod(keepAlive: true)
CivilDate historyWindowStart(Ref ref) =>
    ref.watch(todayProvider.select(chartWindowStart));

/// The active company's closed and rolled-over contracts (live).
@Riverpod(keepAlive: true)
Stream<List<Contract>> historyContracts(Ref ref) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) return Stream<List<Contract>>.value(const <Contract>[]);
  return ref.watch(ledgerSnapshotRepositoryProvider).watchHistoryContracts(cid);
}

/// Transactions of inactive contracts inside the chart window (live).
@Riverpod(keepAlive: true)
Stream<List<LedgerTransaction>> historyTransactions(Ref ref) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) {
    return Stream<List<LedgerTransaction>>.value(const <LedgerTransaction>[]);
  }
  final since = ref.watch(historyWindowStartProvider);
  return ref
      .watch(ledgerSnapshotRepositoryProvider)
      .watchHistoryTransactions(cid, since);
}

/// Installments of inactive contracts inside the chart window (live).
@Riverpod(keepAlive: true)
Stream<List<Installment>> historyInstallments(Ref ref) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) {
    return Stream<List<Installment>>.value(const <Installment>[]);
  }
  final since = ref.watch(historyWindowStartProvider);
  return ref
      .watch(ledgerSnapshotRepositoryProvider)
      .watchHistoryInstallments(cid, since);
}

/// The last [PortfolioMetrics] computed for the active company. Reset on a
/// company switch, so a stale value never crosses companies.
final class PortfolioHolder {
  PortfolioMetrics? last;
}

/// One holder per active company (see [portfolioProvider]).
@Riverpod(keepAlive: true)
PortfolioHolder portfolioHolder(Ref ref) {
  ref.watch(activeCompanyIdProvider.select((AsyncValue<String?> v) => v.value));
  return PortfolioHolder();
}

/// Dashboard, calendar and overdue figures for the active company. Loading
/// until the active projections and the three history listeners have
/// delivered for this company. While a listener reloads afterwards (a
/// re-subscription at the month change, a loan closing), the last figures
/// stay on screen instead of a spinner.
@Riverpod(keepAlive: true)
AsyncValue<PortfolioMetrics> portfolio(Ref ref) {
  final projections = ref.watch(activeProjectionsProvider);
  final activeTx = ref.watch(activeTransactionsProvider);
  final history = ref.watch(historyContractsProvider);
  final historyTx = ref.watch(historyTransactionsProvider);
  final historyInst = ref.watch(historyInstallmentsProvider);
  final today = ref.watch(todayProvider);
  final holder = ref.watch(portfolioHolderProvider);

  for (final AsyncValue<Object?> v in <AsyncValue<Object?>>[
    projections,
    activeTx,
    history,
    historyTx,
    historyInst,
  ]) {
    if (v.hasError) {
      return AsyncError<PortfolioMetrics>(
        v.error!,
        v.stackTrace ?? StackTrace.current,
      );
    }
  }
  final inputs = <AsyncValue<Object?>>[
    projections,
    activeTx,
    history,
    historyTx,
    historyInst,
  ];
  // isLoading also covers a company switch, where a listener still holds
  // the previous company's value; the holder is reset then.
  if (inputs.any((AsyncValue<Object?> v) => v.isLoading || !v.hasValue)) {
    final last = holder.last;
    return last == null
        ? const AsyncLoading<PortfolioMetrics>()
        : AsyncData<PortfolioMetrics>(last);
  }

  final active = projections.requireValue;
  // A contract or transaction caught between the two listeners during a
  // close / reopen appears once: the active side wins.
  final txById = <String, LedgerTransaction>{
    for (final t in historyTx.requireValue) t.id: t,
    for (final t in activeTx.requireValue) t.id: t,
  };
  final metrics = computePortfolio(
    projections: active.values.toList(growable: false),
    allTransactions: txById.values.toList(growable: false),
    today: today,
    contractsById: <String, Contract>{
      for (final p in active.values) p.contract.id: p.contract,
    },
    historyContracts: history.requireValue,
    // Deduped by id; rows of contracts that are active are dropped in the
    // domain (active wins).
    historyInstallments: <String, Installment>{
      for (final i in historyInst.requireValue) i.id: i,
    }.values,
  );
  holder.last = metrics;
  return AsyncData<PortfolioMetrics>(metrics);
}

/// Memoised collections chart series for [period].
@riverpod
List<CollectionBucket>? collectionsSeries(Ref ref, ChartPeriod period) =>
    ref.watch(portfolioProvider).value?.collectionsSeries(period);

/// Memoised calendar buckets for one month.
@riverpod
List<CalendarDay>? calendarMonth(Ref ref, int year, int month) =>
    ref.watch(portfolioProvider).value?.calendarBuckets(year, month);

/// Memoised schedule rows due in [from]..[to] (calendar day and month
/// lists).
@riverpod
List<DueRowItem>? dueItems(Ref ref, CivilDate from, CivilDate to) =>
    ref.watch(portfolioProvider).value?.dueItemsBetween(from, to);

/// Overdue loans of the active company, grouped per contract.
@Riverpod(keepAlive: true)
List<OverdueLoan>? overdueLoans(Ref ref) {
  final m = ref.watch(portfolioProvider).value;
  return m == null ? null : groupOverdueByLoan(m.overdueList);
}
