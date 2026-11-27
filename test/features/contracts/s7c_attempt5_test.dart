import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/contracts/data/contract_repository.dart';
import 'package:nordic_ledger/features/payments/data/payment_repository.dart';

import '../payments/payment_test_support.dart';

/// Sprint 7c attempt 5: the Module Lead's attempt-4 findings.
/// - F1: Cancel racing a running resumer (re-check before every batch;
///   queue cancelled first and acked; targets from a server read).
/// - F2: finishing a cancel that left onboarding payments unreversed.
/// - F5: debounced resume triggers; one immediate retry after a denial.
final CivilDate _today = d(2026, 11, 24);

/// A fake whose batches can run a hook after a given commit, or fail.
final class _HookDb extends FakeFirebaseFirestore {
  int made = 0;

  /// Called after batch number [afterBatch] (1-based) has committed.
  int? afterBatch;
  Future<void> Function()? hook;

  /// Batch numbers whose commit is denied (nothing applied).
  final Set<int> denied = <int>{};

  /// When true, updates of an onboarding queue doc never get an ack.
  bool queueOffline = false;

  @override
  WriteBatch batch() {
    final n = ++made;
    if (denied.contains(n)) return _DeniedBatch();
    final inner = super.batch();
    if (afterBatch != n || hook == null) return inner;
    return _HookBatch(inner, hook!);
  }

  @override
  DocumentReference<Map<String, dynamic>> doc(String path) {
    final ref = super.doc(path);
    if (queueOffline && path.contains('/onboardingQueues/')) {
      return _StuckDoc(ref);
    }
    return ref;
  }
}

final class _HookBatch implements WriteBatch {
  _HookBatch(this._inner, this._hook);

  final WriteBatch _inner;
  final Future<void> Function() _hook;

  @override
  Future<void> commit() async {
    await _inner.commit();
    await _hook();
  }

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) =>
      _inner.set(document, data, options);

  @override
  void update<T>(DocumentReference<T> document, T data) =>
      _inner.update(document, data);

  @override
  void delete(DocumentReference document) => _inner.delete(document);
}

