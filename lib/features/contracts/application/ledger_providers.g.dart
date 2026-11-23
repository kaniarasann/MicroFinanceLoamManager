// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ledger_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ledgerSnapshotRepository)
final ledgerSnapshotRepositoryProvider = LedgerSnapshotRepositoryProvider._();

final class LedgerSnapshotRepositoryProvider
    extends
        $FunctionalProvider<
          LedgerSnapshotRepository,
          LedgerSnapshotRepository,
          LedgerSnapshotRepository
        >
    with $Provider<LedgerSnapshotRepository> {
  LedgerSnapshotRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ledgerSnapshotRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ledgerSnapshotRepositoryHash();

  @$internal
  @override
  $ProviderElement<LedgerSnapshotRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LedgerSnapshotRepository create(Ref ref) {
    return ledgerSnapshotRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LedgerSnapshotRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LedgerSnapshotRepository>(value),
    );
  }
}

String _$ledgerSnapshotRepositoryHash() =>
    r'641ab3179445e806745e06cdfe2f2800a763aaca';

/// The active company's active contracts (live).

@ProviderFor(activeContracts)
final activeContractsProvider = ActiveContractsProvider._();

/// The active company's active contracts (live).

final class ActiveContractsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Contract>>,
          List<Contract>,
          Stream<List<Contract>>
        >
    with $FutureModifier<List<Contract>>, $StreamProvider<List<Contract>> {
  /// The active company's active contracts (live).
  ActiveContractsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeContractsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeContractsHash();

  @$internal
  @override
  $StreamProviderElement<List<Contract>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Contract>> create(Ref ref) {
    return activeContracts(ref);
  }
}

String _$activeContractsHash() => r'a04ecb0a514b9ac500a49d02c6f9182d7d0ad3a4';

/// The active company's installments of active contracts (live).

@ProviderFor(activeInstallments)
final activeInstallmentsProvider = ActiveInstallmentsProvider._();

/// The active company's installments of active contracts (live).

final class ActiveInstallmentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Installment>>,
          List<Installment>,
          Stream<List<Installment>>
        >
    with
        $FutureModifier<List<Installment>>,
        $StreamProvider<List<Installment>> {
  /// The active company's installments of active contracts (live).
  ActiveInstallmentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeInstallmentsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeInstallmentsHash();

  @$internal
  @override
  $StreamProviderElement<List<Installment>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Installment>> create(Ref ref) {
    return activeInstallments(ref);
  }
}

String _$activeInstallmentsHash() =>
    r'10c89007451180d955b39dc7c293c143796fc6d3';

/// The active company's transactions of active contracts (live).

@ProviderFor(activeTransactions)
final activeTransactionsProvider = ActiveTransactionsProvider._();

/// The active company's transactions of active contracts (live).

final class ActiveTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LedgerTransaction>>,
          List<LedgerTransaction>,
          Stream<List<LedgerTransaction>>
        >
    with
        $FutureModifier<List<LedgerTransaction>>,
        $StreamProvider<List<LedgerTransaction>> {
  /// The active company's transactions of active contracts (live).
  ActiveTransactionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeTransactionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeTransactionsHash();

  @$internal
  @override
  $StreamProviderElement<List<LedgerTransaction>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<LedgerTransaction>> create(Ref ref) {
    return activeTransactions(ref);
  }
}

String _$activeTransactionsHash() =>
    r'940c8599b5022b9a2519877ba57565fee5d64943';

/// One memo per active company.

@ProviderFor(projectionMemo)
final projectionMemoProvider = ProjectionMemoProvider._();

/// One memo per active company.

final class ProjectionMemoProvider
    extends $FunctionalProvider<ProjectionMemo, ProjectionMemo, ProjectionMemo>
    with $Provider<ProjectionMemo> {
  /// One memo per active company.
  ProjectionMemoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectionMemoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectionMemoHash();

  @$internal
  @override
  $ProviderElement<ProjectionMemo> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ProjectionMemo create(Ref ref) {
    return projectionMemo(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectionMemo value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectionMemo>(value),
    );
  }
}

String _$projectionMemoHash() => r'a2109f2ca5a4002696a17492184a2a18bb1a88de';

/// Projections of the active company's active contracts, keyed by contract
/// id. Loading until all three live listeners have delivered for the
/// current company. Recomputes per contract (see [ProjectionMemo]) on any
/// snapshot change and when [todayProvider] ticks (IST midnight / resume).

@ProviderFor(activeProjections)
final activeProjectionsProvider = ActiveProjectionsProvider._();

/// Projections of the active company's active contracts, keyed by contract
/// id. Loading until all three live listeners have delivered for the
/// current company. Recomputes per contract (see [ProjectionMemo]) on any
/// snapshot change and when [todayProvider] ticks (IST midnight / resume).

final class ActiveProjectionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, ContractProjection>>,
          AsyncValue<Map<String, ContractProjection>>,
          AsyncValue<Map<String, ContractProjection>>
        >
    with $Provider<AsyncValue<Map<String, ContractProjection>>> {
  /// Projections of the active company's active contracts, keyed by contract
  /// id. Loading until all three live listeners have delivered for the
  /// current company. Recomputes per contract (see [ProjectionMemo]) on any
  /// snapshot change and when [todayProvider] ticks (IST midnight / resume).
  ActiveProjectionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeProjectionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeProjectionsHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<Map<String, ContractProjection>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<Map<String, ContractProjection>> create(Ref ref) {
    return activeProjections(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    AsyncValue<Map<String, ContractProjection>> value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<AsyncValue<Map<String, ContractProjection>>>(
            value,
          ),
    );
  }
}

String _$activeProjectionsHash() => r'd295999a42552c0c2c71c37c740c965736d05892';

/// Active projections grouped by borrower id.

@ProviderFor(projectionsByBorrower)
final projectionsByBorrowerProvider = ProjectionsByBorrowerProvider._();

/// Active projections grouped by borrower id.

final class ProjectionsByBorrowerProvider
    extends
        $FunctionalProvider<
          Map<String, List<ContractProjection>>,
          Map<String, List<ContractProjection>>,
          Map<String, List<ContractProjection>>
        >
    with $Provider<Map<String, List<ContractProjection>>> {
  /// Active projections grouped by borrower id.
  ProjectionsByBorrowerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectionsByBorrowerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectionsByBorrowerHash();

  @$internal
  @override
  $ProviderElement<Map<String, List<ContractProjection>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, List<ContractProjection>> create(Ref ref) {
    return projectionsByBorrower(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, List<ContractProjection>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<Map<String, List<ContractProjection>>>(value),
    );
  }
}

String _$projectionsByBorrowerHash() =>
    r'60c2e3fd724c9053f455dd90ee46d0ea9d30be37';
