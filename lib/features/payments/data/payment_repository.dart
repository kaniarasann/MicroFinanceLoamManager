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

export '../../contracts/data/contract_repository.dart'
    show LedgerActor, LedgerWriteResult, WriteOutcome;

/// What the device currently knows about one contract (from the live
/// per-contract listeners). The repository validates against it and uses
/// it to find the docs whose `contractActive` flag must flip.
final class ContractSnapshot {
  const ContractSnapshot({
    required this.contract,
    required this.installments,
    required this.transactions,
  });

  final Contract contract;
  final List<Installment> installments;
  final List<LedgerTransaction> transactions;

  /// sanctioned − (payments + settlements + waivers − reversals), floored
  /// at 0.
  Money get outstanding {
    final left = contract.sanctioned - paidPool(contract.id, transactions);
    return left.isNegative ? Money.zero : left;
  }

  /// Ids of payments that already have a reversal.
  Set<String> get reversedIds => <String>{
    for (final t in transactions)
      if (t.type == TxType.reversal && t.reversesTxId != null) t.reversesTxId!,
  };
}

/// Record one payment (owner or collector).
final class RecordPaymentCommand {
  const RecordPaymentCommand({
    required this.cid,
    required this.snapshot,
    required this.amount,
    required this.paidOn,
    required this.mode,
    required this.actor,
    this.reference,
    this.note,
  });

  final String cid;
  final ContractSnapshot snapshot;
  final Money amount;
  final CivilDate paidOn;
  final PaymentMode mode;
  final LedgerActor actor;
  final String? reference;
  final String? note;

  String get contractId => snapshot.contract.id;
}

/// Close a loan for less than its outstanding (owner only): [cashAmount]
/// received plus [waiverAmount] waived must equal the outstanding exactly.
final class CloseWithWaiverCommand {
  const CloseWithWaiverCommand({
    required this.cid,
    required this.snapshot,
    required this.cashAmount,
    required this.waiverAmount,
    required this.reason,
    required this.paidOn,
    required this.actor,
    required this.role,
    this.mode,
    this.reference,
  });

  final String cid;
  final ContractSnapshot snapshot;

  /// Cash received now (≥ 0; a payment is written only when > 0).
  final Money cashAmount;

  /// The discount (> 0).
  final Money waiverAmount;

  /// Why the rest is waived (required; stored in the waiver's `note`).
  final String reason;
  final CivilDate paidOn;
  final LedgerActor actor;

  /// The caller's role in the company; only an owner may waive.
  final Role? role;

  /// Mode of the cash part (required when [cashAmount] > 0).
  final PaymentMode? mode;
  final String? reference;

  String get contractId => snapshot.contract.id;
}

/// Reverse one payment or waiver (owner only).
final class ReversePaymentCommand {
  const ReversePaymentCommand({
    required this.cid,
    required this.snapshot,
    required this.transactionId,
    required this.reason,
    required this.today,
    required this.actor,
  });

  final String cid;
  final ContractSnapshot snapshot;
  final String transactionId;
  final String reason;
  final CivilDate today;
  final LedgerActor actor;
}

/// Result of a payment: the new transaction id, the ack outcome, whether
/// the payment closed the loan and the balance left after it.
final class PaymentWriteResult {
  const PaymentWriteResult(
    this.id,
    this.outcome, {
    required this.closed,
    required this.balanceAfter,
  });

  final String id;
  final WriteOutcome outcome;
  final bool closed;
  final Money balanceAfter;
}

/// Field name for reversal validation errors.
const String reversalReasonField = 'reason';

/// Field names for close-with-waiver validation errors.
const String waiverAmountField = 'waiverAmount';
const String waiverReasonField = 'waiverReason';
const String waiverModeField = 'mode';

/// Result of [PaymentRepository.closeWithWaiver]: the payment id (null
/// when no cash was received), the waiver id and the ack outcome.
final class WaiverWriteResult {
  const WaiverWriteResult({
    required this.paymentId,
    required this.waiverId,
    required this.outcome,
  });

