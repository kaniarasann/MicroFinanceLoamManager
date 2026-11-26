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

  /// The balanced batches of this plan:
  /// - batch 1: the contract (raw-map `set` with `totalPaidPaise:
  ///   increment(Σ batch-1 payments)`), the N installments, the
  ///   disbursement, the company `nextLoanNo: increment(1)` and the first
  ///   payments;
  /// - batches 2…m: up to `limit − 1` payments + a contract
  ///   `{totalPaidPaise: increment(Σ), updatedAt}` update.
  BalancedChunks chunks(
    FirebaseFirestore db,
    String cid, {
    int limit = maxOpsPerBatch,
  }) {
    final refs = TypedRefs(db);
    final c = contract;
    final contractRef = db.doc(FirestorePaths.contract(cid, c.id));
    final out = BalancedChunks(
      db,
      limit: limit,
      firstBalance: (WriteBatch b, Money sum) =>
          b.set(contractRef, <String, Object?>{
            ...ModelCodecs.contract.toFirestore(c, null),
            'totalPaidPaise': FieldValue.increment(sum.paise),
          }),
      laterBalance: (WriteBatch b, Money sum) =>
          b.update(contractRef, <String, Object?>{
            'totalPaidPaise': FieldValue.increment(sum.paise),
            'updatedAt': Timestamp.fromDate(c.updatedAt),
          }),
    );
    for (final i in installments) {
      out.fixed((WriteBatch b) => b.set(refs.installment(cid, i.id), i));
    }
    final d = base.disbursement;
    if (d != null) {
      out.fixed((WriteBatch b) => b.set(refs.transaction(cid, d.id), d));
    }
    out.fixed(
      (WriteBatch b) => b.update(
        db.doc(FirestorePaths.company(cid)),
        <String, Object?>{'nextLoanNo': FieldValue.increment(1)},
      ),
    );
    for (final p in payments) {
      out.item(
        (WriteBatch b) => b.set(refs.transaction(cid, p.id), p),
        p.amount,
      );
    }
    return out;
  }
}

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
      LedgerTransaction(
        id: uuid.v4(),
        contractId: c.id,
        borrowerId: c.borrowerId,
        borrowerName: c.borrowerName,
        loanNo: c.loanNo,
        type: TxType.payment,
        amount: p.amount,
        paidOn: p.paidOn,
        mode: p.mode ?? (throw ArgumentError('Past payment without a mode')),
        reference: optionalText(p.reference),
        note: p.openingBalance ? openingBalanceNote : null,
        origin: TxOrigin.onboarding,
        openingBalance: p.openingBalance,
        recordedBy: terms.actor.uid,
        recordedByName: terms.actor.name,
        clientRecordedAt: now,
        deviceId: terms.actor.deviceId,
      ),
  ];
  final total = Money.sum(payments.map((LedgerTransaction t) => t.amount));
  return OnboardingPlan(
    base: NewContractPlan(
      contract: c.copyWith(
        totalPaid: total,
        lastPaymentOn: payments.isEmpty ? null : payments.last.paidOn,
      ),
      installments: base.installments,
      disbursement: base.disbursement,
    ),
    payments: payments,
  );
}
