import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/time/ist_clock.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/borrowers/data/borrower_repository.dart';
import 'package:nordic_ledger/features/contracts/data/ledger_snapshot_repository.dart';

import 'borrower_test_support.dart';

final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  late FakeFirebaseFirestore db;
  late BorrowerRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = BorrowerRepository(
      firestore: db,
      clock: FixedClock.ist(2023, 11, 7, 10),
    );
  });

  Future<Map<String, dynamic>> raw(String id) async =>
      (await db.doc('companies/$kCid/borrowers/$id').get()).data()!;

  group('BorrowerRepository', () {
    test('create writes every field: uuid v4, nameLower, E.164', () async {
      final created = await repo.createBorrower(
        cid: kCid,
        name: '  Anita Sharma ',
        phone: '098450 12890',
        locality: ' Anna Nagar ',
        notes: '',
        createdBy: kOwnerUid,
      );
      expect(created.id, matches(_uuidV4));
      expect(created.outcome, WriteOutcome.synced);
      final m = await raw(created.id);
      expect(m['name'], 'Anita Sharma');
      expect(m['nameLower'], 'anita sharma');
      expect(m['phoneE164'], '+919845012890');
      expect(m['locality'], 'Anna Nagar');
      expect(m['notes'], isNull);
      expect(m['archived'], false);
      expect(m['createdBy'], kOwnerUid);
      expect(m['createdAt'], isA<Timestamp>());
      expect(m['updatedAt'], isA<Timestamp>());
      expect(m['schemaVersion'], 1);
      expect(m.containsKey('id'), isFalse);
      // The clock moment, stored as a UTC instant.
      expect(
        (m['createdAt'] as Timestamp).toDate().toUtc(),
        DateTime(2023, 11, 7, 10).toUtc(),
      );
    });

    test('create validates name and phone', () async {
      await expectLater(
        repo.createBorrower(
          cid: kCid,
          name: 'A',
          phone: '9845012890',
          createdBy: kOwnerUid,
        ),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        repo.createBorrower(
          cid: kCid,
          name: 'Anita',
          phone: '12345',
          createdBy: kOwnerUid,
        ),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        (await db.collection('companies/$kCid/borrowers').get()).docs,
        isEmpty,
      );
    });

    test('update changes editable fields only', () async {
      final id = (await repo.createBorrower(
        cid: kCid,
        name: 'Anita Sharma',
        phone: '9845012890',
        createdBy: kOwnerUid,
      )).id;
      final before = await raw(id);
      final outcome = await repo.updateBorrower(
        cid: kCid,
        id: id,
        name: 'Anita S. Rao',
        phone: '+91 99001 12233',
        locality: 'T. Nagar',
        notes: 'Prefers UPI',
      );
      expect(outcome, WriteOutcome.synced);
      final m = await raw(id);
      expect(m['name'], 'Anita S. Rao');
      expect(m['nameLower'], 'anita s. rao');
      expect(m['phoneE164'], '+919900112233');
      expect(m['locality'], 'T. Nagar');
      expect(m['notes'], 'Prefers UPI');
      expect(m['createdBy'], before['createdBy']);
      expect(m['createdAt'], before['createdAt']);
    });

    test(
      'archive hides the borrower from watchBorrowers, keeps the doc',
      () async {
        final a = (await repo.createBorrower(
          cid: kCid,
          name: 'Zoya Khan',
          phone: '9845012891',
          createdBy: kOwnerUid,
        )).id;
        final b = (await repo.createBorrower(
          cid: kCid,
          name: 'anil Das',
          phone: '9845012892',
          createdBy: kOwnerUid,
        )).id;
        final first = await repo.watchBorrowers(kCid).first;
        // Ordered by nameLower: "anil das" < "zoya khan".
        expect(first.map((Borrower x) => x.id), <String>[b, a]);

        await repo.archiveBorrower(kCid, a);
        final after = await repo.watchBorrowers(kCid).first;
        expect(after.map((Borrower x) => x.id), <String>[b]);
        expect((await raw(a))['archived'], true);
        expect((await repo.watchBorrower(kCid, a).first)?.archived, isTrue);
      },
    );

    test('watchBorrowers is scoped to the company', () async {
      await repo.createBorrower(
        cid: 'other',
        name: 'Elsewhere',
        phone: '9845012893',
        createdBy: kOwnerUid,
      );
      expect(await repo.watchBorrowers(kCid).first, isEmpty);
      expect(await repo.watchBorrower(kCid, 'missing').first, isNull);
    });

    test('a write with no server ack in time counts as queued', () async {
      const grace = Duration(milliseconds: 10);
      expect(
        await awaitServerAck(Completer<void>().future, grace, 't'),
        WriteOutcome.queued,
      );
      expect(
        await awaitServerAck(Future<void>.value(), grace, 't'),
        WriteOutcome.synced,
      );
      await expectLater(
        awaitServerAck(
          Future<void>.error(
            FirebaseException(plugin: 'firestore', code: 'permission-denied'),
          ),
          grace,
          't',
        ),
        throwsA(isA<PermissionDeniedFailure>()),
      );
    });
  });

  group('LedgerSnapshotRepository', () {
    late LedgerSnapshotRepository ledger;

    setUp(() async {
      ledger = LedgerSnapshotRepository(firestore: db);
      await listFixture().writeTo(db);
    });

    test(
      'live listeners return only active contracts and their docs',
      () async {
        final contracts = await ledger.watchActiveContracts(kCid).first;
        expect(contracts.map((Contract c) => c.id).toSet(), <String>{
          'c1',
          'c2',
          'c4',
          'c5',
        });
        final inst = await ledger.watchActiveInstallments(kCid).first;
        expect(inst.every((Installment i) => i.contractId != 'c3'), isTrue);
        final txs = await ledger.watchActiveTransactions(kCid).first;
        expect(
          txs.every((LedgerTransaction t) => t.contractId != 'c3'),
          isTrue,
        );
        expect(txs.length, 5);
      },
    );

    test(
      'borrower history: closed / rolled-over contracts and their txs',
      () async {
        final hist = await ledger
            .watchBorrowerHistoryContracts(kCid, 'b1')
            .first;
        expect(hist.map((Contract c) => c.id), <String>['c3']);
        final htx = await ledger
            .watchBorrowerHistoryTransactions(kCid, 'b1')
            .first;
        expect(htx.map((LedgerTransaction t) => t.id), <String>['t-c3-p1']);
        expect(
          await ledger.watchBorrowerHistoryContracts(kCid, 'b2').first,
          isEmpty,
        );
      },
    );

    test('per-contract streams (any status)', () async {
      expect((await ledger.watchContract(kCid, 'c3').first)?.loanNo, 2);
      expect(await ledger.watchContract(kCid, 'nope').first, isNull);
      expect(
        (await ledger.watchContractInstallments(kCid, 'c3').first).length,
        3,
      );
      expect(
        (await ledger.watchContractTransactions(kCid, 'c2').first).length,
        3,
      );
    });
  });
}
