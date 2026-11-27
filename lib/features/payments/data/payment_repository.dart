import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/firebase/balanced_chunks.dart';
import '../../../core/firebase/chunked_batch.dart';
import '../../../core/firebase/converters.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../core/money/inr_format.dart';
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

/// Add one past payment missing from a partly synced onboarding (owner
/// only).
final class AddOnboardingPaymentCommand {
  const AddOnboardingPaymentCommand({
    required this.cid,
    required this.snapshot,
    required this.amount,
    required this.paidOn,
    required this.mode,
    required this.actor,
    required this.role,
    this.reference,
    this.openingBalance = false,
  });

  final String cid;
  final ContractSnapshot snapshot;
  final Money amount;

  /// Within [contract.disbursedOn, contract.onboardedOn].
  final CivilDate paidOn;
  final PaymentMode mode;
  final LedgerActor actor;

  /// The caller's role in the company; only an owner may add it.
  final Role? role;
  final String? reference;

  /// Part of an opening-total spread: written with `openingBalance: true`
  /// and the "Opening balance" note, so "Reverse opening balance" also
  /// covers it. False for itemised loans.
  final bool openingBalance;
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

/// Cancel a wrongly onboarded loan (owner only): reverse every onboarding
/// payment, then set the contract `cancelled`.
final class CancelOnboardedCommand {
  const CancelOnboardedCommand({
    required this.cid,
    required this.snapshot,
    required this.reason,
    required this.actor,
    required this.role,
    this.queuePending = false,
  });

  final String cid;
  final ContractSnapshot snapshot;
  final String reason;
  final LedgerActor actor;
  final Role? role;

  /// The contract still has a pending sync list; it is marked cancelled in
  /// the same batch as the status, so the resumer stops.
  final bool queuePending;
}

/// Unreversed payments and waivers recorded after onboarding (origin
/// live). Cancelling is refused while any exist: that cash is real.
List<LedgerTransaction> liveEntriesBlockingCancel(ContractSnapshot snap) {
  final reversed = snap.reversedIds;
  return <LedgerTransaction>[
    for (final t in snap.transactions)
      if (t.contractId == snap.contract.id &&
          !t.isOnboarding &&
          (t.type == TxType.payment || t.type == TxType.waiver) &&
          !reversed.contains(t.id))
        t,
  ];
}

/// Onboarding payments of [snap]'s contract without a reversal (what
/// "Cancel onboarded loan" reverses).
List<LedgerTransaction> unreversedOnboardingPayments(ContractSnapshot snap) {
  final reversed = snap.reversedIds;
  return <LedgerTransaction>[
    for (final t in onboardingPayments(snap))
      if (!reversed.contains(t.id)) t,
  ];
}

/// A cancelled onboarded loan that still has unreversed onboarding
/// payments: "Finish cancelling" reverses them (no status change).
bool isCancelUnfinished(ContractSnapshot snap) =>
    snap.contract.isOnboarded &&
    snap.contract.status == ContractStatus.cancelled &&
    unreversedOnboardingPayments(snap).isNotEmpty;

/// Why "Cancel onboarded loan" is not available, or null when it is.
String? cancelOnboardedBlocker(ContractSnapshot snap) {
  final c = snap.contract;
  if (!c.isOnboarded) return 'Only onboarded loans can be cancelled.';
  // F2 (attempt 5): a cancelled loan whose onboarding payments are not all
  // reversed yet (an interrupted or raced Cancel) can be finished.
  if (c.status == ContractStatus.cancelled) {
    return isCancelUnfinished(snap) ? null : 'This loan is already cancelled.';
  }
  if (c.status != ContractStatus.active && c.status != ContractStatus.closed) {
    return 'This loan can no longer be cancelled.';
  }
  if (liveEntriesBlockingCancel(snap).isNotEmpty) {
    return 'Reverse the payments recorded after onboarding first.';
  }
  return null;
}

/// Reverse every unreversed opening-balance payment of an onboarded
/// contract in one action (owner only).
final class ReverseOpeningCommand {
  const ReverseOpeningCommand({
    required this.cid,
    required this.snapshot,
    required this.reason,
    required this.actor,
    required this.role,
  });

  final String cid;
  final ContractSnapshot snapshot;
  final String reason;
  final LedgerActor actor;

