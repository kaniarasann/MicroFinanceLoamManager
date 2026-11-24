import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/converters.dart';
import '../../../core/time/civil_date.dart';
import '../../../domain/models/models.dart';

/// Read side of the ledger, shared by Borrowers, Contracts, Dashboard,
/// Calendar and Overdue (Section 2, "Offline-first data flow").
///
/// - Live, company-scoped listeners for the working set:
///   [watchActiveContracts], [watchActiveInstallments],
///   [watchActiveTransactions]. Persistence serves them offline.
/// - On-demand queries for history: a borrower's closed / rolled-over
///   contracts and their transactions, and one contract's docs (any
///   status).
///
/// No aggregation queries: every figure is computed from these snapshots by
/// `lib/domain/ledger/`.
class LedgerSnapshotRepository {
  LedgerSnapshotRepository({required FirebaseFirestore firestore})
    : _refs = TypedRefs(firestore);

  final TypedRefs _refs;

  /// Statuses that count as history (closed tab).
  static const List<String> historyStatuses = <String>['closed', 'rolledOver'];

  static List<T> _docs<T>(QuerySnapshot<T> s) => <T>[
    for (final d in s.docs) d.data(),
  ];

  // ------------------------------------------------------ live working set

  /// `contracts` where `status == 'active'`.
  Stream<List<Contract>> watchActiveContracts(String cid) => _refs
      .contracts(cid)
      .where('status', isEqualTo: ContractStatus.active.name)
      .snapshots()
      .map(_docs);

  /// `installments` where `contractActive == true`.
  Stream<List<Installment>> watchActiveInstallments(String cid) => _refs
      .installments(cid)
      .where('contractActive', isEqualTo: true)
      .snapshots()
      .map(_docs);

  /// `transactions` where `contractActive == true`.
  Stream<List<LedgerTransaction>> watchActiveTransactions(String cid) => _refs
      .transactions(cid)
      .where('contractActive', isEqualTo: true)
      .snapshots()
      .map(_docs);

  // ------------------------------------------------------ dashboard history

  /// The company's closed and rolled-over contracts (single-field `in`
  /// query, no composite index). Feeds lifetime net disbursed / collected
  /// and the "Excess to review" indicator.
  Stream<List<Contract>> watchHistoryContracts(String cid) => _refs
      .contracts(cid)
      .where('status', whereIn: historyStatuses)
      .snapshots()
      .map(_docs);

  /// Transactions of inactive contracts with `paidOn >= since` (the chart
  /// window). Served by the existing (contractActive ASC, paidOn DESC)
  /// index.
  Stream<List<LedgerTransaction>> watchHistoryTransactions(
    String cid,
    CivilDate since,
  ) => _refs
      .transactions(cid)
      .where('contractActive', isEqualTo: false)
      .where('paidOn', isGreaterThanOrEqualTo: since.toString())
      .orderBy('paidOn', descending: true)
      .snapshots()
      .map(_docs);

  /// Installments of inactive contracts with `dueDate >= since` (the
  /// chart window). Served by the existing (contractActive ASC, dueDate
  /// ASC) index.
  Stream<List<Installment>> watchHistoryInstallments(
    String cid,
    CivilDate since,
  ) => _refs
      .installments(cid)
      .where('contractActive', isEqualTo: false)
      .where('dueDate', isGreaterThanOrEqualTo: since.toString())
      .orderBy('dueDate')
      .snapshots()
      .map(_docs);

  // ------------------------------------------------------ on demand

  /// A borrower's closed and rolled-over contracts.
  Stream<List<Contract>> watchBorrowerHistoryContracts(
    String cid,
    String borrowerId,
  ) => _refs
      .contracts(cid)
      .where('borrowerId', isEqualTo: borrowerId)
      .where('status', whereIn: historyStatuses)
      .snapshots()
      .map(_docs);

  /// Transactions of a borrower's inactive (closed / rolled-over)
  /// contracts. Active ones come from [watchActiveTransactions].
  Stream<List<LedgerTransaction>> watchBorrowerHistoryTransactions(
    String cid,
    String borrowerId,
  ) => _refs
      .transactions(cid)
      .where('borrowerId', isEqualTo: borrowerId)
      .where('contractActive', isEqualTo: false)
      .snapshots()
      .map(_docs);

  /// One contract, any status (null when missing).
  Stream<Contract?> watchContract(String cid, String contractId) => _refs
      .contract(cid, contractId)
      .snapshots()
      .map((DocumentSnapshot<Contract> s) => s.exists ? s.data() : null);

  /// One contract's installments, any status.
  Stream<List<Installment>> watchContractInstallments(
    String cid,
    String contractId,
  ) => _refs
      .installments(cid)
      .where('contractId', isEqualTo: contractId)
      .snapshots()
      .map(_docs);

  /// One contract's transactions, any status.
  Stream<List<LedgerTransaction>> watchContractTransactions(
    String cid,
    String contractId,
  ) => _refs
      .transactions(cid)
      .where('contractId', isEqualTo: contractId)
      .snapshots()
      .map(_docs);
}
