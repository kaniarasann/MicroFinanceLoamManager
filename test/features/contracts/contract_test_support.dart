import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/core/time/ist_clock.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/auth/application/device_id_provider.dart';
import 'package:nordic_ledger/features/company/application/company_providers.dart';
import 'package:nordic_ledger/features/contracts/application/contract_providers.dart';
import 'package:nordic_ledger/features/contracts/data/contract_repository.dart';

import '../../domain/ledger/ledger_fixtures.dart';
import '../borrowers/borrower_test_support.dart';

export '../../domain/ledger/ledger_fixtures.dart';
export '../borrowers/borrower_test_support.dart';

const LedgerActor kActor = LedgerActor(
  uid: kOwnerUid,
  name: 'Ravi',
  deviceId: 'dev-1',
);

final DateTime _t = DateTime.utc(2023, 10, 1);

/// 10:00 IST on [day].
FixedClock clockAt(CivilDate day) =>
    FixedClock.ist(day.year, day.month, day.day, 10);

Company companyDoc({int nextLoanNo = 3}) => Company(
  id: kCid,
  name: 'Sri Lakshmi Finance',
  nameLower: 'sri lakshmi finance',
  ownerUids: const <String>[kOwnerUid],
  nextLoanNo: nextLoanNo,
  createdBy: kOwnerUid,
  createdAt: _t,
);

Borrower anita() =>
    borrowerDoc('b1', 'Anita Sharma', '+919845012890', locality: 'Anna Nagar');

/// The Stitch contract (Loan #04, ₹1,00,000, 10 × ₹10,000 weekly on
/// Tuesdays from 31 Oct 2023) with ₹10,000 × 3 + ₹6,000 paid; viewed on
/// 3 Dec 2023: inst 4 partial, inst 5 missed → Installment 11 / 12 added.
LedgerSeed stitchSeed() {
  final seed = LedgerSeed()..borrowers.add(anita());
  final c = contractFor(
    'b1',
    'c1',
    loanNo: 4,
    sanctionedRs: 100000,
    installmentRs: 10000,
    firstDue: d(2023, 10, 31),
    totalPaidRs: 36000,
  ).copyWith(purpose: 'Shop stock');
  seed.contracts.add(c);
  seed.transactions.addAll(<LedgerTransaction>[
    txFor(c, 'tx-d', 93000, d(2023, 10, 24), type: TxType.disbursement),
    txFor(c, 'tx-1', 10000, d(2023, 10, 31), mode: PaymentMode.upi),
    txFor(c, 'tx-2', 10000, d(2023, 11, 7)),
    txFor(c, 'tx-3', 10000, d(2023, 11, 14), mode: PaymentMode.bank),
    txFor(c, 'tx-4', 6000, d(2023, 11, 21)),
  ]);
  return seed;
}

/// "Today" for the Stitch timeline: Sun 3 Dec 2023.
final CivilDate kStitchToday = d(2023, 12, 3);

Future<void> seedCompany(FakeFirebaseFirestore db, {int nextLoanNo = 3}) =>
    TypedRefs(db).company(kCid).set(companyDoc(nextLoanNo: nextLoanNo));

/// [borrowerOverrides] plus the company doc stream and a fixed device id.
List<Override> contractOverrides(
  FakeFirebaseFirestore db, {
  Role role = Role.owner,
  int nextLoanNo = 3,
  CivilDate? today,
}) => <Override>[
  ...borrowerOverrides(
    db,
    role: role,
    clock: today == null ? null : clockAt(today),
  ),
  activeCompanyProvider.overrideWith(
    (Ref ref) => Stream<Company?>.value(companyDoc(nextLoanNo: nextLoanNo)),
  ),
  deviceIdProvider.overrideWith((Ref ref) async => 'dev-1'),
  ledgerActorNameProvider.overrideWithValue('Ravi'),
];
