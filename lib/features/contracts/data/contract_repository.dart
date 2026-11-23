import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/firebase/converters.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../core/firebase/write_outcome.dart';
import '../../../core/money/money.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/time/ist_clock.dart';
import '../../../domain/ledger/ledger.dart';
import '../../../domain/models/models.dart';

export '../../../core/firebase/write_outcome.dart';

/// Who is writing: stamped on every ledger doc.
final class LedgerActor {
  const LedgerActor({
    required this.uid,
    required this.name,
    required this.deviceId,
  });

  final String uid;
  final String name;
  final String deviceId;
}

/// Everything needed to create and disburse a contract (owner only).
final class CreateContractCommand implements LoanTermsInput {
  const CreateContractCommand({
    required this.cid,
    required this.borrower,
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
  final Borrower borrower;
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

/// The terms of a new contract, shared by create and rollover.
abstract interface class LoanTermsInput {
  Money get sanctioned;
  UpfrontMode get upfrontMode;

  /// Paise (flat) or basis points (percent).
  int get upfrontInput;
  Money get installmentAmount;
  Frequency get frequency;
  int? get preferredWeekday;
  int? get preferredMonthDay;
  CivilDate get firstDueDate;
  CivilDate get disbursedOn;

  /// `company.nextLoanNo` as last seen in the cache; the new loan is
  /// number `cachedNextLoanNo + 1` and the batch increments the counter.
  int get cachedNextLoanNo;
  LedgerActor get actor;
  String? get guarantor;
  String? get notes;
  String? get purpose;
}

/// Moves part (or all) of one stored installment's unpaid amount to a new
/// date (owner or collector).
final class RescheduleCommand {
  const RescheduleCommand({
    required this.cid,
    required this.source,
    required this.amount,
    required this.newDueDate,
    required this.remaining,
    required this.maxSeq,
    required this.today,
    required this.actor,
    this.note,
  });

  final String cid;

  /// The stored installment being moved from.
  final Installment source;
  final Money amount;
  final CivilDate newDueDate;

  /// The row's unpaid remainder, from the projection.
  final Money remaining;

  /// Highest stored seq of the contract (the new row takes `maxSeq + 1`).
  final int maxSeq;
  final CivilDate today;
  final LedgerActor actor;
  final String? note;
}

/// Result of a ledger write: the new doc id and whether the server
/// acknowledged it within the grace period.
final class LedgerWriteResult {
  const LedgerWriteResult(this.id, this.outcome);

  final String id;
  final WriteOutcome outcome;
}

/// Validates the terms of [cmd] (weekday only for weekly, month day only
/// for monthly). Empty = valid. Shared by create and rollover.
List<ValidationError> validateCommandTerms(LoanTermsInput cmd) =>
    validateContractTerms(
      sanctioned: cmd.sanctioned,
      upfrontMode: cmd.upfrontMode,
      upfrontInput: cmd.upfrontInput,
      installmentAmount: cmd.installmentAmount,
      frequency: cmd.frequency,
      preferredWeekday: cmd.frequency == Frequency.weekly
          ? cmd.preferredWeekday
          : null,
      preferredMonthDay: cmd.frequency == Frequency.monthly
          ? cmd.preferredMonthDay
          : null,
      firstDueDate: cmd.firstDueDate,
      disbursedOn: cmd.disbursedOn,
    );

/// The documents of a new contract: the contract, its base installments
/// and its disbursement transaction. Built by [planNewContract] and shared
/// by create and rollover, so both write identical shapes.
final class NewContractPlan {
  const NewContractPlan({
    required this.contract,
    required this.installments,
    required this.disbursement,
  });

  final Contract contract;
  final List<Installment> installments;

  /// `null` when no cash is handed over (a rollover with ₹0 net cash).
  final LedgerTransaction? disbursement;

  /// Number of batch operations [writeTo] adds.
  int get opCount => 1 + installments.length + (disbursement == null ? 0 : 1);

  void writeTo(WriteBatch batch, TypedRefs refs, String cid) {
    batch.set(refs.contract(cid, contract.id), contract);
    for (final i in installments) {
      batch.set(refs.installment(cid, i.id), i);
    }
    final tx = disbursement;
    if (tx != null) batch.set(refs.transaction(cid, tx.id), tx);
  }
}

/// Builds the docs of a new contract from already validated [cmd] terms.
/// [netDisbursed] overrides sanctioned − upfront (a rollover hands over
/// less). A rollover with zero net cash gets no disbursement transaction.
NewContractPlan planNewContract({
  required LoanTermsInput cmd,
  required String contractId,
  required String borrowerId,
  required String borrowerName,
  required String borrowerPhoneE164,
  required DateTime now,
  required Uuid uuid,
  Money? netDisbursed,
  String? rolledOverFromContractId,
}) {
  final weekday = cmd.frequency == Frequency.weekly
      ? cmd.preferredWeekday
      : null;
  final monthDay = cmd.frequency == Frequency.monthly
      ? cmd.preferredMonthDay
      : null;
  final schedule = generateSchedule(
    sanctioned: cmd.sanctioned,
    installmentAmount: cmd.installmentAmount,
    frequency: cmd.frequency,
    firstDueDate: cmd.firstDueDate,
    preferredWeekday: weekday,
    preferredMonthDay: monthDay,
  );
  final upfront = computeUpfront(
    cmd.sanctioned,
    cmd.upfrontMode,
    cmd.upfrontInput,
  );
  final net = netDisbursed ?? computeNetDisbursed(cmd.sanctioned, upfront);
  final loanNo = cmd.cachedNextLoanNo + 1;
  final uid = cmd.actor.uid;

  final contract = Contract(
    id: contractId,
    borrowerId: borrowerId,
    borrowerName: borrowerName,
    borrowerPhoneE164: borrowerPhoneE164,
    loanNo: loanNo,
    purpose: optionalText(cmd.purpose),
    sanctioned: cmd.sanctioned,
    upfrontMode: cmd.upfrontMode,
    upfrontInput: cmd.upfrontInput,
    upfront: upfront,
    netDisbursed: net,
    frequency: cmd.frequency,
    preferredWeekday: weekday,
    preferredMonthDay: monthDay,
    installmentAmount: cmd.installmentAmount,
    baseInstallmentCount: schedule.length,
    firstDueDate: schedule.first.dueDate,
    disbursedOn: cmd.disbursedOn,
    guarantor: optionalText(cmd.guarantor),
    notes: optionalText(cmd.notes),
    rolledOverFromContractId: rolledOverFromContractId,
    createdBy: uid,
    createdAt: now,
    updatedAt: now,
  );
  final installments = <Installment>[
    for (final row in schedule)
      Installment(
        id: uuid.v4(),
        contractId: contractId,
        borrowerId: borrowerId,
        borrowerName: borrowerName,
        loanNo: loanNo,
        seq: row.seq,
        dueDate: row.dueDate,
        amountDue: row.amount,
        createdBy: uid,
        createdAt: now,
      ),
  ];
  final skipDisbursement = rolledOverFromContractId != null && !net.isPositive;
  return NewContractPlan(
    contract: contract,
    installments: installments,
    disbursement: skipDisbursement
        ? null
        : LedgerTransaction(
            id: uuid.v4(),
            contractId: contractId,
            borrowerId: borrowerId,
            borrowerName: borrowerName,
            loanNo: loanNo,
            type: TxType.disbursement,
            amount: net,
            paidOn: cmd.disbursedOn,
            relatedContractId: rolledOverFromContractId,
            recordedBy: uid,
            recordedByName: cmd.actor.name,
            clientRecordedAt: now,
            deviceId: cmd.actor.deviceId,
          ),
  );
}

/// Trimmed text, or null when blank.
String? optionalText(String? value) {
  final v = value?.trim();
  return (v == null || v.isEmpty) ? null : v;
}

/// Contract write paths (Section 2, "4. Write paths"). Each is ONE
/// [WriteBatch] with client uuid v4 ids, so it queues offline and a retry is
/// idempotent. The call waits up to [commitGrace] for the server ack; after
/// that the batch is already in the cache and counts as queued.
class ContractRepository {
  ContractRepository({
    required FirebaseFirestore firestore,
    required Clock clock,
    Uuid uuid = const Uuid(),
    this.commitGrace = const Duration(seconds: 2),
  }) : _db = firestore,
       _refs = TypedRefs(firestore),
       _clock = clock,
       _uuid = uuid;

  final FirebaseFirestore _db;
  final TypedRefs _refs;
  final Clock _clock;
  final Uuid _uuid;
  final Duration commitGrace;

  /// Validates the terms, then writes the contract, its N base
  /// installments, the disbursement transaction and the company's
  /// `nextLoanNo` increment. Throws [ValidationFailure] (first error).
  Future<LedgerWriteResult> createContract(CreateContractCommand cmd) {
    final errors = validateCommandTerms(cmd);
    if (errors.isNotEmpty) {
      return Future<LedgerWriteResult>.error(
        ValidationFailure(errors.first.field, errors.first.message),
      );
    }
    final b = cmd.borrower;
    final plan = planNewContract(
      cmd: cmd,
      contractId: _uuid.v4(),
      borrowerId: b.id,
      borrowerName: b.name,
      borrowerPhoneE164: b.phoneE164,
      now: _clock.nowIst().toUtc(),
      uuid: _uuid,
    );
    final batch = _db.batch();
    plan.writeTo(batch, _refs, cmd.cid);
    batch.update(_db.doc(FirestorePaths.company(cmd.cid)), <String, Object?>{
      'nextLoanNo': FieldValue.increment(1),
    });
    return _commit(batch, plan.contract.id, 'contract create');
  }

  /// Moves `cmd.amount` of the source installment to `cmd.newDueDate`:
  /// source `{rescheduledOutPaise: +x, rescheduledToIds: ∪ new}`, a new
  /// `rescheduled` installment, and a 0-amount `reschedule` audit
  /// transaction. Throws [ValidationFailure] (first error).
  Future<LedgerWriteResult> reschedule(RescheduleCommand cmd) {
    final errors = validateReschedule(
      amount: cmd.amount,
      remaining: cmd.remaining,
      newDueDate: cmd.newDueDate,
      today: cmd.today,
    );
    if (errors.isNotEmpty) {
      return Future<LedgerWriteResult>.error(
        ValidationFailure(errors.first.field, errors.first.message),
      );
    }
    final src = cmd.source;
    final now = _clock.nowIst().toUtc();
    final newId = _uuid.v4();
    final txId = _uuid.v4();
    final uid = cmd.actor.uid;

    final batch = _db.batch()
      ..update(
        _db.doc(FirestorePaths.installment(cmd.cid, src.id)),
        <String, Object?>{
          'rescheduledOutPaise': FieldValue.increment(cmd.amount.paise),
          'rescheduledToIds': FieldValue.arrayUnion(<String>[newId]),
        },
      )
      ..set(
        _refs.installment(cmd.cid, newId),
        Installment(
          id: newId,
          contractId: src.contractId,
          borrowerId: src.borrowerId,
          borrowerName: src.borrowerName,
          loanNo: src.loanNo,
          seq: cmd.maxSeq + 1,
          kind: InstallmentKind.rescheduled,
          dueDate: cmd.newDueDate,
          amountDue: cmd.amount,
          rescheduledFromId: src.id,
          createdBy: uid,
          createdAt: now,
        ),
      )
      ..set(
        _refs.transaction(cmd.cid, txId),
        LedgerTransaction(
          id: txId,
          contractId: src.contractId,
          borrowerId: src.borrowerId,
          borrowerName: src.borrowerName,
          loanNo: src.loanNo,
          type: TxType.reschedule,
          amount: Money.zero,
          paidOn: cmd.today,
          note: optionalText(cmd.note),
          rescheduleInfo: <String, dynamic>{
            'fromInstallmentId': src.id,
            'toInstallmentId': newId,
            'amountPaise': cmd.amount.paise,
            'newDueDate': cmd.newDueDate.toString(),
          },
          recordedBy: uid,
          recordedByName: cmd.actor.name,
          clientRecordedAt: now,
          deviceId: cmd.actor.deviceId,
        ),
      );
    return _commit(batch, newId, 'reschedule');
  }

  Future<LedgerWriteResult> _commit(
    WriteBatch batch,
    String id,
    String what,
  ) async => LedgerWriteResult(
    id,
    await awaitServerAck(batch.commit(), commitGrace, what),
  );
}
