import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/time/clock_provider.dart';
import '../../../core/time/today_provider.dart';
import '../../../domain/ledger/ledger.dart';
import '../../../domain/models/models.dart';
import '../../company/application/company_providers.dart';
import '../../contracts/application/ledger_providers.dart';
import '../data/borrower_repository.dart';
import '../data/contact_launcher.dart';

part 'borrower_providers.g.dart';

@Riverpod(keepAlive: true)
BorrowerRepository borrowerRepository(Ref ref) => BorrowerRepository(
  firestore: ref.watch(firestoreProvider),
  clock: ref.watch(clockProvider),
);

/// The active company's non-archived borrowers, by name (live).
@Riverpod(keepAlive: true)
Stream<List<Borrower>> borrowers(Ref ref) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) return Stream<List<Borrower>>.value(const <Borrower>[]);
  return ref.watch(borrowerRepositoryProvider).watchBorrowers(cid);
}

/// One borrower of the active company (live; null when missing).
@riverpod
Stream<Borrower?> borrower(Ref ref, String borrowerId) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) return Stream<Borrower?>.value(null);
  return ref.watch(borrowerRepositoryProvider).watchBorrower(cid, borrowerId);
}

/// List filter chips.
enum BorrowerFilter {
  all('All'),
  active('Active only'),
  dueThisWeek('Due this week'),
  overdue('Overdue');

  const BorrowerFilter(this.label);

  final String label;
}

/// The search field text and the selected filter chip.
final class BorrowerQuery {
  const BorrowerQuery({this.text = '', this.filter = BorrowerFilter.all});

  final String text;
  final BorrowerFilter filter;
}

@Riverpod(keepAlive: true)
class BorrowerQueryState extends _$BorrowerQueryState {
  @override
  BorrowerQuery build() {
    ref.watch(
      activeCompanyIdProvider.select((AsyncValue<String?> v) => v.value),
    );
    return const BorrowerQuery();
  }

  void setText(String text) =>
      state = BorrowerQuery(text: text, filter: state.filter);

  void setFilter(BorrowerFilter filter) =>
      state = BorrowerQuery(text: state.text, filter: filter);
}

/// One row of the borrower list.
final class BorrowerListItem {
  const BorrowerListItem(this.borrower, this.stats);

  final Borrower borrower;
  final BorrowerListStats stats;
}

final RegExp _phoneQuery = RegExp(r'^[\d\s+\-()]+$');
final RegExp _nonDigit = RegExp(r'\D');

/// Whether [b] matches the search [text]: name (case-insensitive substring)
/// or, when the text looks like a phone number, the phone digits.
bool matchesBorrowerQuery(Borrower b, String text) {
  final q = text.trim();
  if (q.isEmpty) return true;
  if (_phoneQuery.hasMatch(q)) {
    final digits = q.replaceAll(_nonDigit, '');
    if (digits.isNotEmpty &&
        b.phoneE164.replaceAll(_nonDigit, '').contains(digits)) {
      return true;
    }
  }
  return b.nameLower.contains(q.toLowerCase());
}

/// Whether [stats] passes [filter].
bool matchesBorrowerFilter(BorrowerListStats stats, BorrowerFilter filter) =>
    switch (filter) {
      BorrowerFilter.all => true,
      BorrowerFilter.active => stats.activeCount > 0,
      BorrowerFilter.dueThisWeek => stats.dueThisWeek,
      BorrowerFilter.overdue => stats.standing == Standing.overdue,
    };

/// Every borrower with their list figures (no search applied).
@Riverpod(keepAlive: true)
AsyncValue<List<BorrowerListItem>> borrowerItems(Ref ref) {
  final list = ref.watch(borrowersProvider);
  final byBorrower = ref.watch(projectionsByBorrowerProvider);
  final today = ref.watch(todayProvider);
  return list.whenData(
    (List<Borrower> bs) => <BorrowerListItem>[
      for (final b in bs)
        BorrowerListItem(
          b,
          borrowerListStats(
            byBorrower[b.id] ?? const <ContractProjection>[],
            today,
          ),
        ),
    ],
  );
}

