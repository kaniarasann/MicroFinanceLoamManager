// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'portfolio_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// First day of the dashboard's history window (changes once a month).

@ProviderFor(historyWindowStart)
final historyWindowStartProvider = HistoryWindowStartProvider._();

/// First day of the dashboard's history window (changes once a month).

final class HistoryWindowStartProvider
    extends $FunctionalProvider<CivilDate, CivilDate, CivilDate>
    with $Provider<CivilDate> {
  /// First day of the dashboard's history window (changes once a month).
  HistoryWindowStartProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyWindowStartProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyWindowStartHash();

  @$internal
  @override
  $ProviderElement<CivilDate> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CivilDate create(Ref ref) {
    return historyWindowStart(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CivilDate value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CivilDate>(value),
    );
  }
}

String _$historyWindowStartHash() =>
    r'71b723dbc6fd7e8dc9809dfd4ef82541435cf91a';

/// The active company's closed and rolled-over contracts (live).

@ProviderFor(historyContracts)
final historyContractsProvider = HistoryContractsProvider._();

/// The active company's closed and rolled-over contracts (live).

final class HistoryContractsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Contract>>,
          List<Contract>,
          Stream<List<Contract>>
        >
    with $FutureModifier<List<Contract>>, $StreamProvider<List<Contract>> {
  /// The active company's closed and rolled-over contracts (live).
  HistoryContractsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyContractsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyContractsHash();

  @$internal
  @override
  $StreamProviderElement<List<Contract>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Contract>> create(Ref ref) {
    return historyContracts(ref);
  }
}

String _$historyContractsHash() => r'01cd06b37003ec05556cc013dfa65f7b51d48c2c';

/// Transactions of inactive contracts inside the chart window (live).

@ProviderFor(historyTransactions)
final historyTransactionsProvider = HistoryTransactionsProvider._();

/// Transactions of inactive contracts inside the chart window (live).

final class HistoryTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LedgerTransaction>>,
          List<LedgerTransaction>,
          Stream<List<LedgerTransaction>>
        >
    with
        $FutureModifier<List<LedgerTransaction>>,
        $StreamProvider<List<LedgerTransaction>> {
  /// Transactions of inactive contracts inside the chart window (live).
  HistoryTransactionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyTransactionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyTransactionsHash();

  @$internal
  @override
  $StreamProviderElement<List<LedgerTransaction>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<LedgerTransaction>> create(Ref ref) {
    return historyTransactions(ref);
  }
}

String _$historyTransactionsHash() =>
    r'b3b243e88c58eec7320720c00747fcb7aabe3253';

/// Installments of inactive contracts inside the chart window (live).

@ProviderFor(historyInstallments)
final historyInstallmentsProvider = HistoryInstallmentsProvider._();

/// Installments of inactive contracts inside the chart window (live).

final class HistoryInstallmentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Installment>>,
          List<Installment>,
          Stream<List<Installment>>
        >
    with
        $FutureModifier<List<Installment>>,
        $StreamProvider<List<Installment>> {
  /// Installments of inactive contracts inside the chart window (live).
  HistoryInstallmentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyInstallmentsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyInstallmentsHash();

  @$internal
  @override
  $StreamProviderElement<List<Installment>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Installment>> create(Ref ref) {
    return historyInstallments(ref);
  }
}

String _$historyInstallmentsHash() =>
    r'c310f55a6a3335313628a0fea3d3d4190ffcb684';

/// One holder per active company (see [portfolioProvider]).

@ProviderFor(portfolioHolder)
final portfolioHolderProvider = PortfolioHolderProvider._();

/// One holder per active company (see [portfolioProvider]).

final class PortfolioHolderProvider
    extends
        $FunctionalProvider<PortfolioHolder, PortfolioHolder, PortfolioHolder>
    with $Provider<PortfolioHolder> {
  /// One holder per active company (see [portfolioProvider]).
  PortfolioHolderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'portfolioHolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$portfolioHolderHash();

  @$internal
  @override
  $ProviderElement<PortfolioHolder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PortfolioHolder create(Ref ref) {
    return portfolioHolder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PortfolioHolder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PortfolioHolder>(value),
    );
  }
}

