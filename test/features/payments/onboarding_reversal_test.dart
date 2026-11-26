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

  /// Onboards the ₹1,00,000 weekly loan (disbursed 25 Aug 2026) with
  /// [past] payments; returns the contract id.
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

  Future<List<Map<String, dynamic>>> reversals(String id) async =>
      <Map<String, dynamic>>[
        for (final m in await rawDocs(db, 'transactions', id))
          if (m['type'] == 'reversal') m,
      ];

  group('reversePayment of an onboarding payment', () {
    test('is dated on the original date and copies origin + mode', () async {
      final id = await onboard(<PastPaymentInput>[
        PastPaymentInput(
          paidOn: d(2026, 9, 8),
          amount: rs(10000),
          mode: PaymentMode.upi,
        ),
        PastPaymentInput(
          paidOn: d(2026, 9, 15),
          amount: rs(10000),
          mode: PaymentMode.bank,
        ),
      ]);
      final snap = await readSnapshot(db, id);
      final original = snap.transactions.firstWhere(
        (LedgerTransaction t) => t.paidOn == d(2026, 9, 15),
      );
      final r = await payments.reversePayment(
        ReversePaymentCommand(
          cid: kCid,
          snapshot: snap,
          transactionId: original.id,
          reason: 'Entered twice',
          today: _today,
          actor: kActor,
        ),
      );
      expect(r.balanceAfter, rs(90000));

      final rev = (await reversals(id)).single;
      expect(rev['paidOn'], '2026-09-15');
      expect(rev['origin'], 'onboarding');
      expect(rev['mode'], 'bank');
      expect(rev['reversesTxId'], original.id);
      expect(rev['amountPaise'], 1000000);
      expect(rev['note'], 'Entered twice');
      expect(rev['openingBalance'], false);
      expect(rev['recordedBy'], kOwnerUid);
      expect((await rawContract(db, id))['totalPaidPaise'], 1000000);

      // Nothing moved today: the cash on 15 Sep nets to ₹0.
      final after = await readSnapshot(db, id);
      expect(
        after.transactions.where((LedgerTransaction t) => t.paidOn == _today),
        isEmpty,
      );
    });

    test('a live payment on an onboarded loan still reverses today', () async {
      final id = await onboard(const <PastPaymentInput>[]);
      final pay = await payments.recordPayment(
        RecordPaymentCommand(
          cid: kCid,
          snapshot: await readSnapshot(db, id),
          amount: rs(5000),
          paidOn: d(2026, 11, 20),
          mode: PaymentMode.cash,
          actor: kActor,
        ),
      );
      await payments.reversePayment(
        ReversePaymentCommand(
          cid: kCid,
          snapshot: await readSnapshot(db, id),
          transactionId: pay.id,
          reason: 'Wrong loan',
          today: _today,
          actor: kActor,
        ),
      );
      final rev = (await reversals(id)).single;
      expect(rev['paidOn'], '2026-11-24');
      expect(rev['origin'], 'live');
    });
  });

  group('reverseOpeningBalance', () {
    ReverseOpeningCommand cmd(
      ContractSnapshot snap, {
      Role? role = Role.owner,
      String reason = 'Wrong opening total',
    }) => ReverseOpeningCommand(
      cid: kCid,
      snapshot: snap,
      reason: reason,
      actor: kActor,
      role: role,
    );

    test('reverses every opening row on its own date', () async {
      final id = await onboard(opening(75000));
      final snap = await readSnapshot(db, id);
      expect(unreversedOpeningBalance(snap), hasLength(8));

      final r = await payments.reverseOpeningBalance(cmd(snap));
      expect(r.balanceAfter, rs(100000));
      expect(r.closed, isFalse);

      final revs = await reversals(id);
      expect(revs, hasLength(8));
      final originals = <String, Map<String, dynamic>>{
        for (final m in await rawDocs(db, 'transactions', id))
          if (m['type'] == 'payment') m['id'] as String: m,
      };
      for (final rev in revs) {
        final o = originals[rev['reversesTxId']]!;
        expect(rev['paidOn'], o['paidOn']);
        expect(rev['amountPaise'], o['amountPaise']);
        expect(rev['mode'], 'cash');
        expect(rev['origin'], 'onboarding');
        expect(rev['note'], 'Wrong opening total');
        expect(rev['contractActive'], true);
        expect(rev['recordedByName'], 'Ravi');
      }
      expect(r.id, isIn(revs.map((m) => m['id'])));
      expect((await rawContract(db, id))['totalPaidPaise'], 0);

      // A second call has nothing left to reverse.
      await expectLater(
        payments.reverseOpeningBalance(cmd(await readSnapshot(db, id))),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('skips opening rows already reversed one by one', () async {
      final id = await onboard(opening(30000));
      var snap = await readSnapshot(db, id);
      final first = unreversedOpeningBalance(snap).first;
      await payments.reversePayment(
        ReversePaymentCommand(
          cid: kCid,
          snapshot: snap,
          transactionId: first.id,
          reason: 'x',
          today: _today,
          actor: kActor,
        ),
      );
      snap = await readSnapshot(db, id);
      expect(unreversedOpeningBalance(snap), hasLength(2));
      await payments.reverseOpeningBalance(cmd(snap));
      expect(await reversals(id), hasLength(3));
      expect((await rawContract(db, id))['totalPaidPaise'], 0);
    });

    test('itemised rows are not opening rows', () async {
      final id = await onboard(<PastPaymentInput>[
        PastPaymentInput(
          paidOn: d(2026, 9, 1),
          amount: rs(10000),
          mode: PaymentMode.upi,
        ),
      ]);
      await expectLater(
        payments.reverseOpeningBalance(cmd(await readSnapshot(db, id))),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure f) => f.message,
            'message',
            contains('no opening balance'),
          ),
        ),
      );
    });

    test('balanced across several batches', () async {
      payments = PaymentRepository(
        firestore: db,
        clock: clockAt(_today),
        batchLimit: 4, // 3 reversals + 1 contract increment per batch
      );
      final id = await onboard(opening(75000)); // 8 rows → 3 batches
      await payments.reverseOpeningBalance(cmd(await readSnapshot(db, id)));
      expect(await reversals(id), hasLength(8));
      expect((await rawContract(db, id))['totalPaidPaise'], 0);
    });

    test('reopens a loan closed by a later live payment', () async {
      final id = await onboard(opening(30000));
      await payments.recordPayment(
        RecordPaymentCommand(
          cid: kCid,
          snapshot: await readSnapshot(db, id),
          amount: rs(70000),
          paidOn: _today,
          mode: PaymentMode.cash,
          actor: kActor,
        ),
      );
      expect((await rawContract(db, id))['status'], 'closed');

      final r = await payments.reverseOpeningBalance(
        cmd(await readSnapshot(db, id)),
      );
      expect(r.balanceAfter, rs(30000));
      final c = await rawContract(db, id);
      expect(c['status'], 'active');
      expect(c['closedAt'], isNull);
      expect(c['totalPaidPaise'], 7000000);
      for (final col in <String>['installments', 'transactions']) {
        for (final m in await rawDocs(db, col, id)) {
          expect(m['contractActive'], true, reason: '$col ${m['id']}');
        }
      }
    });

    test('owner only, reason required', () async {
      final id = await onboard(opening(30000));
      final snap = await readSnapshot(db, id);
      for (final role in <Role?>[Role.collector, null]) {
        await expectLater(
          payments.reverseOpeningBalance(cmd(snap, role: role)),
          throwsA(isA<PermissionDeniedFailure>()),
        );
      }
      await expectLater(
        payments.reverseOpeningBalance(cmd(snap, reason: '  ')),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure f) => f.field,
            'field',
            reversalReasonField,
          ),
        ),
      );
      expect(await reversals(id), isEmpty);
      expect(
        (await rawContract(db, id))['totalPaidPaise'],
        Money.sum(opening(30000).map((PastPaymentInput p) => p.amount)).paise,
      );
    });
  });
}
