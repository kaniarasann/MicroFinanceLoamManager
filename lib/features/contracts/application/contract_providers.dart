import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/time/clock_provider.dart';
import '../../../core/time/today_provider.dart';
import '../../../domain/ledger/ledger.dart';
import '../../../domain/models/models.dart';
import '../../auth/application/device_id_provider.dart';
import '../../auth/application/session_controller.dart';
import '../../company/application/company_providers.dart';
import '../data/contract_repository.dart';
import 'contract_draft.dart';
import 'ledger_providers.dart';

part 'contract_providers.g.dart';

@Riverpod(keepAlive: true)
ContractRepository contractRepository(Ref ref) => ContractRepository(
  firestore: ref.watch(firestoreProvider),
  clock: ref.watch(clockProvider),
);

/// One contract of the active company, any status (live).
@riverpod
Stream<Contract?> contractDoc(Ref ref, String contractId) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) return Stream<Contract?>.value(null);
  return ref
      .watch(ledgerSnapshotRepositoryProvider)
      .watchContract(cid, contractId);
}

/// One contract's stored installments (live).
@riverpod
Stream<List<Installment>> contractInstallments(Ref ref, String contractId) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) {
    return Stream<List<Installment>>.value(const <Installment>[]);
  }
  return ref
      .watch(ledgerSnapshotRepositoryProvider)
      .watchContractInstallments(cid, contractId);
}

/// One contract's transactions (live).
@riverpod
Stream<List<LedgerTransaction>> contractTransactions(
  Ref ref,
  String contractId,
) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) {
    return Stream<List<LedgerTransaction>>.value(const <LedgerTransaction>[]);
  }
  return ref
      .watch(ledgerSnapshotRepositoryProvider)
      .watchContractTransactions(cid, contractId);
}

/// Everything the contract detail screen renders.
final class ContractView {
  ContractView({
    required this.projection,
    required List<Installment> installments,
    required this.transactions,
  }) : installments = <String, Installment>{
         for (final i in installments) i.id: i,
       },
       settlements = rowSettlements(projection, transactions);

  final ContractProjection projection;

  /// Stored installments by id.
  final Map<String, Installment> installments;
  final List<LedgerTransaction> transactions;

  /// Paid rows' cleared date and mode, by installment id.
  final Map<String, RowSettlement> settlements;

  Contract get contract => projection.contract;

  /// Highest stored seq.
  int get maxSeq => installments.values.fold<int>(
    0,
    (int m, Installment i) => i.seq > m ? i.seq : m,
  );

  /// Target dates of the rows moved out of installment [id].
  List<CivilDate> movedTo(String id) => <CivilDate>[
    for (final i in installments.values)
      if (i.rescheduledFromId == id) i.dueDate,
  ]..sort();

  /// Seq of installment [id] (for "Moved from Inst. N").
  int? seqOf(String? id) => id == null ? null : installments[id]?.seq;

  /// "Immediate action" amount: overdue shortfall, else what is due today.
  Money get immediate {
    final p = projection;
    if (p.hasOverdue) return p.overdueAmount;
    final dueToday = p.rows.where(
      (ProjectedRow r) => r.status == RowStatus.dueToday,
    );
    return Money.sum(dueToday.map((ProjectedRow r) => r.remaining));
  }
}

/// The projected contract (any status) with its docs. Data(null) when the
/// contract does not exist.
@riverpod
AsyncValue<ContractView?> contractView(Ref ref, String contractId) {
  final contract = ref.watch(contractDocProvider(contractId));
  final inst = ref.watch(contractInstallmentsProvider(contractId));
  final txs = ref.watch(contractTransactionsProvider(contractId));
  final today = ref.watch(todayProvider);
  for (final AsyncValue<Object?> v in <AsyncValue<Object?>>[
    contract,
    inst,
    txs,
  ]) {
    if (v.hasError) {
      return AsyncError<ContractView?>(
        v.error!,
        v.stackTrace ?? StackTrace.current,
      );
    }
    if (!v.hasValue) return const AsyncLoading<ContractView?>();
  }
  final c = contract.requireValue;
  if (c == null) return const AsyncData<ContractView?>(null);
  final installments = inst.requireValue;
  final transactions = txs.requireValue;
  return AsyncData<ContractView?>(
    ContractView(
      projection: projectContract(
        contract: c,
        installments: installments,
        transactions: transactions,
        today: today,
      ),
      installments: installments,
      transactions: transactions,
    ),
  );
}