String _$portfolioHolderHash() => r'c2b71f484b39c9310600b2b509b5fdfbd16c7a61';

/// Dashboard, calendar and overdue figures for the active company. Loading
/// until the active projections and the three history listeners have
/// delivered for this company. While a listener reloads afterwards (a
/// re-subscription at the month change, a loan closing), the last figures
/// stay on screen instead of a spinner.

@ProviderFor(portfolio)
final portfolioProvider = PortfolioProvider._();

/// Dashboard, calendar and overdue figures for the active company. Loading
/// until the active projections and the three history listeners have
/// delivered for this company. While a listener reloads afterwards (a
/// re-subscription at the month change, a loan closing), the last figures
/// stay on screen instead of a spinner.

final class PortfolioProvider
    extends
        $FunctionalProvider<
          AsyncValue<PortfolioMetrics>,
          AsyncValue<PortfolioMetrics>,
          AsyncValue<PortfolioMetrics>
        >
    with $Provider<AsyncValue<PortfolioMetrics>> {
  /// Dashboard, calendar and overdue figures for the active company. Loading
  /// until the active projections and the three history listeners have
  /// delivered for this company. While a listener reloads afterwards (a
  /// re-subscription at the month change, a loan closing), the last figures
  /// stay on screen instead of a spinner.
  PortfolioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'portfolioProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$portfolioHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<PortfolioMetrics>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<PortfolioMetrics> create(Ref ref) {
    return portfolio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<PortfolioMetrics> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<PortfolioMetrics>>(value),
    );
  }
}

String _$portfolioHash() => r'cacb447c94702cf9bbc41f4a767627079da344d0';

/// Memoised collections chart series for [period].

@ProviderFor(collectionsSeries)
final collectionsSeriesProvider = CollectionsSeriesFamily._();

/// Memoised collections chart series for [period].

