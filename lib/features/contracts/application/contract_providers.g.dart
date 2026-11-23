// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contract_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(contractRepository)
final contractRepositoryProvider = ContractRepositoryProvider._();

final class ContractRepositoryProvider
    extends
        $FunctionalProvider<
          ContractRepository,
          ContractRepository,
          ContractRepository
        >
    with $Provider<ContractRepository> {
  ContractRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contractRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contractRepositoryHash();

  @$internal
  @override
  $ProviderElement<ContractRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ContractRepository create(Ref ref) {
    return contractRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContractRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContractRepository>(value),
    );
  }
}

String _$contractRepositoryHash() =>
    r'e4ed9a95471c4d250f986d02459ecca3142ae28e';

/// One contract of the active company, any status (live).

@ProviderFor(contractDoc)
final contractDocProvider = ContractDocFamily._();

/// One contract of the active company, any status (live).

final class ContractDocProvider
    extends
        $FunctionalProvider<AsyncValue<Contract?>, Contract?, Stream<Contract?>>
    with $FutureModifier<Contract?>, $StreamProvider<Contract?> {
  /// One contract of the active company, any status (live).
  ContractDocProvider._({
    required ContractDocFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'contractDocProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$contractDocHash();

  @override
  String toString() {
    return r'contractDocProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Contract?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Contract?> create(Ref ref) {
    final argument = this.argument as String;
    return contractDoc(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ContractDocProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$contractDocHash() => r'9ee256223c106aea9c2d2b9916e2e66e168221c0';

/// One contract of the active company, any status (live).

final class ContractDocFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Contract?>, String> {
  ContractDocFamily._()
    : super(
        retry: null,
        name: r'contractDocProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One contract of the active company, any status (live).

  ContractDocProvider call(String contractId) =>
      ContractDocProvider._(argument: contractId, from: this);

  @override
  String toString() => r'contractDocProvider';
}

/// One contract's stored installments (live).

@ProviderFor(contractInstallments)
final contractInstallmentsProvider = ContractInstallmentsFamily._();

/// One contract's stored installments (live).

final class ContractInstallmentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Installment>>,
          List<Installment>,
          Stream<List<Installment>>
        >
    with
        $FutureModifier<List<Installment>>,
        $StreamProvider<List<Installment>> {
  /// One contract's stored installments (live).
  ContractInstallmentsProvider._({
    required ContractInstallmentsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'contractInstallmentsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$contractInstallmentsHash();

  @override
  String toString() {
    return r'contractInstallmentsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Installment>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Installment>> create(Ref ref) {
    final argument = this.argument as String;
    return contractInstallments(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ContractInstallmentsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$contractInstallmentsHash() =>
    r'5a3d70cf9d01d487c048d1f8146650f21fc8bdc0';

/// One contract's stored installments (live).

final class ContractInstallmentsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Installment>>, String> {
  ContractInstallmentsFamily._()
    : super(
        retry: null,
        name: r'contractInstallmentsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One contract's stored installments (live).

  ContractInstallmentsProvider call(String contractId) =>
      ContractInstallmentsProvider._(argument: contractId, from: this);

  @override
  String toString() => r'contractInstallmentsProvider';
}

/// One contract's transactions (live).

@ProviderFor(contractTransactions)
final contractTransactionsProvider = ContractTransactionsFamily._();

/// One contract's transactions (live).

final class ContractTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LedgerTransaction>>,
          List<LedgerTransaction>,
          Stream<List<LedgerTransaction>>
        >
    with
        $FutureModifier<List<LedgerTransaction>>,
        $StreamProvider<List<LedgerTransaction>> {
  /// One contract's transactions (live).
  ContractTransactionsProvider._({
    required ContractTransactionsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'contractTransactionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$contractTransactionsHash();

  @override
  String toString() {
    return r'contractTransactionsProvider'
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
    return contractTransactions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ContractTransactionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$contractTransactionsHash() =>
    r'2ddd5f5538d2d48712a5fef6f2047fd97c909009';

/// One contract's transactions (live).

final class ContractTransactionsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<LedgerTransaction>>, String> {
  ContractTransactionsFamily._()
    : super(
        retry: null,
        name: r'contractTransactionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One contract's transactions (live).

  ContractTransactionsProvider call(String contractId) =>
      ContractTransactionsProvider._(argument: contractId, from: this);

  @override
  String toString() => r'contractTransactionsProvider';
}

/// The projected contract (any status) with its docs. Data(null) when the
/// contract does not exist.

@ProviderFor(contractView)
final contractViewProvider = ContractViewFamily._();

/// The projected contract (any status) with its docs. Data(null) when the
/// contract does not exist.

final class ContractViewProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContractView?>,
          AsyncValue<ContractView?>,
          AsyncValue<ContractView?>
        >
    with $Provider<AsyncValue<ContractView?>> {
  /// The projected contract (any status) with its docs. Data(null) when the
  /// contract does not exist.
  ContractViewProvider._({
    required ContractViewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'contractViewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$contractViewHash();

  @override
  String toString() {
    return r'contractViewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AsyncValue<ContractView?>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<ContractView?> create(Ref ref) {
    final argument = this.argument as String;
    return contractView(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<ContractView?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<ContractView?>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ContractViewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$contractViewHash() => r'61170881df180482e0d7e69f473e7d3a4f479158';

/// The projected contract (any status) with its docs. Data(null) when the
/// contract does not exist.

final class ContractViewFamily extends $Family
    with $FunctionalFamilyOverride<AsyncValue<ContractView?>, String> {
  ContractViewFamily._()
    : super(
        retry: null,
        name: r'contractViewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The projected contract (any status) with its docs. Data(null) when the
  /// contract does not exist.

  ContractViewProvider call(String contractId) =>
      ContractViewProvider._(argument: contractId, from: this);

  @override
  String toString() => r'contractViewProvider';
}

/// `recordedByName` for ledger writes: the member doc's display name, else
/// the signed-in account's.

@ProviderFor(ledgerActorName)
final ledgerActorNameProvider = LedgerActorNameProvider._();

/// `recordedByName` for ledger writes: the member doc's display name, else
/// the signed-in account's.

final class LedgerActorNameProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// `recordedByName` for ledger writes: the member doc's display name, else
  /// the signed-in account's.
  LedgerActorNameProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ledgerActorNameProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ledgerActorNameHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return ledgerActorName(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$ledgerActorNameHash() => r'02913c08c4627759651519e636a7ab4fbef09344';

/// Contract use-cases. Create is owner only; reschedule is owner or
/// collector (the rules enforce both).

@ProviderFor(contractActions)
final contractActionsProvider = ContractActionsProvider._();

/// Contract use-cases. Create is owner only; reschedule is owner or
/// collector (the rules enforce both).

final class ContractActionsProvider
    extends
        $FunctionalProvider<ContractActions, ContractActions, ContractActions>
    with $Provider<ContractActions> {
  /// Contract use-cases. Create is owner only; reschedule is owner or
  /// collector (the rules enforce both).
  ContractActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contractActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contractActionsHash();

  @$internal
  @override
  $ProviderElement<ContractActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ContractActions create(Ref ref) {
    return contractActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContractActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContractActions>(value),
    );
  }
}

String _$contractActionsHash() => r'07eb9f9e3cd77ad80d1575aab307f8ea7570f1a5';
