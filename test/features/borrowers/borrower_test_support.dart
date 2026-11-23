import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/core/firebase/firebase_providers.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/clock_provider.dart';
import 'package:nordic_ledger/core/time/ist_clock.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/borrowers/application/borrower_providers.dart';
import 'package:nordic_ledger/features/borrowers/data/contact_launcher.dart';
import 'package:nordic_ledger/features/company/application/company_providers.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/ledger/ledger_fixtures.dart';

const String kCid = 'co-1';
const String kOwnerUid = 'uid-owner';

/// "Today" for every borrower fixture: Tue 7 Nov 2023, 10:00 IST.
FixedClock fixtureClock() => FixedClock.ist(2023, 11, 7, 10);
final CivilDate kToday = d(2023, 11, 7);

final DateTime _t = DateTime.utc(2023, 10, 1);

Borrower borrowerDoc(
  String id,
  String name,
  String phoneE164, {
  String? locality,
}) => Borrower(
  id: id,
  name: name,
  nameLower: name.toLowerCase(),
  phoneE164: phoneE164,
  locality: locality,
  createdBy: kOwnerUid,
  createdAt: _t,
  updatedAt: _t,
);

/// Contract for [borrowerId] with a generated schedule.
Contract contractFor(
  String borrowerId,
  String id, {
  required int loanNo,
  required int sanctionedRs,
  required int installmentRs,
  required CivilDate firstDue,
  int weekday = 2,
  ContractStatus status = ContractStatus.active,
  int totalPaidRs = 0,
  String? rolledOverToContractId,
}) =>
    makeContract(
      id: id,
      loanNo: loanNo,
      sanctioned: rs(sanctionedRs),
      installment: rs(installmentRs),
      firstDue: firstDue,
      weekday: weekday,
      status: status,
    ).copyWith(
      borrowerId: borrowerId,
      totalPaid: rs(totalPaidRs),
      rolledOverToContractId: rolledOverToContractId,
    );

LedgerTransaction txFor(
  Contract c,
  String id,
  int amountRs,
  CivilDate paidOn, {
  TxType type = TxType.payment,
  PaymentMode? mode = PaymentMode.cash,
  String? reversesTxId,
}) =>
    tx(
      c.id,
      rs(amountRs),
      paidOn,
      type: type,
      id: id,
      reversesTxId: reversesTxId,
    ).copyWith(
      borrowerId: c.borrowerId,
      loanNo: c.loanNo,
      contractActive: c.status == ContractStatus.active,
      // A reversal copies its original's mode (reversePayment); a payment
      // reversal therefore carries one.
      mode: type == TxType.payment || type == TxType.reversal ? mode : null,
    );

/// Everything a fixture writes.
final class LedgerSeed {
  final List<Borrower> borrowers = <Borrower>[];
  final List<Contract> contracts = <Contract>[];
  final List<LedgerTransaction> transactions = <LedgerTransaction>[];

  Future<void> writeTo(FakeFirebaseFirestore db, {String cid = kCid}) async {
    final refs = TypedRefs(db);
    for (final b in borrowers) {
      await refs.borrower(cid, b.id).set(b);
    }
    for (final c in contracts) {
      await refs.contract(cid, c.id).set(c);
      for (final i in scheduleFor(c)) {
        await refs
            .installment(cid, i.id)
            .set(
              i.copyWith(
                borrowerId: c.borrowerId,
                contractActive: c.status == ContractStatus.active,
              ),
            );
      }
    }
    for (final t in transactions) {
      await refs.transaction(cid, t.id).set(t);
    }
  }
}

