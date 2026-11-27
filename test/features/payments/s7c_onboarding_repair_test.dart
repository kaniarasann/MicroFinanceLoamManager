import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/contracts/data/contract_repository.dart';
import 'package:nordic_ledger/features/payments/data/payment_repository.dart';

import 'payment_test_support.dart';

/// Onboarding "today": Mon 24 Nov 2026.
final CivilDate _today = d(2026, 11, 24);

/// Sprint 7c: the L2 reversal guards and the M2 repair path ("Add missing
/// onboarding payment" + [OnboardingSync]).
void main() {
  late FakeFirebaseFirestore db;
  late ContractRepository contracts;
  late PaymentRepository payments;

  setUp(() async {
    db = FakeFirebaseFirestore();
    contracts = ContractRepository(firestore: db, clock: clockAt(_today));
    payments = PaymentRepository(firestore: db, clock: clockAt(_today));
    await seedCompany(db);
  });

  List<PlannedInstallment> weeklySchedule() => generateSchedule(
    sanctioned: rs(100000),
    installmentAmount: rs(10000),
    frequency: Frequency.weekly,
    firstDueDate: d(2026, 9, 1),
    preferredWeekday: 2,
  );

  Future<String> onboard(List<PastPaymentInput> past) async {
    final r = await contracts.onboardContract(
      OnboardContractCommand(
        cid: kCid,
        borrower: anita(),
        sanctioned: rs(100000),
        upfrontMode: UpfrontMode.flat,
        upfrontInput: 0,
        installmentAmount: rs(10000),
        frequency: Frequency.weekly,
        preferredWeekday: 2,
        firstDueDate: d(2026, 9, 1),
        disbursedOn: d(2026, 8, 25),
        cachedNextLoanNo: 3,
        actor: kActor,
        role: Role.owner,
        today: _today,
        pastPayments: past,
      ),
    );
    return r.id;
  }

  List<PastPaymentInput> opening(int rupees) => spreadOpeningTotal(
    schedule: weeklySchedule(),
    total: rs(rupees),
    mode: PaymentMode.cash,
    disbursedOn: d(2026, 8, 25),
    today: _today,
  );

  /// The snapshot with its contract moved to [status].
  ContractSnapshot withStatus(ContractSnapshot s, ContractStatus status) =>
      ContractSnapshot(
        contract: s.contract.copyWith(status: status),
        installments: s.installments,
        transactions: s.transactions,
      );

  group('L2: no reversal on rolled-over or cancelled contracts', () {
    for (final status in <ContractStatus>[
      ContractStatus.rolledOver,
      ContractStatus.cancelled,
    ]) {
      test('reversePayment on ${status.name}: ValidationFailure, nothing '
          'written', () async {
        final id = await onboard(opening(30000));
        final snap = withStatus(await readSnapshot(db, id), status);
        final pay = snap.transactions.firstWhere(
          (LedgerTransaction t) => t.type == TxType.payment,
        );
        await expectLater(
          payments.reversePayment(
            ReversePaymentCommand(
              cid: kCid,
              snapshot: snap,
              transactionId: pay.id,
              reason: 'Wrong',
              today: _today,
              actor: kActor,
            ),
          ),
          throwsA(
            isA<ValidationFailure>().having(
              (ValidationFailure f) => f.message,
              'message',
              contains('can no longer be reversed'),
            ),
          ),
        );
        expect(
          (await rawDocs(
            db,
            'transactions',
            id,
          )).where((Map<String, dynamic> m) => m['type'] == 'reversal'),
          isEmpty,
        );
      });

      test(
        'reverseOpeningBalance on ${status.name}: ValidationFailure',
        () async {
          final id = await onboard(opening(30000));
          final snap = withStatus(await readSnapshot(db, id), status);
          await expectLater(
            payments.reverseOpeningBalance(
              ReverseOpeningCommand(
                cid: kCid,
                snapshot: snap,
                reason: 'Wrong',
                actor: kActor,
                role: Role.owner,
              ),
            ),
            throwsA(isA<ValidationFailure>()),
          );
          expect((await rawContract(db, id))['totalPaidPaise'], 3000000);
        },
      );
    }

    test('canReverseIn / reversalLockedMessage per status', () {
      expect(canReverseIn(ContractStatus.active), isTrue);
      expect(canReverseIn(ContractStatus.closed), isTrue);
      expect(canReverseIn(ContractStatus.rolledOver), isFalse);
      expect(canReverseIn(ContractStatus.cancelled), isFalse);
      expect(
        reversalLockedMessage(ContractStatus.cancelled),
        contains('cancelled'),
      );
    });
  });

  group('M2: OnboardingSync', () {
    test('complete after a full onboarding; a reversal does not lower the '
        'count', () async {
      final id = await onboard(opening(30000));
      final snap = await readSnapshot(db, id);
      final sync = OnboardingSync.of(snap)!;
      expect(sync.expected, 3);
      expect(sync.synced, 3);
      expect(sync.isIncomplete, isFalse);

      await payments.reversePayment(
        ReversePaymentCommand(
          cid: kCid,
          snapshot: snap,
          transactionId: snap.transactions
              .firstWhere((LedgerTransaction t) => t.type == TxType.payment)
              .id,
          reason: 'Entered twice',
          today: _today,
          actor: kActor,
        ),
      );
      expect(
        OnboardingSync.of(await readSnapshot(db, id))!.isIncomplete,
        isFalse,
      );
    });

    test('incomplete when a payment doc never landed', () async {
      final id = await onboard(opening(30000));
      final snap = await readSnapshot(db, id);
      final missing = snap.transactions.lastWhere(
        (LedgerTransaction t) => t.type == TxType.payment,
      );
      final partial = ContractSnapshot(
        contract: snap.contract,
        installments: snap.installments,
        transactions: <LedgerTransaction>[
          for (final t in snap.transactions)
            if (t.id != missing.id) t,
        ],
      );
      final sync = OnboardingSync.of(partial)!;
      expect(sync.synced, 2);
      expect(sync.expected, 3);
      expect(sync.isIncomplete, isTrue);
    });

    test(
      'null for standard contracts and onboarded docs without a count',
      () async {
        final id = await onboard(opening(10000));
        final snap = await readSnapshot(db, id);
        expect(
          OnboardingSync.of(
            ContractSnapshot(
              contract: snap.contract.copyWith(origin: ContractOrigin.standard),
              installments: snap.installments,
              transactions: snap.transactions,
            ),
          ),
          isNull,
        );
        expect(
          OnboardingSync.of(
            ContractSnapshot(
              contract: snap.contract.copyWith(onboardedPaymentCount: null),
              installments: snap.installments,
              transactions: snap.transactions,
            ),
          ),
          isNull,
        );
      },
    );
  });

  /// [s] without its [drop] newest onboarding payments, as a device sees a
  /// partly synced onboarding (later batches hold the newest payments).
  ContractSnapshot partial(ContractSnapshot s, {int drop = 1}) {
    final pays =
        s.transactions
            .where(
              (LedgerTransaction t) =>
                  t.type == TxType.payment && t.isOnboarding,
            )
            .toList()
          ..sort(
            (LedgerTransaction a, LedgerTransaction b) =>
                a.paidOn.compareTo(b.paidOn),
          );
    final gone = <String>{for (final t in pays.skip(pays.length - drop)) t.id};
    return ContractSnapshot(
      contract: s.contract,
      installments: s.installments,
      transactions: <LedgerTransaction>[
        for (final t in s.transactions)
          if (!gone.contains(t.id)) t,
      ],
    );
  }

  group('M2: addOnboardingPayment', () {
    AddOnboardingPaymentCommand cmd(
      ContractSnapshot snap, {
      int rupees = 10000,
      CivilDate? paidOn,
      Role? role = Role.owner,
      bool opening = false,
    }) => AddOnboardingPaymentCommand(
      cid: kCid,
      snapshot: snap,
      amount: rs(rupees),
      paidOn: paidOn ?? d(2026, 9, 15),
      mode: PaymentMode.upi,
      reference: ' Book 3 ',
      actor: kActor,
      role: role,
      openingBalance: opening,
    );

    test('writes an origin-onboarding payment on its date, increments the '
        'total, and keeps lastPaymentOn when it is older', () async {
      final id = await onboard(opening(20000)); // 1 + 8 Sep
      final snap = partial(await readSnapshot(db, id)); // 8 Sep "missing"
      final r = await payments.addOnboardingPayment(
        cmd(snap, paidOn: d(2026, 8, 30), rupees: 5000),
      );
      expect(r.closed, isFalse);
      expect(r.balanceAfter, rs(85000));
      final added = (await rawDocs(
        db,
        'transactions',
        id,
      )).singleWhere((Map<String, dynamic> m) => m['id'] == r.id);
      expect(added['type'], 'payment');
      expect(added['origin'], 'onboarding');
      expect(added['openingBalance'], false);
      expect(added['note'], isNull);
      expect(added['paidOn'], '2026-08-30');
      expect(added['mode'], 'upi');
      expect(added['reference'], 'Book 3');
      expect(added['recordedBy'], kOwnerUid);
      final c = await rawContract(db, id);
      expect(c['totalPaidPaise'], 2500000);
      expect(c['lastPaymentOn'], '2026-09-08');
      expect(c['onboardedPaymentCount'], 2);
      // The "missing" 8 Sep payment was only queued: once it is there too,
      // the repair shows as an overshoot of ₹5,000.
      final sync = OnboardingSync.of(await readSnapshot(db, id))!;
      expect(sync.synced, 3);
      expect(sync.isOvershoot, isTrue);
      expect(sync.overshoot, rs(5000));
    });

    test('a newer date moves lastPaymentOn forward; onboardedOn is the '
        'latest allowed date', () async {
      final id = await onboard(opening(20000));
      await payments.addOnboardingPayment(
        cmd(partial(await readSnapshot(db, id)), paidOn: _today),
      );
      expect((await rawContract(db, id))['lastPaymentOn'], '2026-11-24');
    });

    test('O1: on an opening-total loan the repair is an "Opening balance" '
        'row that Reverse opening balance also covers', () async {
      final id = await onboard(opening(30000));
      final snap = partial(await readSnapshot(db, id));
      expect(OnboardingSync.of(snap)!.isOpeningTotal, isTrue);
      final r = await payments.addOnboardingPayment(
        cmd(snap, paidOn: d(2026, 9, 15), opening: true),
      );
      final added = (await rawDocs(
        db,
        'transactions',
        id,
      )).singleWhere((Map<String, dynamic> m) => m['id'] == r.id);
      expect(added['openingBalance'], true);
      expect(added['note'], 'Opening balance');
      expect(
        unreversedOpeningBalance(
          await readSnapshot(db, id),
        ).map((LedgerTransaction t) => t.id),
        contains(r.id),
      );
    });

    test('R2 cap: at most onboardedTotal − Σ gross onboarding payments '
        '(reversed included), and never with nothing missing', () async {
      final id = await onboard(opening(30000));
      final full = await readSnapshot(db, id);
      await expectLater(
        payments.addOnboardingPayment(cmd(full, rupees: 100)),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure f) => f.message,
            'message',
            contains('Nothing is missing'),
          ),
        ),
      );
      final snap = partial(full); // ₹10,000 missing
      expect(OnboardingSync.of(snap)!.missing, rs(10000));
      expect(OnboardingSync.of(snap)!.repairCap(snap.outstanding), rs(10000));
      await expectLater(
        payments.addOnboardingPayment(cmd(snap, rupees: 10001)),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure f) => f.message,
            'message',
            contains('At most ₹10,000 is missing'),
          ),
        ),
      );
      // A reversed onboarding payment still counts as onboarded cash.
      final pay = full.transactions.firstWhere(
        (LedgerTransaction t) => t.type == TxType.payment,
      );
      await payments.reversePayment(
        ReversePaymentCommand(
          cid: kCid,
          snapshot: full,
          transactionId: pay.id,
          reason: 'Typo',
          today: _today,
          actor: kActor,
        ),
      );
      final afterRev = await readSnapshot(db, id);
      expect(OnboardingSync.of(afterRev)!.missing, Money.zero);
      expect(OnboardingSync.of(afterRev)!.isIncomplete, isFalse);
      expect((await rawContract(db, id))['totalPaidPaise'], 2000000);
    });

    test('refusals: collector, outside [disbursedOn, onboardedOn], over the '
        'balance, ₹0, standard or closed contracts', () async {
      final id = await onboard(opening(20000));
      final snap = partial(await readSnapshot(db, id));
      await expectLater(
        payments.addOnboardingPayment(cmd(snap, role: Role.collector)),
        throwsA(isA<PermissionDeniedFailure>()),
      );
      await expectLater(
        payments.addOnboardingPayment(cmd(snap, role: null)),
        throwsA(isA<PermissionDeniedFailure>()),
      );
      await expectLater(
        payments.addOnboardingPayment(cmd(snap, paidOn: d(2026, 8, 24))),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure f) => f.field,
            'field',
            LedgerFields.paidOn,
          ),
        ),
      );
      await expectLater(
        payments.addOnboardingPayment(cmd(snap, paidOn: d(2026, 11, 25))),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        payments.addOnboardingPayment(cmd(snap, rupees: 90001)),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        payments.addOnboardingPayment(cmd(snap, rupees: 0)),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        payments.addOnboardingPayment(
          cmd(
            ContractSnapshot(
              contract: snap.contract.copyWith(
                origin: ContractOrigin.standard,
                onboardedOn: null,
              ),
              installments: snap.installments,
              transactions: snap.transactions,
            ),
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        payments.addOnboardingPayment(
          cmd(withStatus(snap, ContractStatus.closed)),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      expect((await rawContract(db, id))['totalPaidPaise'], 2000000);
    });
  });

  group('O1: defaultRepairDate', () {
    test('the first due date after the newest landed payment', () async {
      final id = await onboard(opening(50000)); // 1 Sep … 29 Sep
      final snap = partial(await readSnapshot(db, id), drop: 2);
      // 22 Sep and 29 Sep missing: the gap starts on 22 Sep.
      expect(defaultRepairDate(snap, _today), d(2026, 9, 22));
    });

    test('nothing landed: the first due date', () async {
      final id = await onboard(opening(20000));
      final snap = partial(await readSnapshot(db, id), drop: 2);
      expect(defaultRepairDate(snap, _today), d(2026, 9, 1));
    });

    test('every row before today paid: the last due before today, never '
        'onboardedOn (= today)', () async {
      final id = await onboard(opening(90000)); // rows 1 Sep … 27 Oct
      final all = await readSnapshot(db, id);
      // Pretend row 10 (3 Nov) was paid too.
      final last = all.installments.firstWhere(
        (Installment i) => i.dueDate == d(2026, 11, 3),
      );
      final snap = ContractSnapshot(
        contract: all.contract,
        installments: all.installments,
        transactions: <LedgerTransaction>[
          ...all.transactions,
          tx(
            id,
            last.amountDue,
            last.dueDate,
            id: 'p-last',
          ).copyWith(origin: TxOrigin.onboarding),
        ],
      );
      final date = defaultRepairDate(snap, _today);
      expect(date, d(2026, 11, 3));
      expect(date == _today, isFalse);
    });
  });
}
