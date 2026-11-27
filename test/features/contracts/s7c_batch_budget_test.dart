import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/firebase/balanced_chunks.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/contracts/data/contract_repository.dart';
import 'package:nordic_ledger/features/payments/data/payment_repository.dart';
import 'package:uuid/uuid.dart';

import '../payments/payment_test_support.dart';

/// Sprint 7c attempt 3: the production per-batch rule budget. On the live
/// project a batch with 113 onboarding payments was accepted and one with
/// 215 was rejected (PERMISSION_DENIED), so no balanced batch may carry
/// more than [maxLedgerItemsPerBatch] (100) money items. Installments
/// still fill batch 1 up to the 450-op limit.

/// Records every committed batch's writes (path + data) on top of a fake.
final class _RecordingDb extends FakeFirebaseFirestore {
  final List<List<(String, Map<String, Object?>)>> batches =
      <List<(String, Map<String, Object?>)>>[];

  @override
  WriteBatch batch() {
    final log = <(String, Map<String, Object?>)>[];
    batches.add(log);
    return _RecordingBatch(super.batch(), log);
  }
}

final class _RecordingBatch implements WriteBatch {
  _RecordingBatch(this._inner, this._log);

  final WriteBatch _inner;
  final List<(String, Map<String, Object?>)> _log;

  Map<String, Object?> _data<T>(DocumentReference<T> ref, T data) {
    if (data is Map<String, Object?>) return data;
    final r = ref as DocumentReference<Object?>;
    return <String, Object?>{'_typed': r.path};
  }

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    _log.add((document.path, _data(document, data)));
    _inner.set(document, data, options);
  }

  @override
  void update<T>(DocumentReference<T> document, T data) {
    _log.add((document.path, <String, Object?>{'_update': true}));
    _inner.update(document, data);
  }

  @override
  void delete(DocumentReference document) => _inner.delete(document);

  @override
  Future<void> commit() => _inner.commit();
}

final CivilDate _today = d(2026, 11, 24);

/// Money items of a batch: transaction docs that are payments or
/// reversals (the disbursement is a fixed op).
int _moneyItems(
  List<(String, Map<String, Object?>)> batch,
  Set<String> moneyIds,
) => batch
    .where(((String, Map<String, Object?>) w) => moneyIds.contains(w.$1))
    .length;