final class CollectionsSeriesProvider
    extends
        $FunctionalProvider<
          List<CollectionBucket>?,
          List<CollectionBucket>?,
          List<CollectionBucket>?
        >
    with $Provider<List<CollectionBucket>?> {
  /// Memoised collections chart series for [period].
  CollectionsSeriesProvider._({
    required CollectionsSeriesFamily super.from,
    required ChartPeriod super.argument,
  }) : super(
         retry: null,
         name: r'collectionsSeriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$collectionsSeriesHash();

  @override
  String toString() {
    return r'collectionsSeriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<CollectionBucket>?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<CollectionBucket>? create(Ref ref) {
    final argument = this.argument as ChartPeriod;
    return collectionsSeries(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<CollectionBucket>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<CollectionBucket>?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CollectionsSeriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$collectionsSeriesHash() => r'4f49043813661f1ce5e0cab77015947386dda438';

/// Memoised collections chart series for [period].

final class CollectionsSeriesFamily extends $Family
    with $FunctionalFamilyOverride<List<CollectionBucket>?, ChartPeriod> {
  CollectionsSeriesFamily._()
    : super(
        retry: null,
        name: r'collectionsSeriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Memoised collections chart series for [period].

  CollectionsSeriesProvider call(ChartPeriod period) =>
      CollectionsSeriesProvider._(argument: period, from: this);

  @override
  String toString() => r'collectionsSeriesProvider';
}

/// Memoised calendar buckets for one month.

@ProviderFor(calendarMonth)
final calendarMonthProvider = CalendarMonthFamily._();

/// Memoised calendar buckets for one month.

final class CalendarMonthProvider
    extends
        $FunctionalProvider<
          List<CalendarDay>?,
          List<CalendarDay>?,
          List<CalendarDay>?
        >
    with $Provider<List<CalendarDay>?> {
  /// Memoised calendar buckets for one month.
  CalendarMonthProvider._({
    required CalendarMonthFamily super.from,
    required (int, int) super.argument,
  }) : super(
         retry: null,
         name: r'calendarMonthProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$calendarMonthHash();

  @override
  String toString() {
    return r'calendarMonthProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<List<CalendarDay>?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<CalendarDay>? create(Ref ref) {
    final argument = this.argument as (int, int);
    return calendarMonth(ref, argument.$1, argument.$2);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<CalendarDay>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<CalendarDay>?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarMonthProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$calendarMonthHash() => r'8f3d25f9dd36b568244ddf75cc20a7c82f578ab0';

/// Memoised calendar buckets for one month.

final class CalendarMonthFamily extends $Family
    with $FunctionalFamilyOverride<List<CalendarDay>?, (int, int)> {
  CalendarMonthFamily._()
    : super(
        retry: null,
        name: r'calendarMonthProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Memoised calendar buckets for one month.

  CalendarMonthProvider call(int year, int month) =>
      CalendarMonthProvider._(argument: (year, month), from: this);

  @override
  String toString() => r'calendarMonthProvider';
}

/// Memoised schedule rows due in [from]..[to] (calendar day and month
/// lists).

@ProviderFor(dueItems)
final dueItemsProvider = DueItemsFamily._();

/// Memoised schedule rows due in [from]..[to] (calendar day and month
/// lists).

final class DueItemsProvider
    extends
        $FunctionalProvider<
          List<DueRowItem>?,
          List<DueRowItem>?,
          List<DueRowItem>?
        >
    with $Provider<List<DueRowItem>?> {
  /// Memoised schedule rows due in [from]..[to] (calendar day and month
  /// lists).
  DueItemsProvider._({
    required DueItemsFamily super.from,
    required (CivilDate, CivilDate) super.argument,
  }) : super(
         retry: null,
         name: r'dueItemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dueItemsHash();

  @override
  String toString() {
    return r'dueItemsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<List<DueRowItem>?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<DueRowItem>? create(Ref ref) {
    final argument = this.argument as (CivilDate, CivilDate);
    return dueItems(ref, argument.$1, argument.$2);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<DueRowItem>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<DueRowItem>?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DueItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dueItemsHash() => r'eef14c08f022e0e26f55e04afa72d6744dd6c99d';

/// Memoised schedule rows due in [from]..[to] (calendar day and month
/// lists).

final class DueItemsFamily extends $Family
    with $FunctionalFamilyOverride<List<DueRowItem>?, (CivilDate, CivilDate)> {
  DueItemsFamily._()
    : super(
        retry: null,
        name: r'dueItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Memoised schedule rows due in [from]..[to] (calendar day and month
  /// lists).

  DueItemsProvider call(CivilDate from, CivilDate to) =>
      DueItemsProvider._(argument: (from, to), from: this);

  @override
  String toString() => r'dueItemsProvider';
}

/// Overdue loans of the active company, grouped per contract.

@ProviderFor(overdueLoans)
final overdueLoansProvider = OverdueLoansProvider._();

/// Overdue loans of the active company, grouped per contract.

final class OverdueLoansProvider
    extends
        $FunctionalProvider<
          List<OverdueLoan>?,
          List<OverdueLoan>?,
          List<OverdueLoan>?
        >
    with $Provider<List<OverdueLoan>?> {
  /// Overdue loans of the active company, grouped per contract.
  OverdueLoansProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'overdueLoansProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$overdueLoansHash();

  @$internal
  @override
  $ProviderElement<List<OverdueLoan>?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<OverdueLoan>? create(Ref ref) {
    return overdueLoans(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<OverdueLoan>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<OverdueLoan>?>(value),
    );
  }
}

String _$overdueLoansHash() => r'faead61d8bcf8ecc12b7bdece3bdce9bb5a2d1f4';
