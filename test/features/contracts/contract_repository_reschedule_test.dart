import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/contracts/data/contract_repository.dart';

import 'contract_test_support.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ContractRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = ContractRepository(firestore: db, clock: clockAt(d(2023, 10, 24)));
    await seedCompany(db);
  });

  Future<List<Map<String, dynamic>>> all(
    String col,
  ) async => <Map<String, dynamic>>[
    for (final d in (await db.collection('companies/$kCid/$col').get()).docs)
      d.data(),
  ];

  group('reschedule', () {
    late Installment src;

    setUp(() async {
      await stitchSeed().writeTo(db);
      src = (await TypedRefs(db).installment(kCid, 'c1-i5').get()).data()!;
    });

    RescheduleCommand rc(Money amount, CivilDate on) => RescheduleCommand(
      cid: kCid,
      source: src,
      amount: amount,
      newDueDate: on,
      remaining: rs(10000),
      maxSeq: 10,
      today: kStitchToday,
      actor: kActor,
      note: 'Harvest delayed',
    );

    test('one batch: source increment, new row, 0-amount audit tx', () async {
      final r = await repo.reschedule(rc(rs(10000), d(2023, 12, 8)));
      final s = (await db.doc('companies/$kCid/installments/c1-i5').get())
          .data()!;
      expect(s['rescheduledOutPaise'], 1000000);
      expect(s['rescheduledToIds'], <String>[r.id]);
      expect(s['amountDuePaise'], 1000000); // immutable

      final n = (await db.doc('companies/$kCid/installments/${r.id}').get())
          .data()!;
      expect(n['kind'], 'rescheduled');
      expect(n['rescheduledFromId'], 'c1-i5');
      expect(n['dueDate'], '2023-12-08');
      expect(n['amountDuePaise'], 1000000);
      expect(n['seq'], 11);
      expect(n['rescheduledOutPaise'], 0);
      expect(n['contractActive'], true);
      expect(n['contractId'], 'c1');
      expect(n['loanNo'], 4);

      final txs = (await all(
        'transactions',
      )).where((m) => m['type'] == 'reschedule').toList();
      expect(txs, hasLength(1));
      final t = txs.single;
      expect(t['amountPaise'], 0);
      expect(t['paidOn'], '2023-12-03');
      expect(t['note'], 'Harvest delayed');
      expect(t['recordedBy'], kOwnerUid);
      expect(t['recordedAt'], isA<Timestamp>());
      expect(t['rescheduleInfo'], <String, dynamic>{
        'fromInstallmentId': 'c1-i5',
        'toInstallmentId': r.id,
        'amountPaise': 1000000,
        'newDueDate': '2023-12-08',
      });
    });

    test('validates 0 < amount ≤ remaining and date ≥ today', () async {
      for (final bad in <RescheduleCommand>[
        rc(Money.zero, d(2023, 12, 8)),
        rc(rs(10001), d(2023, 12, 8)),
        rc(rs(5000), d(2023, 12, 2)),
      ]) {
        await expectLater(
          repo.reschedule(bad),
          throwsA(isA<ValidationFailure>()),
        );
      }
      final s = (await db.doc('companies/$kCid/installments/c1-i5').get())
          .data()!;
      expect(s['rescheduledOutPaise'], 0);
    });
  });
}