  /// The caller's role in the company; only an owner may reverse.
  final Role? role;
}

/// The opening-balance payments of [snap]'s contract that have no reversal
/// yet (what "Reverse opening balance" would reverse).
List<LedgerTransaction> unreversedOpeningBalance(ContractSnapshot snap) {
  final reversed = snap.reversedIds;
  return <LedgerTransaction>[
    for (final t in snap.transactions)
      if (t.contractId == snap.contract.id &&
          t.type == TxType.payment &&
          t.openingBalance &&
          !reversed.contains(t.id))
        t,
  ];
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

/// Why entries of a contract in [status] can no longer be reversed, or
/// null when they can. A rolled-over contract's balance was settled into
/// its successor and a cancelled one is out of the books, so reversing
/// there would reopen money that already moved.
String? reversalLockedMessage(ContractStatus status) => switch (status) {
  ContractStatus.rolledOver =>
    'This loan was rolled over. Its entries can no longer be reversed.',
  ContractStatus.cancelled =>
    'This loan was cancelled. Its entries can no longer be reversed.',
  ContractStatus.active || ContractStatus.closed => null,
};

/// Whether "Reverse" / "Reverse opening balance" are offered for a
/// contract in [status].
bool canReverseIn(ContractStatus status) =>
    reversalLockedMessage(status) == null;

/// Payments written by an onboarding (origin onboarding, type payment),
/// reversed or not: what `Contract.onboardedPaymentCount` counted.
/// Reversals are separate docs, so a correction never lowers this count.
List<LedgerTransaction> onboardingPayments(ContractSnapshot snap) =>
    <LedgerTransaction>[
      for (final t in snap.transactions)
        if (t.contractId == snap.contract.id &&
            t.type == TxType.payment &&
            t.isOnboarding)
          t,
    ];

/// "Onboarding incomplete" state of an onboarded contract: how many of
/// the payments the onboarding wrote (and how much cash) are on this
/// device, against the immutable `onboardedPaymentCount` /
/// `onboardedTotalPaise`. Null when the contract is not onboarded or
/// carries no count (older docs).
///
/// Counts and sums are **gross**: reversed onboarding payments still
/// count, because a reversal is a separate doc and the original was
/// written by the onboarding (or a repair) all the same.
final class OnboardingSync {
  const OnboardingSync({
    required this.synced,
    required this.expected,
    this.gross = Money.zero,
    this.onboardedTotal,
    this.isOpeningTotal,
  });

  final int synced;
  final int expected;

  /// Σ of every onboarding payment on this device, reversed or not.
  final Money gross;

  /// `onboardedTotalPaise`, or null on docs written before it existed.
  final Money? onboardedTotal;

  /// Whether the landed onboarding payments are an opening-total spread
  /// (true), itemised (false), or null when none has landed.
  final bool? isOpeningTotal;

  /// Cash the onboarding wrote that is not on this device (≥ ₹0).
  Money get missing {
    final total = onboardedTotal;
    if (total == null || gross >= total) return Money.zero;
    return total - gross;
  }

  bool get isIncomplete => synced < expected || missing.isPositive;

  /// More onboarding payments (or cash) than the onboarding wrote: a
  /// repair that double-counted a batch that was only queued.
  bool get isOvershoot {
    final total = onboardedTotal;
    return synced > expected || (total != null && gross > total);
  }

  /// How far the gross Σ is above `onboardedTotalPaise` (≥ ₹0).
  Money get overshoot {
    final total = onboardedTotal;
    if (total == null || gross <= total) return Money.zero;
    return gross - total;
  }

  /// The most a repair may add: [missing], capped at [outstanding].
  Money repairCap(Money outstanding) => Money.min(missing, outstanding);

  static OnboardingSync? of(ContractSnapshot snap) {
    final expected = snap.contract.onboardedPaymentCount;
    if (!snap.contract.isOnboarded || expected == null) return null;
    final pays = onboardingPayments(snap);
    return OnboardingSync(
      synced: pays.length,
      expected: expected,
      gross: Money.sum(pays.map((LedgerTransaction t) => t.amount)),
      onboardedTotal: snap.contract.onboardedTotal,
      isOpeningTotal: pays.isEmpty
          ? null
          : pays.any((LedgerTransaction t) => t.openingBalance),
    );
  }
}

/// Default date of a repair payment: the first base due date after the
/// newest landed onboarding payment that has no onboarding payment of its
/// own (later batches hold the newest payments, so that is where the gap
/// is), else the last base due date before [today], else `disbursedOn`.
/// Always within [disbursedOn, onboardedOn] and never [today] unless the
/// loan was disbursed today.
CivilDate defaultRepairDate(ContractSnapshot snap, CivilDate today) {
  final c = snap.contract;
  final last = c.onboardedOn ?? today;
  final paidDates = <CivilDate>{
    for (final t in onboardingPayments(snap)) t.paidOn,
  };
  final dues = <CivilDate>{
    for (final i in snap.installments)
      if (i.kind == InstallmentKind.base &&
          !i.dueDate.isBefore(c.disbursedOn) &&
          i.dueDate.isBefore(today) &&
          !i.dueDate.isAfter(last))
        i.dueDate,
  }.toList()..sort();
  CivilDate? newest;
  for (final p in paidDates) {
    if (newest == null || p.isAfter(newest)) newest = p;
  }
  for (final due in dues) {
    if ((newest == null || due.isAfter(newest)) && !paidDates.contains(due)) {
      return due;
    }
  }
  if (dues.isNotEmpty) return dues.last;
  return c.disbursedOn;
}

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
    this.batchMaxItems = maxLedgerItemsPerBatch,
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

  /// Most reversals per "Reverse opening balance" batch (production rule
  /// budget; see [maxLedgerItemsPerBatch]).
  final int batchMaxItems;

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
    if (closes) _flipActive(out.spill, cmd.cid, snap, active: false);
    return _commit(out, txId, 'payment', closed: closes, balanceAfter: after);
  }

