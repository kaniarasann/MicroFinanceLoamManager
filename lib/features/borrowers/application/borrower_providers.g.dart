// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'borrower_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(borrowerRepository)
final borrowerRepositoryProvider = BorrowerRepositoryProvider._();

final class BorrowerRepositoryProvider
    extends
        $FunctionalProvider<
          BorrowerRepository,
          BorrowerRepository,
          BorrowerRepository
        >
    with $Provider<BorrowerRepository> {
  BorrowerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'borrowerRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$borrowerRepositoryHash();

  @$internal
  @override
  $ProviderElement<BorrowerRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BorrowerRepository create(Ref ref) {
    return borrowerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BorrowerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BorrowerRepository>(value),
    );
  }
}

String _$borrowerRepositoryHash() =>
    r'a2880b1ab3d2ca8194f1056320f8a9910bd868d4';

/// The active company's non-archived borrowers, by name (live).

@ProviderFor(borrowers)
final borrowersProvider = BorrowersProvider._();

/// The active company's non-archived borrowers, by name (live).

final class BorrowersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Borrower>>,
          List<Borrower>,
          Stream<List<Borrower>>
        >
    with $FutureModifier<List<Borrower>>, $StreamProvider<List<Borrower>> {
  /// The active company's non-archived borrowers, by name (live).
  BorrowersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'borrowersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$borrowersHash();

  @$internal
  @override
  $StreamProviderElement<List<Borrower>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Borrower>> create(Ref ref) {
    return borrowers(ref);
  }
}

String _$borrowersHash() => r'd17c73d46ddba7ad42c45099d0b7a8bce8cbc5d2';

/// One borrower of the active company (live; null when missing).

@ProviderFor(borrower)
final borrowerProvider = BorrowerFamily._();

/// One borrower of the active company (live; null when missing).

