import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firebase/balanced_chunks.dart';
import '../../../core/firebase/converters.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../core/money/money.dart';
import '../../../core/time/civil_date.dart';
import '../../../domain/ledger/ledger.dart';
import '../../../domain/models/models.dart';
import 'contract_repository.dart';

export 'onboarding_queue.dart';

/// Onboard an existing, in-progress loan (owner only): the original terms
/// and dates plus what was already collected.
final class OnboardContractCommand implements LoanTermsInput {
  const OnboardContractCommand({
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
    required this.role,
    required this.today,
    required this.pastPayments,
    this.preferredWeekday,
    this.preferredMonthDay,
    this.previousRef,
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

  /// The caller's role in the company; only an owner may onboard.
  final Role? role;

  /// IST today (from `todayProvider`): stored as `onboardedOn`.
  final CivilDate today;

  /// Itemised payments, or an opening total already passed through
  /// `spreadOpeningTotal`.
  final List<PastPaymentInput> pastPayments;

  /// Paper / old-system loan number.
  final String? previousRef;
  @override
  final String? guarantor;
  @override
  final String? notes;
  @override
  final String? purpose;
}

/// Validates [cmd]: the new-loan terms plus the onboarding windows and past
/// payments. Empty = valid.
List<ValidationError> validateOnboardCommand(OnboardContractCommand cmd) =>
    validateOnboarding(
      termErrors: validateCommandTerms(cmd),
      sanctioned: cmd.sanctioned,
      disbursedOn: cmd.disbursedOn,
      firstDueDate: cmd.firstDueDate,
      today: cmd.today,
      payments: cmd.pastPayments,
      previousRef: cmd.previousRef,
    );

/// How an onboarding is written (Sprint 7c attempt 4, "sync list"):
/// - **batch 1**, committed by `onboardContract`: the contract (raw-map
///   `set` with `totalPaidPaise: increment(Σ batch-1 payments)`), every
///   installment, the disbursement, the company `nextLoanNo` increment, the
///   first [firstPayments] payments and, when more remain, the
///   [OnboardingQueue] doc listing all of them;
/// - **later batches**, written by `resumeOnboarding` only once batch 1 is
///   on the server, one at a time: a contract increment equal to that
///   batch's payments plus at most [maxItems] queued payments.
///
/// Production evaluates queued batches before batch 1 has landed, so a
/// later batch fired blindly finds no contract and is denied (device
/// smoke test, 2026-11-26). Nothing after batch 1 is fired blindly.
final class OnboardingLayout {
  const OnboardingLayout({
    required this.installments,
    required this.firstPayments,
    required this.laterSizes,
    required this.hasQueue,
    required this.sums,
  });

  final int installments;

  /// Payments in batch 1.
  final int firstPayments;

  /// Payments per later (resumed) batch.
  final List<int> laterSizes;
  final bool hasQueue;

  /// Σ of the payments per batch (each is that batch's increment).
  final List<Money> sums;

  /// Payments per batch, batch 1 first.
  List<int> get chunkSizes => <int>[firstPayments, ...laterSizes];

  List<Money> get chunkSums => sums;

  int get batchCount => 1 + laterSizes.length;

  /// Ops per batch: batch 1 = contract + disbursement + nextLoanNo (+
  /// queue) + installments + payments; later = 1 increment + payments.
  List<int> get opsPerBatch => <int>[
    3 + (hasQueue ? 1 : 0) + installments + firstPayments,
    for (final n in laterSizes) 1 + n,
  ];
}

/// The documents of an onboarding: an ordinary new-contract plan (origin
/// onboarded, disbursement dated on the original `disbursedOn`) plus the
/// past `payment` transactions (origin onboarding), oldest first.
///
/// [contract] holds the state after every batch has landed (`totalPaid` =
/// Σ payments, `lastPaymentOn` = latest `paidOn`), so a preview that
/// projects [contract], [installments] and [transactions] shows exactly
/// what the contract detail shows after the save.
final class OnboardingPlan {
  const OnboardingPlan({required this.base, required this.payments});

  final NewContractPlan base;
  final List<LedgerTransaction> payments;

  Contract get contract => base.contract;

  List<Installment> get installments => base.installments;

  /// Disbursement + payments.
  List<LedgerTransaction> get transactions => <LedgerTransaction>[
    ?base.disbursement,
    ...payments,
  ];

  Money get totalCollected =>
      Money.sum(payments.map((LedgerTransaction t) => t.amount));

  /// How many payments batch 1 carries under [limit] ops and [maxItems]
  /// money items. Throws [StateError] when the schedule itself does not
  /// fit next to the contract (never at the default 450 ops: 366 + 4).
  int firstPaymentCount({
    int limit = maxOpsPerBatch,
    int maxItems = maxLedgerItemsPerBatch,
  }) {
    final fixed = 3 + installments.length; // contract, disb, nextLoanNo
    int fits(int room) => room < 0
        ? 0
        : <int>[
            payments.length,
            room,
            maxItems,
          ].reduce((int a, int b) => a < b ? a : b);
    if (fixed > limit) {
      throw StateError(
        'The schedule ($fixed ops) does not fit one batch of $limit.',
      );
    }
    final k = fits(limit - fixed);
    if (k == payments.length) return k;
    // More remain: batch 1 also carries the queue doc.
    if (fixed + 1 > limit) {
      throw StateError('No room for the onboarding queue (limit $limit).');
    }
    return fits(limit - fixed - 1);
  }

  /// The batch layout under [limit] / [maxItems].
  OnboardingLayout layout({
    int limit = maxOpsPerBatch,
    int maxItems = maxLedgerItemsPerBatch,
  }) {
    final k = firstPaymentCount(limit: limit, maxItems: maxItems);
    final later = onboardingChunks(
      payments.skip(k).toList(),
      maxItems: maxItems < limit - 1 ? maxItems : limit - 1,
    );
    return OnboardingLayout(
      installments: installments.length,
      firstPayments: k,
      laterSizes: <int>[for (final c in later) c.length],
      hasQueue: k < payments.length,
      sums: <Money>[
        Money.sum(payments.take(k).map((LedgerTransaction t) => t.amount)),
        for (final c in later)
          Money.sum(c.map((LedgerTransaction t) => t.amount)),
      ],
    );
  }

  /// The sync list of the payments after batch 1, or null when batch 1
  /// holds them all.
  OnboardingQueue? queue({
    int limit = maxOpsPerBatch,
    int maxItems = maxLedgerItemsPerBatch,
  }) {
    final k = firstPaymentCount(limit: limit, maxItems: maxItems);
    if (k == payments.length) return null;
    return OnboardingQueue(
      contractId: contract.id,
      status: OnboardingQueueStatus.pending,
      createdBy: contract.createdBy,
      entries: <QueuedPayment>[
        for (final p in payments.skip(k))
          QueuedPayment(
            id: p.id,
            paidOn: p.paidOn,
            amount: p.amount,
            mode: p.mode!,
            reference: p.reference,
            openingBalance: p.openingBalance,
          ),
      ],
    );
  }

  /// Batch 1: contract, installments, disbursement, `nextLoanNo`, the
  /// queue doc (when more payments remain) and the first payments. The
  /// contract's `totalPaidPaise` is `increment(Σ batch-1 payments)`.
  WriteBatch firstBatch(
    FirebaseFirestore db,
    String cid, {
    int limit = maxOpsPerBatch,
    int maxItems = maxLedgerItemsPerBatch,
  }) {
    final refs = TypedRefs(db);
    final c = contract;
    final k = firstPaymentCount(limit: limit, maxItems: maxItems);
    final first = payments.take(k).toList();
    final sum = Money.sum(first.map((LedgerTransaction t) => t.amount));
    final b = db.batch()
      ..set(db.doc(FirestorePaths.contract(cid, c.id)), <String, Object?>{
        ...ModelCodecs.contract.toFirestore(c, null),
        'totalPaidPaise': FieldValue.increment(sum.paise),
      });
    for (final i in installments) {
      b.set(refs.installment(cid, i.id), i);
    }
    final d = base.disbursement;
    if (d != null) b.set(refs.transaction(cid, d.id), d);
    b.update(db.doc(FirestorePaths.company(cid)), <String, Object?>{
      'nextLoanNo': FieldValue.increment(1),
    });
    final q = queue(limit: limit, maxItems: maxItems);
    if (q != null) {
      b.set(db.doc(FirestorePaths.onboardingQueue(cid, c.id)), q.toFirestore());
    }
    for (final p in first) {
      b.set(refs.transaction(cid, p.id), p);
    }
    return b;
  }
}

/// Splits [items] into consecutive groups of at most [maxItems].
List<List<T>> onboardingChunks<T>(List<T> items, {required int maxItems}) {
  if (maxItems < 1) throw ArgumentError.value(maxItems, 'maxItems');
  return <List<T>>[
    for (var i = 0; i < items.length; i += maxItems)
      items.sublist(
        i,
        i + maxItems < items.length ? i + maxItems : items.length,
      ),
  ];
}

/// One onboarding `payment` transaction of contract [c] (shared by the
/// planner and the resumer, so both write the same shape).
LedgerTransaction onboardingPaymentTx({
  required String id,
  required Contract c,
  required CivilDate paidOn,
  required Money amount,
  required PaymentMode mode,
  required LedgerActor actor,
  required DateTime now,
  String? reference,
  bool openingBalance = false,
}) => LedgerTransaction(
  id: id,
  contractId: c.id,
  borrowerId: c.borrowerId,
  borrowerName: c.borrowerName,
  loanNo: c.loanNo,
  type: TxType.payment,
  amount: amount,
  paidOn: paidOn,
  mode: mode,
  reference: optionalText(reference),
  note: openingBalance ? openingBalanceNote : null,
  origin: TxOrigin.onboarding,
  openingBalance: openingBalance,
  recordedBy: actor.uid,
  recordedByName: actor.name,
  clientRecordedAt: now,
  deviceId: actor.deviceId,
);

/// Builds the docs of an onboarding from already validated inputs. Every
/// id is a client uuid v4 drawn once here, so a retried batch is
/// idempotent. Every payment must have a mode (see `validateOnboarding`).
OnboardingPlan planOnboarding({
  required LoanTermsInput terms,
  required List<PastPaymentInput> pastPayments,
  required CivilDate today,
  required String contractId,
  required String borrowerId,
  required String borrowerName,
  required String borrowerPhoneE164,
  required DateTime now,
  required Uuid uuid,
  String? previousRef,
}) {
  final base = planNewContract(
    cmd: terms,
    contractId: contractId,
    borrowerId: borrowerId,
    borrowerName: borrowerName,
    borrowerPhoneE164: borrowerPhoneE164,
    now: now,
    uuid: uuid,
    origin: ContractOrigin.onboarded,
    onboardedOn: today,
    previousRef: previousRef,
  );
  final c = base.contract;
  // Oldest first; equal dates keep their input order.
  final ordered =
      <(int, PastPaymentInput)>[
        for (var i = 0; i < pastPayments.length; i++) (i, pastPayments[i]),
      ]..sort((a, b) {
        final byDate = a.$2.paidOn.compareTo(b.$2.paidOn);
        return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
      });
  final payments = <LedgerTransaction>[
    for (final (_, p) in ordered)
      onboardingPaymentTx(
        id: uuid.v4(),
        c: c,
        paidOn: p.paidOn,
        amount: p.amount,
        mode: p.mode ?? (throw ArgumentError('Past payment without a mode')),
        reference: p.reference,
        openingBalance: p.openingBalance,
        actor: terms.actor,
        now: now,
      ),
  ];
  final total = Money.sum(payments.map((LedgerTransaction t) => t.amount));
  return OnboardingPlan(
    base: NewContractPlan(
      contract: c.copyWith(
        totalPaid: total,
        lastPaymentOn: payments.isEmpty ? null : payments.last.paidOn,
        onboardedPaymentCount: payments.length,
        onboardedTotal: total,
      ),
      installments: base.installments,
      disbursement: base.disbursement,
    ),
    payments: payments,
  );
}