void main() {
  /// Daily ₹1,00,000 at ₹300 (334 rows) like the smoke test, disbursed
  /// 400 days ago, with [n] itemised payments of ₹10.
  OnboardContractCommand daily(int n) {
    final first = _today.addDays(-399);
    return OnboardContractCommand(
      cid: kCid,
      borrower: anita(),
      sanctioned: rs(100000),
      upfrontMode: UpfrontMode.flat,
      upfrontInput: 0,
      installmentAmount: rs(300),
      frequency: Frequency.daily,
      firstDueDate: first,
      disbursedOn: _today.addDays(-400),
      cachedNextLoanNo: 3,
      actor: kActor,
      role: Role.owner,
      today: _today,
      pastPayments: <PastPaymentInput>[
        for (var i = 0; i < n; i++)
          PastPaymentInput(
            paidOn: first.addDays(i % 330),
            amount: rs(10),
            mode: PaymentMode.cash,
          ),
      ],
    );
  }

  for (final n in <int>[328, 1100]) {
    test('$n onboarding payments: no batch carries more than 100', () async {
      final db = _RecordingDb();
      await seedCompany(db);
      db.batches.clear();
      final repo = ContractRepository(firestore: db, clock: clockAt(_today));
      final r = await repo.onboardContract(daily(n));
      // Attempt 4: only batch 1 is sent; the resumer writes the rest.
      expect(db.batches, hasLength(1));
      await repo.resumeOnboarding(
        ResumeOnboardingCommand(
          cid: kCid,
          contractId: r.id,
          actor: kActor,
          role: Role.owner,
        ),
      );
      final snap = await readSnapshot(db, r.id);
      final moneyIds = <String>{
        for (final t in snap.transactions)
          if (t.type == TxType.payment) 'companies/$kCid/transactions/${t.id}',
      };
      expect(moneyIds, hasLength(n));
      final perBatch = <int>[
        for (final b in db.batches) _moneyItems(b, moneyIds),
      ];
      expect(perBatch.every((int k) => k <= maxLedgerItemsPerBatch), isTrue);
      expect(perBatch.reduce((int a, int b) => a + b), n);
      // Batch 1 still holds the whole schedule (cheap rules) next to the
      // contract.
      final installmentsInFirst = db.batches.first
          .where(
            ((String, Map<String, Object?>) w) =>
                w.$1.contains('/installments/'),
          )
          .length;
      expect(installmentsInFirst, snap.installments.length);
      expect(snap.contract.totalPaid, rs(10) * n);
      // M2 is unaffected by the smaller batches.
      final sync = OnboardingSync.of(snap)!;
      expect(sync.expected, n);
      expect(sync.synced, n);
      expect(sync.isIncomplete, isFalse);
    });
  }

  test('328 payments with a 334-row schedule: the smoke-test layout', () {
    final cmd = daily(328);
    final plan = planOnboarding(
      terms: cmd,
      pastPayments: cmd.pastPayments,
      today: _today,
      contractId: 'x',
      borrowerId: 'b1',
      borrowerName: 'Anita Sharma',
      borrowerPhoneE164: '+919845012890',
      now: DateTime.utc(2026, 11, 24),
      uuid: const Uuid(),
    );
    expect(plan.installments, hasLength(334));
    final chunks = plan.layout();
    // Batch 1: contract, disbursement, nextLoanNo, the queue doc, 334
    // installments and 100 payments;
    // then 100 + 100 + 28 instead of the rejected 215.
    expect(chunks.chunkSizes, <int>[100, 100, 100, 28]);
    expect(chunks.opsPerBatch, <int>[438, 101, 101, 29]);
  });

  test('reverse opening balance with more than 100 rows: ≤ 100 reversals '
      'per batch, every batch balanced', () async {
    final db = _RecordingDb();
    await seedCompany(db);
    final contracts = ContractRepository(firestore: db, clock: clockAt(_today));
    final cmd = daily(0);
    final schedule = generateSchedule(
      sanctioned: cmd.sanctioned,
      installmentAmount: cmd.installmentAmount,
      frequency: Frequency.daily,
      firstDueDate: cmd.firstDueDate,
    );
    final spread = spreadOpeningTotal(
      schedule: schedule,
      total: rs(75000), // 250 rows of ₹300
      mode: PaymentMode.cash,
      disbursedOn: cmd.disbursedOn,
      today: _today,
    );
    expect(spread, hasLength(250));
    final r = await contracts.onboardContract(
      OnboardContractCommand(
        cid: cmd.cid,
        borrower: cmd.borrower,
        sanctioned: cmd.sanctioned,
        upfrontMode: cmd.upfrontMode,
        upfrontInput: cmd.upfrontInput,
        installmentAmount: cmd.installmentAmount,
        frequency: cmd.frequency,
        firstDueDate: cmd.firstDueDate,
        disbursedOn: cmd.disbursedOn,
        cachedNextLoanNo: 3,
        actor: kActor,
        role: Role.owner,
        today: _today,
        pastPayments: spread,
      ),
    );
    await contracts.resumeOnboarding(
      ResumeOnboardingCommand(
        cid: kCid,
        contractId: r.id,
        actor: kActor,
        role: Role.owner,
      ),
    );
    db.batches.clear();
    final payments = PaymentRepository(firestore: db, clock: clockAt(_today));
    await payments.reverseOpeningBalance(
      ReverseOpeningCommand(
        cid: kCid,
        snapshot: await readSnapshot(db, r.id),
        reason: 'Wrong opening total',
        actor: kActor,
        role: Role.owner,
      ),
    );
    final after = await readSnapshot(db, r.id);
    final reversalIds = <String>{
      for (final t in after.transactions)
        if (t.type == TxType.reversal) 'companies/$kCid/transactions/${t.id}',
    };
    expect(reversalIds, hasLength(250));
    final perBatch = <int>[
      for (final b in db.batches) _moneyItems(b, reversalIds),
    ];
    expect(perBatch, <int>[100, 100, 50]);
    expect(after.contract.totalPaid, rs(0));
  });
}
