import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/money/inr_format.dart';
import '../../../core/money/money.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/time/clock_provider.dart';
import '../../../core/time/today_provider.dart';
import '../../../domain/ledger/ledger.dart';
import '../../../domain/models/models.dart';
import '../../company/application/company_providers.dart';
import '../../contracts/application/contract_providers.dart';
import '../../contracts/application/loan_label.dart';
import '../data/payment_repository.dart';

part 'payment_providers.g.dart';

/// How far back a collection date may go.
const int maxBackdateDays = 30;

@Riverpod(keepAlive: true)
PaymentRepository paymentRepository(Ref ref) => PaymentRepository(
  firestore: ref.watch(firestoreProvider),
  clock: ref.watch(clockProvider),
);

/// The live docs behind a [ContractView], for the write paths.
extension ContractViewSnapshot on ContractView {
  ContractSnapshot get snapshot => ContractSnapshot(
    contract: contract,
    installments: installments.values.toList(),
    transactions: transactions,
  );
}

/// The record sheet's quick amounts, derived from the projection.
final class QuickAmounts {
  const QuickAmounts({required this.fullDue, required this.advance});

  /// What is left of the next open installment (capped at outstanding).
  final Money fullDue;

  /// The next two open installments, or the outstanding when smaller.
  final Money advance;

  factory QuickAmounts.of(ContractProjection p) {
    final open = p.rows
        .where((ProjectedRow r) => r.isOpen && !r.isExtension)
        .toList();
    final next = p.nextDue?.remaining ?? Money.zero;
    final two = Money.sum(open.take(2).map((ProjectedRow r) => r.remaining));
    return QuickAmounts(
      fullDue: Money.min(next, p.outstanding),
      advance: Money.min(two.isPositive ? two : next, p.outstanding),
    );
  }
}

/// Validation for the record sheet: > 0 and ≤ outstanding, except on a
/// rolled-over contract (a late payment there surfaces as excess).
List<ValidationError> validateRecordAmount(
  Money? amount,
  Contract c,
  Money outstanding,
) {
  final a = amount ?? Money.zero;
  return c.status == ContractStatus.rolledOver
      ? validatePaymentAmount(a, a)
      : validatePaymentAmount(a, outstanding);
}

/// The receipt text sent from the user's own phone. With a positive
/// [waived] (close with waiver) the balance line becomes
/// "Loan #N closed (₹W waived)."; with no cash it starts there.
String receiptMessage({
  required Money amount,
  required String borrowerName,
  required int loanNo,
  required CivilDate paidOn,
  required PaymentMode? mode,
  required Money balance,
  required String? companyName,
  Money waived = Money.zero,
}) {
  final company = companyName == null || companyName.isEmpty
      ? ''
      : ' — $companyName';
  final via = mode == null ? '' : ' via ${paymentModeLabel(mode)}';
  final received = amount.isPositive
      ? 'Received ${formatInr(amount)} from $borrowerName for '
            '${loanLabel(loanNo)} on ${formatCivilDate(paidOn)}$via. '
      : '';
  final tail = waived.isPositive
      ? '${loanLabel(loanNo)} closed (${formatInr(waived)} waived).'
      : 'Balance: ${formatInr(balance)}.';
  return '$received$tail$company';
}

/// Cash + waiver figures for the "Settle for less" close: the waiver is
/// what the cash leaves of the outstanding.
final class WaiverSplit {
  const WaiverSplit({required this.cash, required this.outstanding});

  final Money cash;
  final Money outstanding;

  Money get waiver => outstanding - cash;

  /// Null when valid, else the message to show under the cash field.
  String? get error {
    if (cash.isNegative) return 'Cash received cannot be negative.';
    if (cash >= outstanding) {
      return 'Cash must be less than the outstanding '
          '${formatInr(outstanding)} to waive the rest.';
    }
    return null;
  }
}

/// Payment use-cases: record (owner or collector) and reverse (owner; the
/// rules enforce it).
@Riverpod(keepAlive: true)
PaymentActions paymentActions(Ref ref) => PaymentActions(ref);

class PaymentActions {
  PaymentActions(this._ref);

  final Ref _ref;

  Future<PaymentWriteResult> record({
    required ContractView view,
    required Money amount,
    required CivilDate paidOn,
    required PaymentMode mode,
    String? reference,
    String? note,
  }) async {
    final actor = await readLedgerActor(_ref);
    return _ref
        .read(paymentRepositoryProvider)
        .recordPayment(
          RecordPaymentCommand(
            cid: requireActiveCid(_ref),
            snapshot: view.snapshot,
            amount: amount,
            paidOn: paidOn,
            mode: mode,
            reference: reference,
            note: note,
            actor: actor,
          ),
        );
  }

  /// Owner only: close the loan for [cash] plus a [waiver] discount.
  Future<WaiverWriteResult> closeWithWaiver({
    required ContractView view,
    required Money cash,
    required Money waiver,
    required String reason,
    required CivilDate paidOn,
    PaymentMode? mode,
    String? reference,
  }) async {
    final actor = await readLedgerActor(_ref);
    return _ref
        .read(paymentRepositoryProvider)
        .closeWithWaiver(
          CloseWithWaiverCommand(
            cid: requireActiveCid(_ref),
            snapshot: view.snapshot,
            cashAmount: cash,
            waiverAmount: waiver,
            reason: reason,
            paidOn: paidOn,
            mode: mode,
            reference: reference,
            actor: actor,
            role: _ref.read(currentRoleProvider),
          ),
        );
  }

  Future<PaymentWriteResult> reverse({
    required ContractView view,
    required String transactionId,
    required String reason,
  }) async {
    final actor = await readLedgerActor(_ref);
    return _ref
        .read(paymentRepositoryProvider)
        .reversePayment(
          ReversePaymentCommand(
            cid: requireActiveCid(_ref),
            snapshot: view.snapshot,
            transactionId: transactionId,
            reason: reason,
            today: _ref.read(todayProvider),
            actor: actor,
          ),
        );
  }

  /// Owner only: reverse every unreversed opening-balance payment of an
  /// onboarded contract (each dated on its original date).
  Future<PaymentWriteResult> reverseOpeningBalance({
    required ContractView view,
    required String reason,
  }) async {
    final actor = await readLedgerActor(_ref);
    return _ref
        .read(paymentRepositoryProvider)
        .reverseOpeningBalance(
          ReverseOpeningCommand(
            cid: requireActiveCid(_ref),
            snapshot: view.snapshot,
            reason: reason,
            actor: actor,
            role: _ref.read(currentRoleProvider),
          ),
        );
  }
}