/// The borrower list after search text and filter chip.
@Riverpod(keepAlive: true)
AsyncValue<List<BorrowerListItem>> borrowerSearch(Ref ref) {
  final query = ref.watch(borrowerQueryStateProvider);
  return ref
      .watch(borrowerItemsProvider)
      .whenData(
        (List<BorrowerListItem> items) => <BorrowerListItem>[
          for (final i in items)
            if (matchesBorrowerQuery(i.borrower, query.text) &&
                matchesBorrowerFilter(i.stats, query.filter))
              i,
        ],
      );
}

/// A borrower's closed / rolled-over contracts (on demand).
@riverpod
Stream<List<Contract>> borrowerHistoryContracts(Ref ref, String borrowerId) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) return Stream<List<Contract>>.value(const <Contract>[]);
  return ref
      .watch(ledgerSnapshotRepositoryProvider)
      .watchBorrowerHistoryContracts(cid, borrowerId);
}

/// Transactions of a borrower's inactive contracts (on demand).
@riverpod
Stream<List<LedgerTransaction>> borrowerHistoryTransactions(
  Ref ref,
  String borrowerId,
) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) {
    return Stream<List<LedgerTransaction>>.value(const <LedgerTransaction>[]);
  }
  return ref
      .watch(ledgerSnapshotRepositoryProvider)
      .watchBorrowerHistoryTransactions(cid, borrowerId);
}

/// Profile aggregates for one borrower. Loading until the active
/// projections are ready; history (closed contracts and their transactions)
/// joins in when its on-demand queries deliver.
@riverpod
AsyncValue<BorrowerSummary> borrowerSummary(Ref ref, String borrowerId) {
  final projections = ref.watch(activeProjectionsProvider);
  final activeTx = ref.watch(activeTransactionsProvider);
  final history = ref.watch(borrowerHistoryContractsProvider(borrowerId));
  final historyTx = ref.watch(borrowerHistoryTransactionsProvider(borrowerId));
  final today = ref.watch(todayProvider);
  if (projections.hasError) {
    return AsyncError<BorrowerSummary>(
      projections.error!,
      projections.stackTrace ?? StackTrace.current,
    );
  }
  final map = projections.value;
  if (map == null || projections.isLoading) {
    return const AsyncLoading<BorrowerSummary>();
  }
  final active = <ContractProjection>[
    for (final p in map.values)
      if (p.contract.borrowerId == borrowerId) p,
  ];
  return AsyncData<BorrowerSummary>(
    summarizeBorrower(
      active: active,
      contracts: history.value ?? const <Contract>[],
      transactions: <LedgerTransaction>[
        for (final t in activeTx.value ?? const <LedgerTransaction>[])
          if (t.borrowerId == borrowerId) t,
        ...?historyTx.value,
      ],
      today: today,
    ),
  );
}

/// Borrower use-cases (owner only; the rules enforce it too).
@Riverpod(keepAlive: true)
BorrowerActions borrowerActions(Ref ref) => BorrowerActions(ref);

class BorrowerActions {
  BorrowerActions(this._ref);

  final Ref _ref;

  String get _cid {
    final cid = _ref.read(activeCompanyIdProvider).value;
    if (cid == null) throw StateError('No active company');
    return cid;
  }

  Future<BorrowerCreated> create({
    required String name,
    required String phone,
    String? locality,
    String? notes,
  }) {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) throw StateError('Not signed in');
    return _ref
        .read(borrowerRepositoryProvider)
        .createBorrower(
          cid: _cid,
          name: name,
          phone: phone,
          locality: locality,
          notes: notes,
          createdBy: uid,
        );
  }

  Future<WriteOutcome> update({
    required String id,
    required String name,
    required String phone,
    String? locality,
    String? notes,
  }) => _ref
      .read(borrowerRepositoryProvider)
      .updateBorrower(
        cid: _cid,
        id: id,
        name: name,
        phone: phone,
        locality: locality,
        notes: notes,
      );

  Future<WriteOutcome> archive(String id) =>
      _ref.read(borrowerRepositoryProvider).archiveBorrower(_cid, id);
}

/// Dialer / WhatsApp launcher (overridden in tests).
@Riverpod(keepAlive: true)
ContactLauncher contactLauncher(Ref ref) => ContactLauncher();
