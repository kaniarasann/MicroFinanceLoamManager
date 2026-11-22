import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/models/models.dart';

import '../../helpers/model_fixtures.dart';

/// Serialises through a real JSON string (proves the map is plain JSON),
/// then re-injects the doc id the way the data layer does.
Map<String, dynamic> _throughJson(Map<String, dynamic> json, String id) =>
    <String, dynamic>{
      ...(jsonDecode(jsonEncode(json)) as Map<String, dynamic>),
      'id': id,
    };

Map<String, dynamic> _without(Map<String, dynamic> json, List<String> keys) =>
    Map<String, dynamic>.of(json)
      ..removeWhere((String k, _) => keys.contains(k));

void main() {
  group('JSON round trip', () {
    test('AppUser', () {
      final v = Fixtures.appUser;
      expect(AppUser.fromJson(_throughJson(v.toJson(), v.id)), v);
    });
    test('Membership', () {
      final v = Fixtures.membership;
      expect(Membership.fromJson(_throughJson(v.toJson(), v.id)), v);
    });
    test('UserSettings (with NotificationPrefs)', () {
      final v = Fixtures.userSettings;
      expect(UserSettings.fromJson(_throughJson(v.toJson(), v.id)), v);
    });
    test('Company', () {
      final v = Fixtures.company;
      expect(Company.fromJson(_throughJson(v.toJson(), v.id)), v);
    });
    test('Member', () {
      final v = Fixtures.member;
      expect(Member.fromJson(_throughJson(v.toJson(), v.id)), v);
    });
    test('Invite', () {
      final v = Fixtures.invite;
      expect(Invite.fromJson(_throughJson(v.toJson(), v.id)), v);
    });
    test('Borrower', () {
      final v = Fixtures.borrower;
      expect(Borrower.fromJson(_throughJson(v.toJson(), v.id)), v);
    });
    test('Contract', () {
      final v = Fixtures.contract;
      expect(Contract.fromJson(_throughJson(v.toJson(), v.id)), v);
    });
    test('Installment', () {
      final v = Fixtures.installment;
      expect(Installment.fromJson(_throughJson(v.toJson(), v.id)), v);
    });
    test('LedgerTransaction', () {
      final v = Fixtures.transaction;
      expect(LedgerTransaction.fromJson(_throughJson(v.toJson(), v.id)), v);
    });
  });

  group('document body shape', () {
    test('id is never serialised; schemaVersion is 1', () {
      final bodies = <Map<String, dynamic>>[
        Fixtures.appUser.toJson(),
        Fixtures.membership.toJson(),
        Fixtures.userSettings.toJson(),
        Fixtures.company.toJson(),
        Fixtures.member.toJson(),
        Fixtures.invite.toJson(),
        Fixtures.borrower.toJson(),
        Fixtures.contract.toJson(),
        Fixtures.installment.toJson(),
        Fixtures.transaction.toJson(),
      ];
      for (final body in bodies) {
        expect(body.containsKey('id'), isFalse);
        expect(body['schemaVersion'], 1);
      }
    });

    test('Contract money is int paise and dates are yyyy-MM-dd', () {
      final json = Fixtures.contract.toJson();
      expect(json['sanctionedPaise'], 10000000); // Rs 1,00,000
      expect(json['upfrontPaise'], 700000);
      expect(json['netDisbursedPaise'], 9300000);
      expect(json['installmentPaise'], 1000000);
      expect(json['totalPaidPaise'], 3000000);
      expect(json['rolloverSettledPaise'], 2500050);
      expect(json['upfrontInput'], 700);
      expect(json['firstDueDate'], '2026-11-24');
      expect(json['disbursedOn'], '2026-11-17');
      expect(json['lastPaymentOn'], '2026-12-08');
      expect(json['status'], 'rolledOver');
      expect(json['upfrontMode'], 'percent');
      expect(json['frequency'], 'weekly');
      expect(json['createdAt'], '2026-11-20T04:30:15.123Z');
      expect(json.containsKey('sanctioned'), isFalse);
    });

    test('Installment and LedgerTransaction keys', () {
      final ins = Fixtures.installment.toJson();
      expect(ins['amountDuePaise'], 500000);
      expect(ins['rescheduledOutPaise'], 100000);
      expect(ins['dueDate'], '2027-02-02');
      expect(ins['kind'], 'rescheduled');

      final tx = Fixtures.transaction.toJson();
      expect(tx['amountPaise'], 2500050);
      expect(tx['paidOn'], '2026-12-08');
      expect(tx['type'], 'rolloverSettlement');
      expect(tx['mode'], 'upi');
    });

    test('UserSettings.notifications serialises as a nested map', () {
      final json = Fixtures.userSettings.toJson();
      expect(json['notifications'], <String, dynamic>{
        'digestEnabled': true,
        'digestTime': '07:30',
        'perInstallmentEnabled': true,
        'overdueNudgeEnabled': true,
      });
    });

    test('Money and CivilDate are exposed as value types', () {
      final c = Fixtures.contract;
      expect(c.sanctioned, isA<Money>());
      expect(c.sanctioned, Fixtures.oneLakh);
      expect(c.firstDueDate, isA<CivilDate>());
      expect(c.firstDueDate, const CivilDate(2026, 11, 24));
    });
  });

  group('enum wire values', () {
    test('match Section 2 exactly', () {
      expect(Role.values.map((Role e) => e.name), <String>[
        'owner',
        'collector',
      ]);
      expect(Frequency.values.map((Frequency e) => e.name), <String>[
        'daily',
        'weekly',
        'monthly',
      ]);
      expect(UpfrontMode.values.map((UpfrontMode e) => e.name), <String>[
        'flat',
        'percent',
      ]);
      expect(ContractStatus.values.map((ContractStatus e) => e.name), <String>[
        'active',
        'closed',
        'rolledOver',
        'cancelled',
      ]);
      expect(
        InstallmentKind.values.map((InstallmentKind e) => e.name),
        <String>['base', 'rescheduled'],
      );
      expect(TxType.values.map((TxType e) => e.name), <String>[
        'disbursement',
        'payment',
        'rolloverSettlement',
        'reversal',
        'reschedule',
      ]);
      expect(PaymentMode.values.map((PaymentMode e) => e.name), <String>[
        'upi',
        'cash',
        'bank',
      ]);
      expect(InviteStatus.values.map((InviteStatus e) => e.name), <String>[
        'pending',
        'accepted',
        'revoked',
      ]);
    });

    test('every value serialises to its name through the models', () {
      for (final s in ContractStatus.values) {
        final json = Fixtures.contract.copyWith(status: s).toJson();
        expect(json['status'], s.name);
        expect(
          Contract.fromJson(<String, dynamic>{...json, 'id': 'x'}).status,
          s,
        );
      }
      for (final f in Frequency.values) {
        final json = Fixtures.contract.copyWith(frequency: f).toJson();
        expect(json['frequency'], f.name);
      }
      for (final m in UpfrontMode.values) {
        final json = Fixtures.contract.copyWith(upfrontMode: m).toJson();
        expect(json['upfrontMode'], m.name);
      }
      for (final t in TxType.values) {
        final json = Fixtures.transaction.copyWith(type: t).toJson();
        expect(json['type'], t.name);
        expect(
          LedgerTransaction.fromJson(<String, dynamic>{
            ...json,
            'id': 'x',
          }).type,
          t,
        );
      }
      for (final m in PaymentMode.values) {
        final json = Fixtures.transaction.copyWith(mode: m).toJson();
        expect(json['mode'], m.name);
      }
      for (final k in InstallmentKind.values) {
        final json = Fixtures.installment.copyWith(kind: k).toJson();
        expect(json['kind'], k.name);
      }
      for (final r in Role.values) {
        final json = Fixtures.member.copyWith(role: r).toJson();
        expect(json['role'], r.name);
      }
      for (final s in InviteStatus.values) {
        final json = Fixtures.invite.copyWith(status: s).toJson();
        expect(json['status'], s.name);
      }
    });

    test('unknown enum string is rejected', () {
      final json = <String, dynamic>{
        ...Fixtures.contract.toJson(),
        'id': 'x',
        'status': 'ROLLED_OVER',
      };
      expect(() => Contract.fromJson(json), throwsArgumentError);
    });
  });

  group('defaults', () {
    test('UserSettings.defaults()', () {
      final s = UserSettings.defaults('uid-1');
      expect(s.id, 'uid-1');
      expect(s.activeCompanyId, isNull);
      expect(s.notifications.digestEnabled, isTrue);
      expect(s.notifications.digestTime, '08:00');
      expect(s.notifications.perInstallmentEnabled, isFalse);
      expect(s.notifications.overdueNudgeEnabled, isTrue);
      expect(s.autoLockMinutes, 1);
      expect(s.updatedAt, isNull);
      expect(s.schemaVersion, 1);
    });

    test('missing optional keys fall back to schema defaults', () {
      final contract = Contract.fromJson(<String, dynamic>{
        ..._without(Fixtures.contract.toJson(), <String>[
          'status',
          'totalPaidPaise',
          'schemaVersion',
        ]),
        'id': 'c',
      });
      expect(contract.status, ContractStatus.active);
      expect(contract.totalPaid, Money.zero);
      expect(contract.schemaVersion, 1);

      final ins = Installment.fromJson(<String, dynamic>{
        ..._without(Fixtures.installment.toJson(), <String>[
          'rescheduledOutPaise',
          'rescheduledToIds',
          'kind',
        ]),
        'id': 'i',
      });
      expect(ins.rescheduledOut, Money.zero);
      expect(ins.rescheduledToIds, isEmpty);
      expect(ins.kind, InstallmentKind.base);

      final settings = UserSettings.fromJson(<String, dynamic>{'id': 'u'});
      expect(settings, UserSettings.defaults('u'));
    });

    test('Member status defaults to active; Borrower not archived', () {
      final m = Member.fromJson(<String, dynamic>{
        ..._without(Fixtures.member.toJson(), <String>['status']),
        'id': 'm',
      });
      expect(m.status, 'active');
      final b = Borrower.fromJson(<String, dynamic>{
        ..._without(Fixtures.borrower.toJson(), <String>['archived']),
        'id': 'b',
      });
      expect(b.archived, isFalse);
    });

    test('nullable money and dates round-trip as null', () {
      final c = Fixtures.contract.copyWith(
        rolloverSettled: null,
        lastPaymentOn: null,
        closedAt: null,
      );
      final json = c.toJson();
      expect(json['rolloverSettledPaise'], isNull);
      expect(json['lastPaymentOn'], isNull);
      expect(json['closedAt'], isNull);
      expect(Contract.fromJson(<String, dynamic>{...json, 'id': c.id}), c);
    });

    test('malformed civil date is rejected', () {
      final json = <String, dynamic>{
        ...Fixtures.installment.toJson(),
        'id': 'i',
        'dueDate': '2027-02-30',
      };
      expect(() => Installment.fromJson(json), throwsFormatException);
    });
  });

  group('domain helpers', () {
    test('Contract.isActive', () {
      for (final s in ContractStatus.values) {
        expect(
          Fixtures.contract.copyWith(status: s).isActive,
          s == ContractStatus.active,
        );
      }
    });

    test('Invite.isExpired is true from expiresAt onwards', () {
      final invite = Fixtures.invite;
      final exp = invite.expiresAt;
      expect(invite.isExpired(exp.subtract(const Duration(seconds: 1))), false);
      expect(invite.isExpired(exp), isTrue);
      expect(invite.isExpired(exp.add(const Duration(days: 1))), isTrue);
      expect(invite.expiresAt.difference(invite.createdAt).inDays, 7);
    });

    test('Invite.isAcceptable requires pending and unexpired', () {
      final pending = Fixtures.invite.copyWith(status: InviteStatus.pending);
      final before = pending.expiresAt.subtract(const Duration(hours: 1));
      expect(pending.isAcceptable(before), isTrue);
      expect(pending.isAcceptable(pending.expiresAt), isFalse);
      expect(
        pending.copyWith(status: InviteStatus.revoked).isAcceptable(before),
        isFalse,
      );
    });

    test('LedgerTransaction.effectiveRecordedAt falls back while pending', () {
      final tx = Fixtures.transaction;
      expect(tx.effectiveRecordedAt, Fixtures.t1);
      expect(
        tx.copyWith(recordedAt: null).effectiveRecordedAt,
        tx.clientRecordedAt,
      );
    });
  });
}