/// The aggregates fixture: borrower b1 (Anita Sharma) with
/// - C1 Loan #04 active: ₹1,00,000 weekly ₹10,000 from Tue 31 Oct; paid
///   ₹10,000 on 31 Oct → 7 Nov installment due today. Outstanding ₹90,000.
/// - C2 Loan #05 active: ₹50,000 weekly ₹5,000 from Tue 24 Oct; paid
///   ₹5,000 on 24 Oct, ₹2,000 on 1 Nov reversed on 2 Nov → 31 Oct overdue
///   7 days. Outstanding ₹45,000.
/// - C3 Loan #02 closed: ₹30,000 paid in full on 30 Sep (rolled over to C1).
///
/// Hand-computed: exposure ₹1,35,000; lifetime lent ₹1,80,000; collected
/// ₹45,000 (10,000 + 5,000 + 2,000 − 2,000 + 30,000).
LedgerSeed aggregatesFixture() {
  final seed = LedgerSeed();
  seed.borrowers.addAll(<Borrower>[
    borrowerDoc('b1', 'Anita Sharma', '+919845012890', locality: 'Anna Nagar'),
  ]);
  final c1 = contractFor(
    'b1',
    'c1',
    loanNo: 4,
    sanctionedRs: 100000,
    installmentRs: 10000,
    firstDue: d(2023, 10, 31),
    totalPaidRs: 10000,
  );
  final c2 = contractFor(
    'b1',
    'c2',
    loanNo: 5,
    sanctionedRs: 50000,
    installmentRs: 5000,
    firstDue: d(2023, 10, 24),
    totalPaidRs: 5000,
  );
  final c3 = contractFor(
    'b1',
    'c3',
    loanNo: 2,
    sanctionedRs: 30000,
    installmentRs: 10000,
    firstDue: d(2023, 9, 5),
    status: ContractStatus.rolledOver,
    totalPaidRs: 30000,
    rolledOverToContractId: 'c1',
  );
  seed.contracts.addAll(<Contract>[c1, c2, c3]);
  seed.transactions.addAll(<LedgerTransaction>[
    txFor(c1, 't-c1-disb', 93000, d(2023, 10, 24), type: TxType.disbursement),
    txFor(c1, 't-c1-p1', 10000, d(2023, 10, 31), mode: PaymentMode.upi),
    txFor(c2, 't-c2-p1', 5000, d(2023, 10, 24)),
    txFor(c2, 't-c2-p2', 2000, d(2023, 11, 1)),
    txFor(
      c2,
      't-c2-rev',
      2000,
      d(2023, 11, 2),
      type: TxType.reversal,
      reversesTxId: 't-c2-p2',
    ),
    txFor(c3, 't-c3-p1', 30000, d(2023, 9, 30), mode: PaymentMode.bank),
  ]);
  return seed;
}

/// Four borrowers for the search / filter tests:
/// - b1 Anita Sharma: overdue (the aggregates fixture's contracts);
/// - b2 Ravi Kumar: due Thu 9 Nov (this week), nothing overdue;
/// - b3 Meena Iyer: no contracts;
/// - b4 Suresh Verma: first due 20 Nov (on track, not this week).
LedgerSeed listFixture() {
  final seed = aggregatesFixture();
  seed.borrowers.addAll(<Borrower>[
    borrowerDoc('b2', 'Ravi Kumar', '+919900112233'),
    borrowerDoc('b3', 'Meena Iyer', '+917012345678'),
    borrowerDoc('b4', 'Suresh Verma', '+918123456789'),
  ]);
  seed.contracts.addAll(<Contract>[
    contractFor(
      'b2',
      'c4',
      loanNo: 6,
      sanctionedRs: 20000,
      installmentRs: 2000,
      firstDue: d(2023, 11, 9),
      weekday: 4,
    ),
    contractFor(
      'b4',
      'c5',
      loanNo: 7,
      sanctionedRs: 40000,
      installmentRs: 4000,
      firstDue: d(2023, 11, 20),
      weekday: 1,
    ),
  ]);
  return seed;
}

/// Records dialer / WhatsApp launches.
final class LaunchLog {
  final List<Uri> launched = <Uri>[];

  ContactLauncher launcher() => ContactLauncher(
    launch: (Uri uri, LaunchMode mode) async {
      launched.add(uri);
      return true;
    },
  );
}

/// Provider overrides for an active company [kCid] with [role].
List<Override> borrowerOverrides(
  FakeFirebaseFirestore db, {
  Role role = Role.owner,
  FixedClock? clock,
  LaunchLog? launches,
}) => <Override>[
  firestoreProvider.overrideWithValue(db),
  clockProvider.overrideWithValue(clock ?? fixtureClock()),
  activeCompanyIdProvider.overrideWithValue(const AsyncData<String?>(kCid)),
  currentUidProvider.overrideWithValue(kOwnerUid),
  currentRoleProvider.overrideWithValue(role),
  activeCompanyNameProvider.overrideWithValue('Sri Lakshmi Finance'),
  if (launches != null)
    contactLauncherProvider.overrideWithValue(launches.launcher()),
];

/// Lets fake Firestore snapshots propagate through the providers.
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Money inr(int rupees) => Money.fromRupees(rupees);
