import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/time/today_provider.dart';
import '../../../domain/ledger/ledger.dart';
import '../../../domain/models/models.dart';
import '../../company/application/company_providers.dart';
import '../data/ledger_snapshot_repository.dart';

part 'ledger_providers.g.dart';

@Riverpod(keepAlive: true)
LedgerSnapshotRepository ledgerSnapshotRepository(Ref ref) =>
    LedgerSnapshotRepository(firestore: ref.watch(firestoreProvider));

/// The active company's active contracts (live).
@Riverpod(keepAlive: true)
Stream<List<Contract>> activeContracts(Ref ref) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) return Stream<List<Contract>>.value(const <Contract>[]);
  return ref.watch(ledgerSnapshotRepositoryProvider).watchActiveContracts(cid);
}

/// The active company's installments of active contracts (live).
@Riverpod(keepAlive: true)
Stream<List<Installment>> activeInstallments(Ref ref) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) {
    return Stream<List<Installment>>.value(const <Installment>[]);
  }
  return ref
      .watch(ledgerSnapshotRepositoryProvider)
      .watchActiveInstallments(cid);
}

/// The active company's transactions of active contracts (live).
@Riverpod(keepAlive: true)
Stream<List<LedgerTransaction>> activeTransactions(Ref ref) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) {
    return Stream<List<LedgerTransaction>>.value(const <LedgerTransaction>[]);
  }
  return ref
      .watch(ledgerSnapshotRepositoryProvider)
      .watchActiveTransactions(cid);
}

/// Per-contract memo for [activeProjectionsProvider]: a contract is
/// re-projected only when its contract doc, its installments, its
/// transactions or today's date changed. Otherwise the previous
/// [ContractProjection] instance is returned as is.
final class ProjectionMemo {
  final Map<String, _MemoEntry> _entries = <String, _MemoEntry>{};

  /// How many projections were computed (for tests and diagnostics).
  int computeCount = 0;

  Map<String, ContractProjection> project({
    required List<Contract> contracts,
    required List<Installment> installments,
    required List<LedgerTransaction> transactions,
    required CivilDate today,
  }) {
    final instBy = <String, List<Installment>>{};
    for (final i in installments) {
      (instBy[i.contractId] ??= <Installment>[]).add(i);
    }
    final txBy = <String, List<LedgerTransaction>>{};
    for (final t in transactions) {
      (txBy[t.contractId] ??= <LedgerTransaction>[]).add(t);
    }
    final out = <String, ContractProjection>{};
    final seen = <String>{};
    for (final c in contracts) {
      seen.add(c.id);
      final inst = (instBy[c.id] ?? <Installment>[])
        ..sort((Installment a, Installment b) => a.id.compareTo(b.id));
      final txs = (txBy[c.id] ?? <LedgerTransaction>[])
        ..sort(
          (LedgerTransaction a, LedgerTransaction b) => a.id.compareTo(b.id),
        );
      final cached = _entries[c.id];
      if (cached != null &&
          cached.today == today &&
          cached.contract == c &&
          _sameList(cached.installments, inst) &&
          _sameList(cached.transactions, txs)) {
        out[c.id] = cached.projection;
        continue;
      }
      computeCount++;
      final projection = projectContract(
        contract: c,
        installments: inst,
        transactions: txs,
        today: today,
      );
      _entries[c.id] = _MemoEntry(c, inst, txs, today, projection);
      out[c.id] = projection;
    }
    _entries.removeWhere((String id, _MemoEntry _) => !seen.contains(id));
    return Map<String, ContractProjection>.unmodifiable(out);
  }

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final class _MemoEntry {
  const _MemoEntry(
    this.contract,
    this.installments,
    this.transactions,
    this.today,
    this.projection,
  );

  final Contract contract;
  final List<Installment> installments;
  final List<LedgerTransaction> transactions;
  final CivilDate today;
  final ContractProjection projection;
}

/// One memo per active company.
@Riverpod(keepAlive: true)
ProjectionMemo projectionMemo(Ref ref) {
  ref.watch(activeCompanyIdProvider.select((AsyncValue<String?> v) => v.value));
  return ProjectionMemo();
}

/// Projections of the active company's active contracts, keyed by contract
/// id. Loading until all three live listeners have delivered for the
/// current company. Recomputes per contract (see [ProjectionMemo]) on any
/// snapshot change and when [todayProvider] ticks (IST midnight / resume).
@Riverpod(keepAlive: true)
AsyncValue<Map<String, ContractProjection>> activeProjections(Ref ref) {
  final contracts = ref.watch(activeContractsProvider);
  final installments = ref.watch(activeInstallmentsProvider);
  final transactions = ref.watch(activeTransactionsProvider);
  final today = ref.watch(todayProvider);
  final memo = ref.watch(projectionMemoProvider);
  for (final AsyncValue<Object?> v in <AsyncValue<Object?>>[
    contracts,
    installments,
    transactions,
  ]) {
    if (v.hasError) {
      return AsyncError<Map<String, ContractProjection>>(
        v.error!,
        v.stackTrace ?? StackTrace.current,
      );
    }
  }
  // isLoading also covers a company switch, where the previous company's
  // value is still attached to the loading state.
  if (contracts.isLoading ||
      installments.isLoading ||
      transactions.isLoading ||
      !contracts.hasValue ||
      !installments.hasValue ||
      !transactions.hasValue) {
    return const AsyncLoading<Map<String, ContractProjection>>();
  }
  return AsyncData<Map<String, ContractProjection>>(
    memo.project(
      contracts: contracts.requireValue,
      installments: installments.requireValue,
      transactions: transactions.requireValue,
      today: today,
    ),
  );
}

/// Active projections grouped by borrower id.
@Riverpod(keepAlive: true)
Map<String, List<ContractProjection>> projectionsByBorrower(Ref ref) {
  final map = ref.watch(activeProjectionsProvider).value;
  final out = <String, List<ContractProjection>>{};
  if (map == null) return out;
  for (final p in map.values) {
    (out[p.contract.borrowerId] ??= <ContractProjection>[]).add(p);
  }
  return out;
}
