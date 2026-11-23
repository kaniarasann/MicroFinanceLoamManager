import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/firebase/chunked_batch.dart';
import '../../../core/firebase/converters.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../core/money/money.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/time/ist_clock.dart';
import '../../../domain/ledger/ledger.dart';
import '../../../domain/models/models.dart';
import '../../contracts/data/contract_repository.dart';
import '../../payments/data/payment_repository.dart' show ContractSnapshot;

export '../../payments/data/payment_repository.dart' show ContractSnapshot;
export '../../contracts/data/contract_repository.dart'
    show LedgerWriteResult, WriteOutcome;

/// Field name for the rollover's net-cash validation error.
const String rolloverNetField = 'netCash';

/// Close an active contract into a new one (owner only). The new loan's
/// terms implement [LoanTermsInput]; `disbursedOn` is the rollover day.
final class RolloverCommand implements LoanTermsInput {
  const RolloverCommand({
    required this.cid,
    required this.old,
    required this.sanctioned,
    required this.upfrontMode,
    required this.upfrontInput,
    required this.installmentAmount,
    required this.frequency,
    required this.firstDueDate,
    required this.disbursedOn,
    required this.cachedNextLoanNo,
    required this.actor,
    this.preferredWeekday,
    this.preferredMonthDay,
    this.guarantor,
    this.notes,
    this.purpose,
  });

  final String cid;

  /// The contract being closed, as this device knows it.
  final ContractSnapshot old;

  String get oldContractId => old.contract.id;

  @override
  final Money sanctioned;
  @override
  final UpfrontMode upfrontMode;
  @override
  final int upfrontInput;
  @override
  final Money installmentAmount;
  @override
  final Frequency frequency;
  @override
  final int? preferredWeekday;
  @override
  final int? preferredMonthDay;
  @override
  final CivilDate firstDueDate;
  @override
  final CivilDate disbursedOn;
  @override
  final int cachedNextLoanNo;
  @override
  final LedgerActor actor;
  @override
  final String? guarantor;
  @override
  final String? notes;
  @override
  final String? purpose;
}

/// The rollover write path (Section 2, "4. Write paths": Rollover).
///
/// One atomic batch: the old contract becomes `rolledOver` (linked, its
/// outstanding settled via `totalPaidPaise` and a `rolloverSettlement`
/// transaction), the new contract with its installments and a disbursement
/// of the net cash, and the company's `nextLoanNo` increment. The old docs'
/// `contractActive: false` flips fill the rest of that batch and spill into
/// follow-up batches past [maxOpsPerBatch].
///
/// With ₹0 net cash no disbursement transaction is written: no cash moves,
/// and the new contract's `netDisbursedPaise` (0) records the handover.
class RolloverRepository {
  RolloverRepository({
    required FirebaseFirestore firestore,
    required Clock clock,
    Uuid uuid = const Uuid(),
    this.commitGrace = const Duration(seconds: 2),
    this.batchLimit = maxOpsPerBatch,
  }) : _db = firestore,
       _refs = TypedRefs(firestore),
       _clock = clock,
       _uuid = uuid;

  final FirebaseFirestore _db;
  final TypedRefs _refs;
  final Clock _clock;
  final Uuid _uuid;
  final Duration commitGrace;
  final int batchLimit;

  /// Returns the new contract's id. Throws [ValidationFailure] when the old
  /// contract is not active, the new terms are invalid or the net cash
  /// would be negative.
  Future<LedgerWriteResult> rollover(RolloverCommand cmd) {
    final old = cmd.old.contract;
    if (!old.isActive) {
      return _fail(rolloverNetField, 'Only an active loan can be rolled over.');
    }
    final termErrors = validateCommandTerms(cmd);
    if (termErrors.isNotEmpty) {
      return _fail(termErrors.first.field, termErrors.first.message);
    }
    final quote = computeRollover(
      oldProjection: projectContract(
        contract: old,
        installments: cmd.old.installments,
        transactions: cmd.old.transactions,
        today: cmd.disbursedOn,
      ),
      newSanctioned: cmd.sanctioned,
      upfrontMode: cmd.upfrontMode,
      upfrontInput: cmd.upfrontInput,
    );
    if (!quote.isValid) return _fail(rolloverNetField, quote.error!);
    final settled = quote.settledOldOutstanding;

    final now = _clock.nowIst().toUtc();
    final newId = _uuid.v4();
    final plan = planNewContract(
      cmd: cmd,
      contractId: newId,
      borrowerId: old.borrowerId,
      borrowerName: old.borrowerName,
      borrowerPhoneE164: old.borrowerPhoneE164,
      now: now,
      uuid: _uuid,
      netDisbursed: quote.netCash,
      rolledOverFromContractId: old.id,
    );
    final settlementId = _uuid.v4();
    final out = ChunkedBatch(_db, limit: batchLimit)
      ..primary(
        (WriteBatch b) => b.update(
          _db.doc(FirestorePaths.contract(cmd.cid, old.id)),
          <String, Object?>{
            'status': ContractStatus.rolledOver.name,
            'rolledOverToContractId': newId,
            'closedAt': Timestamp.fromDate(now),
            'totalPaidPaise': FieldValue.increment(settled.paise),
            'rolloverSettledPaise': settled.paise,
            'updatedAt': Timestamp.fromDate(now),
          },
        ),
      )
      ..primary(
        (WriteBatch b) => b.set(
          _refs.transaction(cmd.cid, settlementId),
          LedgerTransaction(
            id: settlementId,
            contractId: old.id,
            borrowerId: old.borrowerId,
            borrowerName: old.borrowerName,
            loanNo: old.loanNo,
            contractActive: false,
            type: TxType.rolloverSettlement,
            amount: settled,
            paidOn: cmd.disbursedOn,
            relatedContractId: newId,
            recordedBy: cmd.actor.uid,
            recordedByName: cmd.actor.name,
            clientRecordedAt: now,
            deviceId: cmd.actor.deviceId,
          ),
        ),
      )
      ..primary(
        (WriteBatch b) => plan.writeTo(b, _refs, cmd.cid),
        ops: plan.opCount,
      )
      ..primary(
        (WriteBatch b) => b.update(
          _db.doc(FirestorePaths.company(cmd.cid)),
          <String, Object?>{'nextLoanNo': FieldValue.increment(1)},
        ),
      );
    const inactive = <String, Object?>{'contractActive': false};
    for (final i in cmd.old.installments) {
      if (!i.contractActive) continue;
      out.spill(
        (WriteBatch b) => b.update(
          _db.doc(FirestorePaths.installment(cmd.cid, i.id)),
          inactive,
        ),
      );
    }
    for (final t in cmd.old.transactions) {
      if (!t.contractActive) continue;
      out.spill(
        (WriteBatch b) => b.update(
          _db.doc(FirestorePaths.transaction(cmd.cid, t.id)),
          inactive,
        ),
      );
    }
    return _commit(out, newId);
  }

  Future<LedgerWriteResult> _commit(ChunkedBatch out, String id) async =>
      LedgerWriteResult(
        id,
        await awaitServerAck(out.commit(), commitGrace, 'rollover'),
      );

  static Future<LedgerWriteResult> _fail(String field, String message) =>
      Future<LedgerWriteResult>.error(ValidationFailure(field, message));
}