/// Timeline filter chips.
enum TimelineFilter {
  all('All'),
  missed('Missed'),
  upcoming('Upcoming'),
  paid('Paid');

  const TimelineFilter(this.label);

  final String label;

  bool matches(ProjectedRow r) => switch (this) {
    TimelineFilter.all => true,
    TimelineFilter.missed => r.status == RowStatus.overdue,
    TimelineFilter.upcoming =>
      r.status == RowStatus.dueToday ||
          r.status == RowStatus.upcoming ||
          r.status == RowStatus.planned,
    TimelineFilter.paid => r.status == RowStatus.paid,
  };
}

/// `recordedByName` for ledger writes: the member doc's display name, else
/// the signed-in account's.
@Riverpod(keepAlive: true)
String ledgerActorName(Ref ref) =>
    ref.watch(currentMemberProvider)?.displayName ??
    ref.watch(
      sessionControllerProvider.select((SessionState s) => s.user?.displayName),
    ) ??
    '';

/// The active company id for a ledger write (throws when none).
String requireActiveCid(Ref ref) {
  final cid = ref.read(activeCompanyIdProvider).value;
  if (cid == null) throw StateError('No active company');
  return cid;
}

/// Who is writing now: uid, `recordedByName` and this install's device id.
Future<LedgerActor> readLedgerActor(Ref ref) async {
  final uid = ref.read(currentUidProvider);
  if (uid == null) throw StateError('Not signed in');
  final name = ref.read(ledgerActorNameProvider);
  final device = await ref.read(deviceIdProvider.future);
  return LedgerActor(uid: uid, name: name, deviceId: device);
}

/// Contract use-cases. Create is owner only; reschedule is owner or
/// collector (the rules enforce both).
@Riverpod(keepAlive: true)
ContractActions contractActions(Ref ref) => ContractActions(ref);

class ContractActions {
  ContractActions(this._ref);

  final Ref _ref;

  String get _cid => requireActiveCid(_ref);

  Future<LedgerActor> _actor() => readLedgerActor(_ref);

  Future<LedgerWriteResult> create({
    required Borrower borrower,
    required ContractDraft draft,
    String? guarantor,
    String? notes,
    String? purpose,
  }) async {
    final actor = await _actor();
    final company = _ref.read(activeCompanyProvider).value;
    return _ref
        .read(contractRepositoryProvider)
        .createContract(
          CreateContractCommand(
            cid: _cid,
            borrower: borrower,
            sanctioned: draft.sanctioned ?? Money.zero,
            upfrontMode: draft.upfrontMode,
            upfrontInput: draft.upfrontInput ?? 0,
            installmentAmount: draft.installmentAmount ?? Money.zero,
            frequency: draft.frequency,
            preferredWeekday: draft.weekday,
            preferredMonthDay: draft.monthDay,
            firstDueDate: draft.firstDueDate,
            disbursedOn: draft.disbursedOn,
            cachedNextLoanNo: company?.nextLoanNo ?? 0,
            actor: actor,
            guarantor: guarantor,
            notes: notes,
            purpose: purpose,
          ),
        );
  }

  Future<LedgerWriteResult> reschedule({
    required ContractView view,
    required ProjectedRow row,
    required Money amount,
    required CivilDate newDueDate,
    String? note,
  }) async {
    final source = view.installments[row.installmentId];
    if (source == null) throw StateError('Only stored rows can be moved');
    final actor = await _actor();
    return _ref
        .read(contractRepositoryProvider)
        .reschedule(
          RescheduleCommand(
            cid: _cid,
            source: source,
            amount: amount,
            newDueDate: newDueDate,
            remaining: row.remaining,
            maxSeq: view.maxSeq,
            today: _ref.read(todayProvider),
            actor: actor,
            note: note,
          ),
        );
  }
}