  final String? paymentId;
  final String waiverId;
  final WriteOutcome outcome;
}

/// Payment write paths (Section 2, "4. Write paths": Record payment and
/// Reverse payment). Each is a [WriteBatch] with client uuid v4 ids, so it
/// queues offline. When the `contractActive` flips push a batch over
/// [maxOpsPerBatch] they spill into follow-up batches; the money fields
/// always stay in the first, atomic batch.
class PaymentRepository {
  PaymentRepository({
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

  /// Appends a payment and increments `totalPaidPaise`. When the balance
  /// reaches ₹0 the contract closes and all its docs get
  /// `contractActive: false`. The amount must be > 0 and ≤ the outstanding
  /// balance, except on a rolled-over contract, where a late payment is
  /// accepted and surfaces as excess. Throws [ValidationFailure].
  Future<PaymentWriteResult> recordPayment(RecordPaymentCommand cmd) {
    final snap = cmd.snapshot;
    final c = snap.contract;
    final outstanding = snap.outstanding;
    final late = c.status == ContractStatus.rolledOver;
    if (c.status == ContractStatus.cancelled ||
        (c.status == ContractStatus.closed && outstanding.isZero)) {
      return Future<PaymentWriteResult>.error(
        const ValidationFailure(
          LedgerFields.amount,
          'This loan is closed. Payments can no longer be recorded.',
        ),
      );
    }
    final errors = late
        ? validatePaymentAmount(cmd.amount, cmd.amount)
        : validatePaymentAmount(cmd.amount, outstanding);
    if (errors.isNotEmpty) {
      return Future<PaymentWriteResult>.error(
        ValidationFailure(errors.first.field, errors.first.message),
      );
    }

    final now = _clock.nowIst().toUtc();
    final txId = _uuid.v4();
    final after = late ? Money.zero : outstanding - cmd.amount;
    final closes = c.status == ContractStatus.active && after.isZero;
    final out = ChunkedBatch(_db, limit: batchLimit)
      ..primary(
        (WriteBatch b) => b.set(
          _refs.transaction(cmd.cid, txId),
          LedgerTransaction(
            id: txId,
            contractId: c.id,
            borrowerId: c.borrowerId,
            borrowerName: c.borrowerName,
            loanNo: c.loanNo,
            contractActive: c.isActive && !closes,
            type: TxType.payment,
            amount: cmd.amount,
            paidOn: cmd.paidOn,
            mode: cmd.mode,
            reference: optionalText(cmd.reference),
            note: optionalText(cmd.note),
            recordedBy: cmd.actor.uid,
            recordedByName: cmd.actor.name,
            clientRecordedAt: now,
            deviceId: cmd.actor.deviceId,
          ),
        ),
      )
      ..primary(
        (WriteBatch b) => b.update(
          _db.doc(FirestorePaths.contract(cmd.cid, c.id)),
          <String, Object?>{
            'totalPaidPaise': FieldValue.increment(cmd.amount.paise),
            'lastPaymentOn': cmd.paidOn.toString(),
            'updatedAt': Timestamp.fromDate(now),
            if (closes) 'status': ContractStatus.closed.name,
            if (closes) 'closedAt': Timestamp.fromDate(now),
          },
        ),
      );
    if (closes) _flipActive(out, cmd.cid, snap, active: false);
    return _commit(out, txId, 'payment', closed: closes, balanceAfter: after);
  }

  /// Owner only: closes an active loan for [CloseWithWaiverCommand.cashAmount]
  /// cash plus a [CloseWithWaiverCommand.waiverAmount] discount, in one
  /// batch: a payment (when cash > 0), a `waiver` (note = reason, no mode),
  /// the contract update (`totalPaidPaise += cash`, `totalWaivedPaise += W`,
  /// status closed) and the `contractActive: false` flips. cash + W must
  /// equal the outstanding exactly. Throws [PermissionDeniedFailure] /
  /// [ValidationFailure].
  Future<WaiverWriteResult> closeWithWaiver(CloseWithWaiverCommand cmd) {
    Future<WaiverWriteResult> fail(AppFailure f) =>
        Future<WaiverWriteResult>.error(f);
    if (cmd.role != Role.owner) return fail(const PermissionDeniedFailure());
    final snap = cmd.snapshot;
    final c = snap.contract;
    final outstanding = snap.outstanding;
    final cash = cmd.cashAmount;
    final waiver = cmd.waiverAmount;
    if (c.status != ContractStatus.active || outstanding.isZero) {
      return fail(
        const ValidationFailure(
          LedgerFields.amount,
          'Only an open loan with a balance can be closed with a waiver.',
        ),
      );
    }
    if (cash.isNegative) {
      return fail(
        const ValidationFailure(
          LedgerFields.amount,
          'Cash received cannot be negative.',
        ),
      );
    }
    if (!waiver.isPositive) {
      return fail(
        const ValidationFailure(
          waiverAmountField,
          'The waiver must be more than ₹0.',
        ),
      );
    }
    if (cash + waiver != outstanding) {
      return fail(
        const ValidationFailure(
          waiverAmountField,
          'Cash plus waiver must equal the outstanding balance.',
        ),
      );
    }
    final reason = optionalText(cmd.reason);
    if (reason == null) {
      return fail(
        const ValidationFailure(
          waiverReasonField,
          'Enter a reason for the waiver.',
        ),
      );
    }
    final mode = cmd.mode;
    if (cash.isPositive && mode == null) {
      return fail(
        const ValidationFailure(waiverModeField, 'Choose a payment mode.'),
      );
    }

    final now = _clock.nowIst().toUtc();
    final payId = cash.isPositive ? _uuid.v4() : null;
    final waiverId = _uuid.v4();
    LedgerTransaction entry(
      String id,
      TxType type,
      Money amount, {
      PaymentMode? mode,
      String? reference,
      String? note,
    }) => LedgerTransaction(
      id: id,
      contractId: c.id,
      borrowerId: c.borrowerId,
      borrowerName: c.borrowerName,
      loanNo: c.loanNo,
      contractActive: false,
      type: type,
      amount: amount,
      paidOn: cmd.paidOn,
      mode: mode,
      reference: reference,
      note: note,
      recordedBy: cmd.actor.uid,
      recordedByName: cmd.actor.name,
      clientRecordedAt: now,
      deviceId: cmd.actor.deviceId,
    );
    final out = ChunkedBatch(_db, limit: batchLimit);
    if (payId != null) {
      final pay = entry(
        payId,
        TxType.payment,
        cash,
        mode: mode,
        reference: optionalText(cmd.reference),
      );
      out.primary(
        (WriteBatch b) => b.set(_refs.transaction(cmd.cid, payId), pay),
      );
    }
    final waived = entry(waiverId, TxType.waiver, waiver, note: reason);
    out
      ..primary(
        (WriteBatch b) => b.set(_refs.transaction(cmd.cid, waiverId), waived),
      )
      ..primary(
        (WriteBatch b) => b.update(
          _db.doc(FirestorePaths.contract(cmd.cid, c.id)),
          <String, Object?>{
            'totalPaidPaise': FieldValue.increment(cash.paise),
            'totalWaivedPaise': FieldValue.increment(waiver.paise),
            'lastPaymentOn': cmd.paidOn.toString(),
            'status': ContractStatus.closed.name,
            'closedAt': Timestamp.fromDate(now),
            'updatedAt': Timestamp.fromDate(now),
          },
        ),
      );
    _flipActive(out, cmd.cid, snap, active: false);
    return awaitServerAck(out.commit(), commitGrace, 'waiver').then(
      (WriteOutcome o) =>
          WaiverWriteResult(paymentId: payId, waiverId: waiverId, outcome: o),
    );
  }

  /// Appends a reversal of payment or waiver
  /// [ReversePaymentCommand.transactionId] and decrements `totalPaidPaise`
  /// (payment) or `totalWaivedPaise` (waiver). A closed contract that has a
  /// balance again reopens (status active, closedAt null,
  /// `contractActive: true` on its docs). An entry can be reversed only
  /// once. Throws [ValidationFailure] / [NotFoundFailure].
  Future<PaymentWriteResult> reversePayment(ReversePaymentCommand cmd) {
    final snap = cmd.snapshot;
    final c = snap.contract;
    final original = snap.transactions
        .where((LedgerTransaction t) => t.id == cmd.transactionId)
        .firstOrNull;
    if (original == null ||
        (original.type != TxType.payment && original.type != TxType.waiver)) {
      return Future<PaymentWriteResult>.error(const NotFoundFailure());
    }
    final isWaiver = original.type == TxType.waiver;
    if (snap.reversedIds.contains(original.id)) {
      return Future<PaymentWriteResult>.error(
        ValidationFailure(
          LedgerFields.amount,
          isWaiver
              ? 'This waiver has already been reversed.'
              : 'This payment has already been reversed.',
        ),
      );
    }
    final reason = optionalText(cmd.reason);
    if (reason == null) {
      return Future<PaymentWriteResult>.error(
        const ValidationFailure(
          reversalReasonField,
          'Enter a reason for the reversal.',
        ),
      );
    }

    final now = _clock.nowIst().toUtc();
    final txId = _uuid.v4();
    final poolAfter = paidPool(c.id, snap.transactions) - original.amount;
    final reopens =
        c.status == ContractStatus.closed && poolAfter < c.sanctioned;
    final activeAfter = c.isActive || reopens;
    final out = ChunkedBatch(_db, limit: batchLimit)
      ..primary(
        (WriteBatch b) => b.set(
          _refs.transaction(cmd.cid, txId),
          LedgerTransaction(
            id: txId,
            contractId: c.id,
            borrowerId: c.borrowerId,
            borrowerName: c.borrowerName,
            loanNo: c.loanNo,
            contractActive: activeAfter,
            type: TxType.reversal,
            amount: original.amount,
            paidOn: cmd.today,
            mode: original.mode,
            note: reason,
            reversesTxId: original.id,
            recordedBy: cmd.actor.uid,
            recordedByName: cmd.actor.name,
            clientRecordedAt: now,
            deviceId: cmd.actor.deviceId,
          ),
        ),
      )
      ..primary(
        (WriteBatch b) => b.update(
          _db.doc(FirestorePaths.contract(cmd.cid, c.id)),
          <String, Object?>{
            if (isWaiver)
              'totalWaivedPaise': FieldValue.increment(-original.amount.paise)
            else
              'totalPaidPaise': FieldValue.increment(-original.amount.paise),
            'updatedAt': Timestamp.fromDate(now),
            if (reopens) 'status': ContractStatus.active.name,
            if (reopens) 'closedAt': null,
          },
        ),
      );
    if (reopens) _flipActive(out, cmd.cid, snap, active: true);
    return _commit(
      out,
      txId,
      'reversal',
      closed: false,
      balanceAfter: c.sanctioned - poolAfter,
    );
  }

  /// `contractActive: [active]` on every installment and transaction of
  /// the contract whose flag differs (spill ops).
  void _flipActive(
    ChunkedBatch out,
    String cid,
    ContractSnapshot snap, {
    required bool active,
  }) {
    final value = <String, Object?>{'contractActive': active};
    for (final i in snap.installments) {
      if (i.contractActive == active) continue;
      out.spill(
        (WriteBatch b) =>
            b.update(_db.doc(FirestorePaths.installment(cid, i.id)), value),
      );
    }
    for (final t in snap.transactions) {
      if (t.contractActive == active) continue;
      out.spill(
        (WriteBatch b) =>
            b.update(_db.doc(FirestorePaths.transaction(cid, t.id)), value),
      );
    }
  }

  Future<PaymentWriteResult> _commit(
    ChunkedBatch out,
    String id,
    String what, {
    required bool closed,
    required Money balanceAfter,
  }) async => PaymentWriteResult(
    id,
    await awaitServerAck(out.commit(), commitGrace, what),
    closed: closed,
    balanceAfter: balanceAfter,
  );
}