  /// Owner only: repairs a partly synced onboarding by adding one missing
  /// past payment (`origin: onboarding`; an opening-balance row on an
  /// opening-total loan) dated within [disbursedOn, onboardedOn]. The
  /// amount is capped at `onboardedTotalPaise − Σ(gross onboarding
  /// payments)` and at the outstanding, so a batch that is only queued on
  /// the onboarding phone can never be double-counted past the onboarded
  /// total. It increments `totalPaidPaise` and moves `lastPaymentOn` only
  /// forward. When the balance reaches ₹0 the loan closes, as with any
  /// payment. Throws [PermissionDeniedFailure] / [ValidationFailure].
  Future<PaymentWriteResult> addOnboardingPayment(
    AddOnboardingPaymentCommand cmd,
  ) {
    Future<PaymentWriteResult> fail(AppFailure f) =>
        Future<PaymentWriteResult>.error(f);
    if (cmd.role != Role.owner) return fail(const PermissionDeniedFailure());
    final snap = cmd.snapshot;
    final c = snap.contract;
    final onboardedOn = c.onboardedOn;
    if (!c.isOnboarded || onboardedOn == null || !c.isActive) {
      return fail(
        const ValidationFailure(
          LedgerFields.amount,
          'Only an open onboarded loan can take a missing onboarding '
          'payment.',
        ),
      );
    }
    final outstanding = snap.outstanding;
    final errors = validatePaymentAmount(cmd.amount, outstanding);
    if (errors.isNotEmpty) {
      return fail(ValidationFailure(errors.first.field, errors.first.message));
    }
    // Never add more than the onboarding wrote: a "missing" batch may
    // only be queued on the onboarding phone (gross Σ, reversed included).
    final sync = OnboardingSync.of(snap);
    final cap = sync?.repairCap(outstanding) ?? Money.zero;
    if (!cap.isPositive) {
      return fail(
        const ValidationFailure(
          LedgerFields.amount,
          'Nothing is missing from this onboarding.',
        ),
      );
    }
    if (cmd.amount > cap) {
      return fail(
        ValidationFailure(
          LedgerFields.amount,
          'At most ${formatInr(cap)} is missing from this onboarding.',
        ),
      );
    }
    if (cmd.paidOn.isBefore(c.disbursedOn) || cmd.paidOn.isAfter(onboardedOn)) {
      return fail(
        ValidationFailure(
          LedgerFields.paidOn,
          'Choose a date from ${formatCivilDate(c.disbursedOn)} to '
          '${formatCivilDate(onboardedOn)} (the onboarding day).',
        ),
      );
    }

    final now = _clock.nowIst().toUtc();
    final txId = _uuid.v4();
    final after = outstanding - cmd.amount;
    final closes = after.isZero;
    final last = c.lastPaymentOn;
    final moveLast = last == null || cmd.paidOn.isAfter(last);
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
            contractActive: !closes,
            type: TxType.payment,
            amount: cmd.amount,
            paidOn: cmd.paidOn,
            mode: cmd.mode,
            reference: optionalText(cmd.reference),
            note: cmd.openingBalance ? openingBalanceNote : null,
            origin: TxOrigin.onboarding,
            openingBalance: cmd.openingBalance,
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
            if (moveLast) 'lastPaymentOn': cmd.paidOn.toString(),
            'updatedAt': Timestamp.fromDate(now),
            if (closes) 'status': ContractStatus.closed.name,
            if (closes) 'closedAt': Timestamp.fromDate(now),
          },
        ),
      );
    if (closes) _flipActive(out.spill, cmd.cid, snap, active: false);
    return _commit(
      out,
      txId,
      'onboarding payment',
      closed: closes,
      balanceAfter: after,
    );
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
    _flipActive(out.spill, cmd.cid, snap, active: false);
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
    final locked = reversalLockedMessage(c.status);
    if (locked != null) {
      return Future<PaymentWriteResult>.error(
        ValidationFailure(LedgerFields.amount, locked),
      );
    }
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
            // An onboarding correction is dated on the original date, so
            // history is fixed in place and today's figures never go
            // negative. Live reversals are dated today.
            paidOn: original.isOnboarding ? original.paidOn : cmd.today,
            mode: original.mode,
            note: reason,
            reversesTxId: original.id,
            origin: original.origin,
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
    if (reopens) _flipActive(out.spill, cmd.cid, snap, active: true);
    return _commit(
      out,
      txId,
      'reversal',
      closed: false,
      balanceAfter: c.sanctioned - poolAfter,
    );
  }

  /// Owner only: reverses every unreversed opening-balance payment of the
  /// contract ([unreversedOpeningBalance]). Each reversal is dated on its
  /// original's `paidOn`, copies its mode and `origin: onboarding`, and has
  /// the reason as its note. Written as balanced batches: each holds at
  /// most `min(limit − 1, batchMaxItems)` (100) reversals plus
  /// `totalPaidPaise: increment(−Σ)` for exactly those. A closed contract that has a balance again reopens.
  /// The result id is the first reversal's. Throws
  /// [PermissionDeniedFailure] / [ValidationFailure].
  Future<PaymentWriteResult> reverseOpeningBalance(ReverseOpeningCommand cmd) {
    Future<PaymentWriteResult> fail(AppFailure f) =>
        Future<PaymentWriteResult>.error(f);
    if (cmd.role != Role.owner) return fail(const PermissionDeniedFailure());
    final snap = cmd.snapshot;
    final c = snap.contract;
    final locked = reversalLockedMessage(c.status);
    if (locked != null) {
      return fail(ValidationFailure(LedgerFields.amount, locked));
    }
    final targets = unreversedOpeningBalance(snap);
    if (targets.isEmpty) {
      return fail(
        const ValidationFailure(
          LedgerFields.amount,
          'There is no opening balance left to reverse.',
        ),
      );
    }
    final reason = optionalText(cmd.reason);
    if (reason == null) {
      return fail(
        const ValidationFailure(
          reversalReasonField,
          'Enter a reason for the reversal.',
        ),
      );
    }

    final now = _clock.nowIst().toUtc();
    final total = Money.sum(targets.map((LedgerTransaction t) => t.amount));
    final poolAfter = paidPool(c.id, snap.transactions) - total;
    final reopens =
        c.status == ContractStatus.closed && poolAfter < c.sanctioned;
    final activeAfter = c.isActive || reopens;
    final contractRef = _db.doc(FirestorePaths.contract(cmd.cid, c.id));
    Map<String, Object?> decrement(Money sum) => <String, Object?>{
      'totalPaidPaise': FieldValue.increment(-sum.paise),
      'updatedAt': Timestamp.fromDate(now),
    };
    final out = BalancedChunks(
      _db,
      limit: batchLimit,
      maxItems: batchMaxItems,
      firstBalance: (WriteBatch b, Money sum) =>
          b.update(contractRef, <String, Object?>{
            ...decrement(sum),
            if (reopens) 'status': ContractStatus.active.name,
            if (reopens) 'closedAt': null,
          }),
      laterBalance: (WriteBatch b, Money sum) =>
          b.update(contractRef, decrement(sum)),
    );
    String? firstId;
    for (final original in targets) {
      final txId = _uuid.v4();
      firstId ??= txId;
      final reversal = LedgerTransaction(
        id: txId,
        contractId: c.id,
        borrowerId: c.borrowerId,
        borrowerName: c.borrowerName,
        loanNo: c.loanNo,
        contractActive: activeAfter,
        type: TxType.reversal,
        amount: original.amount,
        paidOn: original.paidOn,
        mode: original.mode,
        note: reason,
        reversesTxId: original.id,
        origin: TxOrigin.onboarding,
        recordedBy: cmd.actor.uid,
        recordedByName: cmd.actor.name,
        clientRecordedAt: now,
        deviceId: cmd.actor.deviceId,
      );
      out.item(
        (WriteBatch b) => b.set(_refs.transaction(cmd.cid, txId), reversal),
        original.amount,
      );
    }
    if (reopens) _flipActive(out.spill, cmd.cid, snap, active: true);
    return awaitServerAck(out.commit(), commitGrace, 'opening reversal').then(
      (WriteOutcome o) => PaymentWriteResult(
        firstId!,
        o,
        closed: false,
        balanceAfter: c.sanctioned - poolAfter,
      ),
    );
  }

  /// Owner only: cancels a wrongly onboarded loan (the deferred "undo a
  /// wrong onboarding"). Every unreversed onboarding payment gets a
  /// reversal dated on its original `paidOn` (mode and origin copied,
  /// reason as note), in balanced batches of at most [batchMaxItems] with
  /// `totalPaidPaise: increment(−Σ)`. The last batch sets
  /// `status: cancelled`, and every doc of the contract gets
  /// `contractActive: false`. Batches are sent in order ([commitInOrder]).
  ///
  /// Race with a running resumer (attempt 5, F1):
  /// 1. When a sync list is pending, its `→ cancelled` update is committed
  ///    FIRST and its ack awaited; without an ack (offline) the cancel is
  ///    refused ("Connect to the internet…"), so the resumer, which
  ///    re-checks the queue before every batch, stops before anything else
  ///    is written.
  /// 2. The reversal targets come from a SERVER read of the contract's
  ///    transactions (not the cached snapshot), so payments a resumer
  ///    landed meanwhile are reversed too. The rules also deny any
  ///    onboarding payment on a cancelled contract.
  ///
  /// Recovery (F2): on a contract that is already `cancelled` but still
  /// has unreversed onboarding payments ([isCancelUnfinished]), this
  /// writes the missing reversals only ("Finish cancelling"). If a run
  /// fails half way, running it again finishes it. Refused while live
  /// payments or waivers remain. Throws [PermissionDeniedFailure] /
  /// [ValidationFailure].
  Future<PaymentWriteResult> cancelOnboardedLoan(
    CancelOnboardedCommand cmd,
  ) async {
    if (cmd.role != Role.owner) throw const PermissionDeniedFailure();
    final cached = cmd.snapshot;
    final c = cached.contract;
    final blocked = cancelOnboardedBlocker(cached);
    if (blocked != null) {
      throw ValidationFailure(LedgerFields.amount, blocked);
    }
    final reason = optionalText(cmd.reason);
    if (reason == null) {
      throw const ValidationFailure(
        reversalReasonField,
        'Enter a reason for cancelling.',
      );
    }
    const offlineMessage =
        'Connect to the internet to cancel a loan that is still syncing.';
    if (cmd.queuePending) {
      try {
        final o = await awaitServerAck(
          _db
              .doc(FirestorePaths.onboardingQueue(cmd.cid, c.id))
              .update(<String, Object?>{
                'status': OnboardingQueueStatus.cancelled.name,
                'updatedAt': FieldValue.serverTimestamp(),
              }),
          commitGrace,
          'cancel sync list',
        );
        if (o == WriteOutcome.queued) {
          throw const ValidationFailure(LedgerFields.amount, offlineMessage);
        }
      } on PermissionDeniedFailure {
        // The queue already finished (complete): every payment landed; the
        // server read below sees them all.
      }
    }
    // Targets from the server, so nothing a resumer landed is missed. A
    // failed read is only acceptable when no sync list was pending.
    var snap = cached;
    try {
      final server = await _refs
          .transactions(cmd.cid)
          .where('contractId', isEqualTo: c.id)
          .get(const GetOptions(source: Source.server));
      snap = ContractSnapshot(
        contract: c,
        installments: cached.installments,
        transactions: <LedgerTransaction>[
          for (final d in server.docs) d.data(),
        ],
      );
    } on FirebaseException {
      if (cmd.queuePending) {
        throw const ValidationFailure(LedgerFields.amount, offlineMessage);
      }
    }
    if (liveEntriesBlockingCancel(snap).isNotEmpty &&
        c.status != ContractStatus.cancelled) {
      throw const ValidationFailure(
        LedgerFields.amount,
        'Reverse the payments recorded after onboarding first.',
      );
    }
    final finishing = c.status == ContractStatus.cancelled;
    final now = _clock.nowIst().toUtc();
    final contractRef = _db.doc(FirestorePaths.contract(cmd.cid, c.id));
    final targets = unreversedOnboardingPayments(snap);
    final room = batchMaxItems < batchLimit - 1
        ? batchMaxItems
        : batchLimit - 1;
    final batches = <WriteBatch>[];
    String? firstId;
    for (final group in onboardingChunks(targets, maxItems: room)) {
      final sum = Money.sum(group.map((LedgerTransaction t) => t.amount));
      final b = _db.batch()
        ..update(contractRef, <String, Object?>{
          'totalPaidPaise': FieldValue.increment(-sum.paise),
          'updatedAt': Timestamp.fromDate(now),
        });
      for (final original in group) {
        final txId = _uuid.v4();
        firstId ??= txId;
        b.set(
          _refs.transaction(cmd.cid, txId),
          LedgerTransaction(
            id: txId,
            contractId: c.id,
            borrowerId: c.borrowerId,
            borrowerName: c.borrowerName,
            loanNo: c.loanNo,
            contractActive: false,
            type: TxType.reversal,
            amount: original.amount,
            paidOn: original.paidOn,
            mode: original.mode,
            note: reason,
            reversesTxId: original.id,
            origin: TxOrigin.onboarding,
            recordedBy: cmd.actor.uid,
            recordedByName: cmd.actor.name,
            clientRecordedAt: now,
            deviceId: cmd.actor.deviceId,
          ),
        );
      }
      batches.add(b);
    }
    // The status (not when finishing an earlier cancel) and the
    // contractActive flips (cheap rules), at most [batchLimit] ops per
    // batch; the status goes first. The sync list was already cancelled
    // above. Flips also run when finishing, so payments a racing resumer
    // landed after the cancel leave the active listeners.
    final tail = <BatchOp>[
      if (!finishing)
        (WriteBatch b) => b.update(contractRef, <String, Object?>{
          'status': ContractStatus.cancelled.name,
          'closedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        }),
    ];
    _flipActive(tail.add, cmd.cid, snap, active: false);
    for (final ops in onboardingChunks(tail, maxItems: batchLimit)) {
      if (ops.isEmpty) continue;
      final b = _db.batch();
      for (final op in ops) {
        op(b);
      }
      batches.add(b);
    }
    final outcome = await awaitServerAck(
      commitInOrder(batches),
      commitGrace,
      'cancel onboarded',
    );
    return PaymentWriteResult(
      firstId ?? c.id,
      outcome,
      closed: true,
      balanceAfter: Money.zero,
    );
  }

  /// `contractActive: [active]` on every installment and transaction of
  /// the contract whose flag differs (spill ops, added through [spill]).
  void _flipActive(
    void Function(BatchOp op) spill,
    String cid,
    ContractSnapshot snap, {
    required bool active,
  }) {
    final value = <String, Object?>{'contractActive': active};
    for (final i in snap.installments) {
      if (i.contractActive == active) continue;
      spill(
        (WriteBatch b) =>
            b.update(_db.doc(FirestorePaths.installment(cid, i.id)), value),
      );
    }
    for (final t in snap.transactions) {
      if (t.contractActive == active) continue;
      spill(
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
