import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/core/firebase/firestore_paths.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import '../../helpers/model_fixtures.dart';

Map<String, dynamic> _throughJson(Map<String, dynamic> json, String id) =>
    <String, dynamic>{
      ...(jsonDecode(jsonEncode(json)) as Map<String, dynamic>),
      'id': id,
    };

Map<String, dynamic> _without(Map<String, dynamic> json, List<String> keys) =>
    Map<String, dynamic>.of(json)
      ..removeWhere((String k, _) => keys.contains(k));

void main() {
  final onboarded = Fixtures.contract.copyWith(
    origin: ContractOrigin.onboarded,
    onboardedOn: const CivilDate(2026, 11, 24),
    previousRef: 'Book 3 / 117',
  );
  final onboardingTx = Fixtures.transaction.copyWith(
    type: TxType.payment,
    mode: PaymentMode.cash,
    origin: TxOrigin.onboarding,
    openingBalance: true,
  );

  group('Contract origin fields', () {
    test('serialise as lowercase strings and round-trip', () {
      final json = onboarded.toJson();
      expect(json['origin'], 'onboarded');
      expect(json['onboardedOn'], '2026-11-24');
      expect(json['previousRef'], 'Book 3 / 117');
      expect(Contract.fromJson(_throughJson(json, onboarded.id)), onboarded);
      expect(onboarded.isOnboarded, isTrue);
    });

    test('a standard contract writes origin standard, null extras', () {
      final json = Fixtures.contract.toJson();
      expect(json['origin'], 'standard');
      expect(json['onboardedOn'], isNull);
      expect(json['previousRef'], isNull);
      expect(Fixtures.contract.isOnboarded, isFalse);
    });

    test('an old doc without the fields reads as standard', () {
      final json = _without(Fixtures.contract.toJson(), <String>[
        'origin',
        'onboardedOn',
        'previousRef',
      ]);
      final read = Contract.fromJson(_throughJson(json, 'con-1'));
      expect(read.origin, ContractOrigin.standard);
      expect(read.onboardedOn, isNull);
      expect(read.previousRef, isNull);
      expect(read, Fixtures.contract);
    });

    test('an unknown origin value reads as standard', () {
      final json = <String, dynamic>{
        ...Fixtures.contract.toJson(),
        'origin': 'imported',
      };
      expect(
        Contract.fromJson(_throughJson(json, 'con-1')).origin,
        ContractOrigin.standard,
      );
    });
  });

  group('LedgerTransaction origin fields', () {
    test('serialise and round-trip', () {
      final json = onboardingTx.toJson();
      expect(json['origin'], 'onboarding');
      expect(json['openingBalance'], true);
      final read = LedgerTransaction.fromJson(
        _throughJson(json, onboardingTx.id),
      );
      expect(read, onboardingTx);
      expect(read.isOnboarding, isTrue);
    });

    test('a live tx writes origin live, openingBalance false', () {
      final json = Fixtures.transaction.toJson();
      expect(json['origin'], 'live');
      expect(json['openingBalance'], false);
      expect(Fixtures.transaction.isOnboarding, isFalse);
    });

    test('an old doc without the fields reads as live / false', () {
      final json = _without(Fixtures.transaction.toJson(), <String>[
        'origin',
        'openingBalance',
      ]);
      final read = LedgerTransaction.fromJson(_throughJson(json, 'tx-1'));
      expect(read.origin, TxOrigin.live);
      expect(read.openingBalance, isFalse);
      expect(read, Fixtures.transaction);
    });

    test('an unknown origin value reads as live', () {
      final json = <String, dynamic>{
        ...Fixtures.transaction.toJson(),
        'origin': 'import',
      };
      expect(
        LedgerTransaction.fromJson(_throughJson(json, 'tx-1')).origin,
        TxOrigin.live,
      );
    });
  });

  group('Firestore converter round trip', () {
    late FakeFirebaseFirestore db;
    late TypedRefs refs;

    setUp(() {
      db = FakeFirebaseFirestore();
      refs = TypedRefs(db);
    });

    test('onboarded contract and onboarding tx', () async {
      await refs.contract('cmp-1', onboarded.id).set(onboarded);
      expect(
        (await refs.contract('cmp-1', onboarded.id).get()).data(),
        onboarded,
      );

      await refs.transaction('cmp-1', onboardingTx.id).set(onboardingTx);
      final read = (await refs.transaction('cmp-1', onboardingTx.id).get())
          .data()!;
      expect(read, onboardingTx.copyWith(recordedAt: read.recordedAt));
      final raw =
          (await db
                  .doc(FirestorePaths.transaction('cmp-1', onboardingTx.id))
                  .get())
              .data()!;
      expect(raw['origin'], 'onboarding');
      expect(raw['openingBalance'], true);
    });

    test('old docs without the fields read with defaults', () async {
      final contractBody =
          ModelCodecs.contract.toFirestore(Fixtures.contract, null)
            ..removeWhere(
              (String k, _) =>
                  <String>['origin', 'onboardedOn', 'previousRef'].contains(k),
            );
      await db.doc(FirestorePaths.contract('cmp-1', 'con-1')).set(contractBody);
      final c = (await refs.contract('cmp-1', 'con-1').get()).data()!;
      expect(c.origin, ContractOrigin.standard);
      expect(c, Fixtures.contract);

      final txBody =
          ModelCodecs.transaction.toFirestore(Fixtures.transaction, null)
            ..removeWhere(
              (String k, _) => <String>['origin', 'openingBalance'].contains(k),
            );
      await db.doc(FirestorePaths.transaction('cmp-1', 'tx-1')).set(txBody);
      final t = (await refs.transaction('cmp-1', 'tx-1').get()).data()!;
      expect(t.origin, TxOrigin.live);
      expect(t.openingBalance, isFalse);
    });
  });
}