final class BorrowerProvider
    extends
        $FunctionalProvider<AsyncValue<Borrower?>, Borrower?, Stream<Borrower?>>
    with $FutureModifier<Borrower?>, $StreamProvider<Borrower?> {
  /// One borrower of the active company (live; null when missing).
  BorrowerProvider._({
    required BorrowerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'borrowerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$borrowerHash();

  @override
  String toString() {
    return r'borrowerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Borrower?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Borrower?> create(Ref ref) {
    final argument = this.argument as String;
    return borrower(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BorrowerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$borrowerHash() => r'e205d5566ff2606d1b83c29f108b4514b2796699';

/// One borrower of the active company (live; null when missing).

final class BorrowerFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Borrower?>, String> {
  BorrowerFamily._()
    : super(
        retry: null,
        name: r'borrowerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One borrower of the active company (live; null when missing).

  BorrowerProvider call(String borrowerId) =>
      BorrowerProvider._(argument: borrowerId, from: this);

  @override
  String toString() => r'borrowerProvider';
}

@ProviderFor(BorrowerQueryState)
final borrowerQueryStateProvider = BorrowerQueryStateProvider._();

final class BorrowerQueryStateProvider
    extends $NotifierProvider<BorrowerQueryState, BorrowerQuery> {
  BorrowerQueryStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'borrowerQueryStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$borrowerQueryStateHash();

  @$internal
  @override
  BorrowerQueryState create() => BorrowerQueryState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BorrowerQuery value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BorrowerQuery>(value),
    );
  }
}

String _$borrowerQueryStateHash() =>
    r'1b694c8281ddf5343484aa292b8620f5728f4015';

abstract class _$BorrowerQueryState extends $Notifier<BorrowerQuery> {
  BorrowerQuery build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<BorrowerQuery, BorrowerQuery>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BorrowerQuery, BorrowerQuery>,
              BorrowerQuery,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Every borrower with their list figures (no search applied).

@ProviderFor(borrowerItems)
final borrowerItemsProvider = BorrowerItemsProvider._();

/// Every borrower with their list figures (no search applied).

final class BorrowerItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BorrowerListItem>>,
          AsyncValue<List<BorrowerListItem>>,
          AsyncValue<List<BorrowerListItem>>
        >
    with $Provider<AsyncValue<List<BorrowerListItem>>> {
  /// Every borrower with their list figures (no search applied).
  BorrowerItemsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'borrowerItemsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$borrowerItemsHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<List<BorrowerListItem>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<List<BorrowerListItem>> create(Ref ref) {
    return borrowerItems(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<BorrowerListItem>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<BorrowerListItem>>>(
        value,
      ),
    );
  }
}

String _$borrowerItemsHash() => r'b1ebeb0055f2e6aa2f7fe556780283bbc3f9c544';

/// The borrower list after search text and filter chip.

@ProviderFor(borrowerSearch)
final borrowerSearchProvider = BorrowerSearchProvider._();

/// The borrower list after search text and filter chip.

final class BorrowerSearchProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BorrowerListItem>>,
          AsyncValue<List<BorrowerListItem>>,
          AsyncValue<List<BorrowerListItem>>
        >
    with $Provider<AsyncValue<List<BorrowerListItem>>> {
  /// The borrower list after search text and filter chip.
  BorrowerSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'borrowerSearchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$borrowerSearchHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<List<BorrowerListItem>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<List<BorrowerListItem>> create(Ref ref) {
    return borrowerSearch(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<BorrowerListItem>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<BorrowerListItem>>>(
        value,
      ),
    );
  }
}

String _$borrowerSearchHash() => r'91abc0cb490231fa682626e4ad3ad1b69d211f17';

/// A borrower's closed / rolled-over contracts (on demand).

@ProviderFor(borrowerHistoryContracts)
final borrowerHistoryContractsProvider = BorrowerHistoryContractsFamily._();

/// A borrower's closed / rolled-over contracts (on demand).

final class BorrowerHistoryContractsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Contract>>,
          List<Contract>,
          Stream<List<Contract>>
        >
    with $FutureModifier<List<Contract>>, $StreamProvider<List<Contract>> {
  /// A borrower's closed / rolled-over contracts (on demand).
  BorrowerHistoryContractsProvider._({
    required BorrowerHistoryContractsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'borrowerHistoryContractsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$borrowerHistoryContractsHash();

  @override
  String toString() {
    return r'borrowerHistoryContractsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Contract>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Contract>> create(Ref ref) {
    final argument = this.argument as String;
    return borrowerHistoryContracts(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BorrowerHistoryContractsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$borrowerHistoryContractsHash() =>
    r'99ddc4d802a4b9613d8ec0fdddc46e0c566158bd';

/// A borrower's closed / rolled-over contracts (on demand).

final class BorrowerHistoryContractsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Contract>>, String> {
  BorrowerHistoryContractsFamily._()
    : super(
        retry: null,
        name: r'borrowerHistoryContractsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A borrower's closed / rolled-over contracts (on demand).

  BorrowerHistoryContractsProvider call(String borrowerId) =>
      BorrowerHistoryContractsProvider._(argument: borrowerId, from: this);

  @override
  String toString() => r'borrowerHistoryContractsProvider';
}

/// Transactions of a borrower's inactive contracts (on demand).

@ProviderFor(borrowerHistoryTransactions)
final borrowerHistoryTransactionsProvider =
    BorrowerHistoryTransactionsFamily._();

/// Transactions of a borrower's inactive contracts (on demand).

final class BorrowerHistoryTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LedgerTransaction>>,
          List<LedgerTransaction>,
          Stream<List<LedgerTransaction>>
        >
    with
        $FutureModifier<List<LedgerTransaction>>,
        $StreamProvider<List<LedgerTransaction>> {
  /// Transactions of a borrower's inactive contracts (on demand).
  BorrowerHistoryTransactionsProvider._({
    required BorrowerHistoryTransactionsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'borrowerHistoryTransactionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$borrowerHistoryTransactionsHash();

  @override
  String toString() {
    return r'borrowerHistoryTransactionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<LedgerTransaction>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<LedgerTransaction>> create(Ref ref) {
    final argument = this.argument as String;
    return borrowerHistoryTransactions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BorrowerHistoryTransactionsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$borrowerHistoryTransactionsHash() =>
    r'698a30888532b951e257e06c5ed4608231ed6716';

/// Transactions of a borrower's inactive contracts (on demand).

final class BorrowerHistoryTransactionsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<LedgerTransaction>>, String> {
  BorrowerHistoryTransactionsFamily._()
    : super(
        retry: null,
        name: r'borrowerHistoryTransactionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Transactions of a borrower's inactive contracts (on demand).

  BorrowerHistoryTransactionsProvider call(String borrowerId) =>
      BorrowerHistoryTransactionsProvider._(argument: borrowerId, from: this);

  @override
  String toString() => r'borrowerHistoryTransactionsProvider';
}

/// Profile aggregates for one borrower. Loading until the active
/// projections are ready; history (closed contracts and their transactions)
/// joins in when its on-demand queries deliver.

@ProviderFor(borrowerSummary)
final borrowerSummaryProvider = BorrowerSummaryFamily._();

/// Profile aggregates for one borrower. Loading until the active
/// projections are ready; history (closed contracts and their transactions)
/// joins in when its on-demand queries deliver.

final class BorrowerSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<BorrowerSummary>,
          AsyncValue<BorrowerSummary>,
          AsyncValue<BorrowerSummary>
        >
    with $Provider<AsyncValue<BorrowerSummary>> {
  /// Profile aggregates for one borrower. Loading until the active
  /// projections are ready; history (closed contracts and their transactions)
  /// joins in when its on-demand queries deliver.
  BorrowerSummaryProvider._({
    required BorrowerSummaryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'borrowerSummaryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$borrowerSummaryHash();

  @override
  String toString() {
    return r'borrowerSummaryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AsyncValue<BorrowerSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<BorrowerSummary> create(Ref ref) {
    final argument = this.argument as String;
    return borrowerSummary(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<BorrowerSummary> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<BorrowerSummary>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BorrowerSummaryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$borrowerSummaryHash() => r'0e9f7959c18d877f2d6a143946ff3416817a1dde';

/// Profile aggregates for one borrower. Loading until the active
/// projections are ready; history (closed contracts and their transactions)
/// joins in when its on-demand queries deliver.

final class BorrowerSummaryFamily extends $Family
    with $FunctionalFamilyOverride<AsyncValue<BorrowerSummary>, String> {
  BorrowerSummaryFamily._()
    : super(
        retry: null,
        name: r'borrowerSummaryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Profile aggregates for one borrower. Loading until the active
  /// projections are ready; history (closed contracts and their transactions)
  /// joins in when its on-demand queries deliver.

  BorrowerSummaryProvider call(String borrowerId) =>
      BorrowerSummaryProvider._(argument: borrowerId, from: this);

  @override
  String toString() => r'borrowerSummaryProvider';
}

/// Borrower use-cases (owner only; the rules enforce it too).

@ProviderFor(borrowerActions)
final borrowerActionsProvider = BorrowerActionsProvider._();

/// Borrower use-cases (owner only; the rules enforce it too).

final class BorrowerActionsProvider
    extends
        $FunctionalProvider<BorrowerActions, BorrowerActions, BorrowerActions>
    with $Provider<BorrowerActions> {
  /// Borrower use-cases (owner only; the rules enforce it too).
  BorrowerActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'borrowerActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$borrowerActionsHash();

  @$internal
  @override
  $ProviderElement<BorrowerActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BorrowerActions create(Ref ref) {
    return borrowerActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BorrowerActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BorrowerActions>(value),
    );
  }
}

String _$borrowerActionsHash() => r'248eb220268735482bc2cb3442e6d1a80c97f706';

/// Dialer / WhatsApp launcher (overridden in tests).

@ProviderFor(contactLauncher)
final contactLauncherProvider = ContactLauncherProvider._();

/// Dialer / WhatsApp launcher (overridden in tests).

final class ContactLauncherProvider
    extends
        $FunctionalProvider<ContactLauncher, ContactLauncher, ContactLauncher>
    with $Provider<ContactLauncher> {
  /// Dialer / WhatsApp launcher (overridden in tests).
  ContactLauncherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contactLauncherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contactLauncherHash();

  @$internal
  @override
  $ProviderElement<ContactLauncher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ContactLauncher create(Ref ref) {
    return contactLauncher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContactLauncher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContactLauncher>(value),
    );
  }
}

String _$contactLauncherHash() => r'1fc292e52e19ad24c33a4c083e520e1dc6802b79';