final class _DeniedBatch implements WriteBatch {
  @override
  Future<void> commit() => Future<void>.error(
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ignore: subtype_of_sealed_class
/// A queue doc whose update stays pending forever (offline). Test-only
/// stand-in, like fake_cloud_firestore's own references.
final class _StuckDoc implements DocumentReference<Map<String, dynamic>> {
  _StuckDoc(this._inner);

  final DocumentReference<Map<String, dynamic>> _inner;

  @override
  Future<void> update(Map<Object, Object?> data) => Completer<void>().future;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      _inner.get(options);

  @override
  String get path => _inner.path;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _HookDb db;
  late ContractRepository contracts;
  late PaymentRepository payments;

  setUp(() async {
    db = _HookDb();
    contracts = ContractRepository(firestore: db, clock: clockAt(_today));
    payments = PaymentRepository(
      firestore: db,
      clock: clockAt(_today),
      commitGrace: const Duration(milliseconds: 200),
    );
    await seedCompany(db);
  });

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

  ResumeOnboardingCommand resumeCmd(String id) => ResumeOnboardingCommand(
    cid: kCid,
    contractId: id,
    actor: kActor,
    role: Role.owner,
  );

  CancelOnboardedCommand cancelCmd(
    ContractSnapshot s, {
    bool queuePending = false,
  }) => CancelOnboardedCommand(
    cid: kCid,
    snapshot: s,
    reason: 'Onboarded by mistake',
    actor: kActor,
    role: Role.owner,
    queuePending: queuePending,
  );

  Future<List<Map<String, dynamic>>> byType(String id, String type) async =>
      <Map<String, dynamic>>[
        for (final m in await rawDocs(db, 'transactions', id))
          if (m['type'] == type) m,
      ];

  Future<String?> queueStatus(String id) async =>
      (await db.doc('companies/$kCid/onboardingQueues/$id').get())
              .data()?['status']
          as String?;

  group('F1 race: Cancel lands between resumer batches', () {
    test('the resumer stops at its next re-check; Cancel reverses what '
        'landed', () async {
      final r = await contracts.onboardContract(daily(328)); // batch #1
      final atBatch1 = await readSnapshot(db, r.id);
      // Cancel lands right after the resumer's first batch (#2).
      db
        ..afterBatch = 2
        ..hook = () async {
          await db.doc('companies/$kCid/onboardingQueues/${r.id}').update(
            <String, Object?>{'status': 'cancelled'},
          );
          await db.doc('companies/$kCid/contracts/${r.id}').update(
            <String, Object?>{'status': 'cancelled'},
          );
        };
      expect(
        await contracts.resumeOnboarding(resumeCmd(r.id)),
        ResumeOutcome.stopped,
      );
      // Only batch 1 (100) + one resumed batch (100) landed, balanced.
      final pays = await byType(r.id, 'payment');
      expect(pays, hasLength(200));
      expect((await rawContract(db, r.id))['totalPaidPaise'], 200 * 1000);
      db.hook = null;

      // The contract is cancelled with 200 unreversed payments: Finish
      // cancelling reverses them all (server read, not the stale cache).
      final stale = ContractSnapshot(
        contract: atBatch1.contract.copyWith(status: ContractStatus.cancelled),
        installments: atBatch1.installments,
        transactions: atBatch1.transactions,
      );
      expect(isCancelUnfinished(stale), isTrue);
      await payments.cancelOnboardedLoan(cancelCmd(stale));
      expect(await byType(r.id, 'reversal'), hasLength(200));
      expect((await rawContract(db, r.id))['totalPaidPaise'], 0);
    });

    test('Cancel with a pending queue cancels the queue first; the resumer '
        'then finds nothing to do', () async {
      final r = await contracts.onboardContract(daily(328));
      await payments.cancelOnboardedLoan(
        cancelCmd(await readSnapshot(db, r.id), queuePending: true),
      );
      expect(await queueStatus(r.id), 'cancelled');
      expect(
        await contracts.resumeOnboarding(resumeCmd(r.id)),
        ResumeOutcome.nothingQueued,
      );
      expect(await byType(r.id, 'payment'), hasLength(100));
      expect(await byType(r.id, 'reversal'), hasLength(100));
      final c = await rawContract(db, r.id);
      expect(c['status'], 'cancelled');
      expect(c['totalPaidPaise'], 0);
    });

    test('offline: a cancel of a still-syncing loan is refused and writes '
        'nothing else', () async {
      final r = await contracts.onboardContract(daily(328));
      final s = await readSnapshot(db, r.id);
      db.queueOffline = true;
      await expectLater(
        payments.cancelOnboardedLoan(cancelCmd(s, queuePending: true)),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure f) => f.message,
            'message',
            'Connect to the internet to cancel a loan that is still syncing.',
          ),
        ),
      );
      expect(await byType(r.id, 'reversal'), isEmpty);
      expect((await rawContract(db, r.id))['status'], 'active');
    });

    test('targets come from the server: payments a resumer landed after the '
        'cached snapshot are reversed too', () async {
      final r = await contracts.onboardContract(daily(328));
      final stale = await readSnapshot(db, r.id); // 100 payments
      expect(
        await contracts.resumeOnboarding(resumeCmd(r.id)),
        ResumeOutcome.complete,
      );
      await payments.cancelOnboardedLoan(cancelCmd(stale));
      expect(await byType(r.id, 'reversal'), hasLength(328));
      expect((await rawContract(db, r.id))['totalPaidPaise'], 0);
    });
  });

  group('F2: finish an unfinished cancel', () {
    test('a fully netted cancelled loan cannot be cancelled again', () async {
      final r = await contracts.onboardContract(daily(50));
      await payments.cancelOnboardedLoan(
        cancelCmd(await readSnapshot(db, r.id)),
      );
      final s = await readSnapshot(db, r.id);
      expect(isCancelUnfinished(s), isFalse);
      expect(cancelOnboardedBlocker(s), 'This loan is already cancelled.');
    });

    test('reversals only: status and closedAt untouched; flips the late '
        'payment inactive', () async {
      final r = await contracts.onboardContract(daily(50));
      await payments.cancelOnboardedLoan(
        cancelCmd(await readSnapshot(db, r.id)),
      );
      final closedAt = (await rawContract(db, r.id))['closedAt'];
      // A racing resumer from another phone landed one more payment (and
      // its increment) before the rules deny it.
      final c = (await TypedRefs(db).contract(kCid, r.id).get()).data()!;
      await TypedRefs(db)
          .transaction(kCid, 'late-1')
          .set(
            onboardingPaymentTx(
              id: 'late-1',
              c: c,
              paidOn: _today.addDays(-300),
              amount: rs(10),
              mode: PaymentMode.cash,
              actor: kActor,
              now: DateTime.utc(2026, 11, 24),
            ),
          );
      await db.doc('companies/$kCid/contracts/${r.id}').update(
        <String, Object?>{'totalPaidPaise': FieldValue.increment(1000)},
      );
      final s = await readSnapshot(db, r.id);
      expect(isCancelUnfinished(s), isTrue);
      expect(cancelOnboardedBlocker(s), isNull);
      await payments.cancelOnboardedLoan(cancelCmd(s));
      final after = await rawContract(db, r.id);
      expect(after['status'], 'cancelled');
      expect(after['closedAt'], closedAt);
      expect(after['totalPaidPaise'], 0);
      final late = (await rawDocs(
        db,
        'transactions',
        r.id,
      )).singleWhere((Map<String, dynamic> m) => m['id'] == 'late-1');
      expect(late['contractActive'], false);
      expect(isCancelUnfinished(await readSnapshot(db, r.id)), isFalse);
    });
  });

  group('F5: resume triggers and one retry', () {
    PendingQueues q(Set<String> ids, {bool pending = false}) =>
        PendingQueues(ids, hasPendingWrites: pending);

    test('fires on the first emission, an id-set change, or pending writes '
        'reaching the server; not on other metadata flips', () {
      expect(resumeTriggerChanged(null, q(<String>{})), isTrue);
      expect(resumeTriggerChanged(q(<String>{'a'}), q(<String>{'a'})), isFalse);
      expect(
        resumeTriggerChanged(
          q(<String>{'a'}, pending: false),
          q(<String>{'a'}, pending: true),
        ),
        isFalse,
      );
      expect(
        resumeTriggerChanged(
          q(<String>{'a'}, pending: true),
          q(<String>{'a'}, pending: false),
        ),
        isTrue,
      );
      expect(
        resumeTriggerChanged(q(<String>{'a'}), q(<String>{'a', 'b'})),
        isTrue,
      );
      expect(resumeTriggerChanged(q(<String>{'a'}), q(<String>{'b'})), isTrue);
      expect(
        resumeTriggerChanged(q(<String>{'a', 'b'}), q(<String>{'a'})),
        isTrue,
      );
    });

    test('resumeTriggers drops repeated emissions', () async {
      final out = await resumeTriggers(
        Stream<PendingQueues>.fromIterable(<PendingQueues>[
          q(<String>{'a'}, pending: true),
          q(<String>{'a'}, pending: true),
          q(<String>{'a'}),
          q(<String>{'a'}),
          q(<String>{}),
        ]),
      ).toList();
      expect(out, <List<String>>[
        <String>['a'],
        <String>['a'],
        <String>[],
      ]);
    });

    test('a denied batch is retried once at once and then completes', () async {
      final r = await contracts.onboardContract(daily(328)); // batch #1
      db.denied.add(2); // the first resumed batch is denied once
      expect(
        await contracts.resumeOnboarding(resumeCmd(r.id)),
        ResumeOutcome.complete,
      );
      expect(await byType(r.id, 'payment'), hasLength(328));
      expect((await rawContract(db, r.id))['totalPaidPaise'], 328 * 1000);
    });

    test('a second denial gives up (bounded) until the next trigger', () async {
      final r = await contracts.onboardContract(daily(328)); // batch #1
      db.denied.addAll(<int>{2, 3});
      expect(
        await contracts.resumeOnboarding(resumeCmd(r.id)),
        ResumeOutcome.denied,
      );
      expect(db.made, 3);
      expect(await byType(r.id, 'payment'), hasLength(100));
      expect(await queueStatus(r.id), 'pending');
      // The next trigger succeeds.
      expect(
        await contracts.resumeOnboarding(resumeCmd(r.id)),
        ResumeOutcome.complete,
      );
      expect(await byType(r.id, 'payment'), hasLength(328));
    });
  });
}
