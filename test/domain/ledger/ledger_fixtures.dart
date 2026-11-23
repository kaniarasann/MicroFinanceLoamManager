import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';

/// Rupees → Money.
Money rs(int rupees) => Money.fromRupees(rupees);

/// Shorthand civil date.
CivilDate d(int y, int m, int day) => CivilDate(y, m, day);

final DateTime _t = DateTime.utc(2023, 10, 24);

Contract makeContract({
  String id = 'c1',
  int loanNo = 1,
  String borrowerName = 'Anita Sharma',
  Money? sanctioned,
  Money? installment,
  Frequency frequency = Frequency.weekly,
  int? weekday = 2,
  int? monthDay,
  CivilDate? firstDue,
  CivilDate? disbursedOn,
  ContractStatus status = ContractStatus.active,
  UpfrontMode upfrontMode = UpfrontMode.flat,
  int upfrontInput = 700000,
  Money? netDisbursed,
}) {
  final s = sanctioned ?? rs(100000);
  final inst = installment ?? rs(10000);
  final upfront = computeUpfront(s, upfrontMode, upfrontInput);
  return Contract(
    id: id,
    borrowerId: 'b-$id',
    borrowerName: borrowerName,
    borrowerPhoneE164: '+919812345678',
    loanNo: loanNo,
    status: status,
    sanctioned: s,
    upfrontMode: upfrontMode,
    upfrontInput: upfrontInput,
    upfront: upfront,
    netDisbursed: netDisbursed ?? computeNetDisbursed(s, upfront),
    frequency: frequency,
    preferredWeekday: weekday,
    preferredMonthDay: monthDay,
    installmentAmount: inst,
    baseInstallmentCount: inst.isPositive && s.isPositive
        ? installmentCount(s, inst)
        : 0,
    firstDueDate: firstDue ?? d(2023, 10, 31),
    disbursedOn: disbursedOn ?? d(2023, 10, 24),
    createdBy: 'uid-owner',
    createdAt: _t,
    updatedAt: _t,
  );
}

/// Base installments generated from the contract's terms.
List<Installment> scheduleFor(Contract c) =>
    generateSchedule(
          sanctioned: c.sanctioned,
          installmentAmount: c.installmentAmount,
          frequency: c.frequency,
          firstDueDate: c.firstDueDate,
          preferredWeekday: c.preferredWeekday,
          preferredMonthDay: c.preferredMonthDay,
        )
        .map(
          (PlannedInstallment p) => installment(c, p.seq, p.dueDate, p.amount),
        )
        .toList();

Installment installment(
  Contract c,
  int seq,
  CivilDate due,
  Money amount, {
  InstallmentKind kind = InstallmentKind.base,
  Money rescheduledOut = Money.zero,
  String? rescheduledFromId,
  String? id,
}) => Installment(
  id: id ?? '${c.id}-i$seq',
  contractId: c.id,
  borrowerId: c.borrowerId,
  borrowerName: c.borrowerName,
  loanNo: c.loanNo,
  seq: seq,
  kind: kind,
  dueDate: due,
  amountDue: amount,
  rescheduledOut: rescheduledOut,
  rescheduledFromId: rescheduledFromId,
  createdBy: 'uid-owner',
  createdAt: _t,
);

int _txSeq = 0;

LedgerTransaction tx(
  String contractId,
  Money amount,
  CivilDate paidOn, {
  TxType type = TxType.payment,
  String? id,
  String? reversesTxId,
  PaymentMode? mode,
  bool noMode = false,
}) => LedgerTransaction(
  id: id ?? 'tx-${_txSeq++}',
  contractId: contractId,
  borrowerId: 'b-$contractId',
  borrowerName: 'Borrower',
  loanNo: 1,
  type: type,
  amount: amount,
  paidOn: paidOn,
  reversesTxId: reversesTxId,
  // Real payments always carry a mode and reversals copy the original's;
  // waivers, disbursements and settlements carry none.
  mode: noMode
      ? null
      : mode ??
            (type == TxType.payment || type == TxType.reversal
                ? PaymentMode.upi
                : null),
  recordedBy: 'uid-col',
  recordedByName: 'Suresh',
  clientRecordedAt: _t,
  deviceId: 'dev',
);

ContractProjection project(
  Contract c,
  List<LedgerTransaction> txs,
  CivilDate today, {
  List<Installment>? installments,
}) => projectContract(
  contract: c,
  installments: installments ?? scheduleFor(c),
  transactions: txs,
  today: today,
);
