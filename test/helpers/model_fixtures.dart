import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/models/models.dart';

/// Realistic, fully-populated model instances shared by the model and
/// converter tests. All timestamps are UTC (the domain convention).
abstract final class Fixtures {
  static final DateTime t0 = DateTime.utc(2026, 11, 20, 4, 30, 15, 123);
  static final DateTime t1 = DateTime.utc(2026, 11, 21, 9, 5);

  /// ₹1,00,000.
  static const Money oneLakh = Money(10000000);

  static final AppUser appUser = AppUser(
    id: 'uid-owner',
    displayName: 'Ravi Kumar',
    email: 'ravi@example.com',
    photoUrl: 'https://example.com/ravi.png',
    phoneE164: '+919845012890',
    createdAt: t0,
  );

  static final Membership membership = Membership(
    id: 'cmp-1',
    companyId: 'cmp-1',
    companyName: 'Sri Lakshmi Finance',
    role: Role.owner,
    joinedAt: t0,
  );

  static final UserSettings userSettings = UserSettings(
    id: 'uid-owner',
    activeCompanyId: 'cmp-1',
    notifications: const NotificationPrefs(
      digestTime: '07:30',
      perInstallmentEnabled: true,
    ),
    autoLockMinutes: 5,
    updatedAt: t1,
  );

  static final Company company = Company(
    id: 'cmp-1',
    name: 'Sri Lakshmi Finance',
    nameLower: 'sri lakshmi finance',
    city: 'Bengaluru',
    phoneE164: '+919845012890',
    ownerUids: const <String>['uid-owner'],
    nextLoanNo: 42,
    createdBy: 'uid-owner',
    createdAt: t0,
  );

  static final Member member = Member(
    id: 'uid-col',
    uid: 'uid-col',
    role: Role.collector,
    displayName: 'Suresh',
    phoneE164: '+919900112233',
    inviteCode: 'ABCD1234',
    invitedBy: 'uid-owner',
    joinedAt: t1,
  );

  static final Invite invite = Invite(
    id: 'ABCD1234',
    companyId: 'cmp-1',
    companyName: 'Sri Lakshmi Finance',
    companyCity: 'Bengaluru',
    role: Role.collector,
    inviteeName: 'Suresh',
    inviteePhoneE164: '+919900112233',
    createdBy: 'uid-owner',
    createdByName: 'Ravi Kumar',
    createdAt: t0,
    expiresAt: t0.add(Invite.validity),
    status: InviteStatus.accepted,
    acceptedBy: 'uid-col',
    acceptedAt: t1,
  );

  static final Borrower borrower = Borrower(
    id: 'bor-1',
    name: 'Anita Sharma',
    nameLower: 'anita sharma',
    phoneE164: '+919812345678',
    locality: 'Jayanagar',
    notes: 'Runs a vegetable stall',
    createdBy: 'uid-owner',
    createdAt: t0,
    updatedAt: t1,
  );

  static final Contract contract = Contract(
    id: 'con-1',
    borrowerId: 'bor-1',
    borrowerName: 'Anita Sharma',
    borrowerPhoneE164: '+919812345678',
    loanNo: 41,
    purpose: 'Stock',
    status: ContractStatus.rolledOver,
    sanctioned: oneLakh,
    upfrontMode: UpfrontMode.percent,
    upfrontInput: 700,
    upfront: const Money(700000),
    netDisbursed: const Money(9300000),
    frequency: Frequency.weekly,
    preferredWeekday: 2,
    preferredMonthDay: 15,
    installmentAmount: const Money(1000000),
    baseInstallmentCount: 10,
    firstDueDate: const CivilDate(2026, 11, 24),
    disbursedOn: const CivilDate(2026, 11, 17),
    guarantor: 'Mohan Sharma',
    notes: 'Second loan',
    totalPaid: const Money(3000000),
    lastPaymentOn: const CivilDate(2026, 12, 8),
    closedAt: t1,
    rolledOverFromContractId: 'con-0',
    rolledOverToContractId: 'con-2',
    rolloverSettled: const Money(2500050),
    createdBy: 'uid-owner',
    createdAt: t0,
    updatedAt: t1,
  );

  static final Installment installment = Installment(
    id: 'ins-11',
    contractId: 'con-1',
    borrowerId: 'bor-1',
    borrowerName: 'Anita Sharma',
    loanNo: 41,
    contractActive: false,
    seq: 11,
    kind: InstallmentKind.rescheduled,
    dueDate: const CivilDate(2027, 2, 2),
    amountDue: const Money(500000),
    rescheduledOut: const Money(100000),
    rescheduledToIds: const <String>['ins-12'],
    rescheduledFromId: 'ins-3',
    createdBy: 'uid-col',
    createdAt: t1,
  );

  static final LedgerTransaction transaction = LedgerTransaction(
    id: 'tx-1',
    contractId: 'con-1',
    borrowerId: 'bor-1',
    borrowerName: 'Anita Sharma',
    loanNo: 41,
    type: TxType.rolloverSettlement,
    amount: const Money(2500050),
    paidOn: const CivilDate(2026, 12, 8),
    mode: PaymentMode.upi,
    reference: 'UPI-REF-1',
    note: 'Settled on rollover',
    reversesTxId: 'tx-0',
    relatedContractId: 'con-2',
    rescheduleInfo: const <String, dynamic>{
      'fromInstallmentId': 'ins-3',
      'toDueDate': '2027-02-02',
      'amountPaise': 100000,
    },
    recordedBy: 'uid-col',
    recordedByName: 'Suresh',
    recordedAt: t1,
    clientRecordedAt: t0,
    deviceId: 'device-abc',
  );
}
