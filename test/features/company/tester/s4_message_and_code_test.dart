import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/phone/indian_phone.dart';
import 'package:nordic_ledger/core/time/ist_clock.dart';
import 'package:nordic_ledger/core/validation/onboarding_validators.dart';
import 'package:nordic_ledger/core/widgets/phone_field.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/company/application/invite_message.dart';
import 'package:nordic_ledger/features/onboarding/data/invite_repository.dart';

void main() {
  group('Tester S4 — invite message & URIs', () {
    const name = 'Raju & Sons Finance';
    final msg = InviteMessage.build(
      companyName: name,
      role: Role.collector,
      code: 'K7Q2MD',
    );

    test('message text has company, role, code, play + deep link', () {
      expect(msg, startsWith('Join *Raju & Sons Finance* on Nordic Ledger as Collector.'));
      expect(msg, contains('Invite code: K7Q2MD'));
      expect(msg, contains('referrer=code%3DK7Q2MD'));
      expect(msg, contains('nordicledger://app/join?code=K7Q2MD'));
    });

    test('wa.me URI: no +, & and spaces encoded, round-trips', () {
      final uri = InviteMessage.whatsAppUri('+91 98450 12890', msg);
      final s = uri.toString();
      expect(s, startsWith('https://wa.me/919845012890?text='));
      expect(s, isNot(contains('wa.me/+')));
      final query = s.substring(s.indexOf('?text=') + 6);
      expect(query, isNot(contains(' ')));
      expect(query, isNot(contains('&')));
      expect(query, contains('%26'));
      expect(uri.queryParameters.keys, <String>['text']);
      expect(uri.queryParameters['text'], msg);
    });

    test('sms URI: +E164, body encoded and decodes back to message', () {
      final uri = InviteMessage.smsUri('+919845012890', msg);
      final s = uri.toString();
      expect(s, startsWith('sms:+919845012890?body='));
      final body = s.substring(s.indexOf('?body=') + 6);
      expect(body, isNot(contains('&')));
      expect(body, isNot(contains(' ')));
      expect(Uri.decodeComponent(body), msg);
      expect(uri.queryParameters['body'], msg);
    });

    test('owner role label', () {
      expect(
        InviteMessage.build(companyName: 'X', role: Role.owner, code: 'K7Q2MD'),
        contains('as Owner.'),
      );
    });
  });

  group('Tester S4 — code generation alphabet', () {
    test('5000 generated codes never contain 0/O/1/I/L and are valid', () {
      final repo = InviteRepository(
        firestore: FakeFirebaseFirestore(),
        clock: FixedClock.ist(2026, 11, 21, 10),
        random: Random(42),
      );
      final banned = RegExp('[0O1IL]');
      final seen = <String>{};
      for (var i = 0; i < 5000; i++) {
        final c = repo.generateCode();
        expect(c.length, 6);
        expect(banned.hasMatch(c), isFalse, reason: c);
        expect(InviteCode.isValid(c), isTrue, reason: c);
        seen.addAll(c.split(''));
      }
      expect(InviteCode.alphabet.contains(RegExp('[0O1IL]')), isFalse);
      // every allowed char eventually used
      expect(seen.length, InviteCode.alphabet.length);
    });

    test('isValid rejects ambiguous / short / lowercase codes', () {
      for (final c in <String>['K7Q2M0', 'K7Q2MO', 'K7Q2M1', 'K7Q2MI', 'K7Q2ML', 'K7Q2M', 'k7q2md']) {
        expect(InviteCode.isValid(c), isFalse, reason: c);
      }
    });
  });

  group('Tester S4 — register validation edges', () {
    test('company name 1 char rejected, 2 chars ok', () {
      expect(OnboardingValidators.companyName('A'), isNotNull);
      expect(OnboardingValidators.companyName(' A '), isNotNull);
      expect(OnboardingValidators.companyName('AB'), isNull);
    });

    test('company name 80 ok, 81 rejected, whitespace-only rejected', () {
      expect(OnboardingValidators.companyName('a' * 80), isNull);
      expect(OnboardingValidators.companyName('a' * 81), isNotNull);
      expect(OnboardingValidators.companyName('    '), isNotNull);
      expect(OnboardingValidators.companyName('  ${'a' * 80}  '), isNull);
    });

    test('phone with spaces / +91 / 91 / 0 prefix normalises', () {
      for (final p in <String>['98450 12890', '+91 98450 12890', '+919845012890', '919845012890', '09845012890', '98450-12890']) {
        expect(IndianPhone.toE164(p), '+919845012890', reason: p);
        expect(PhoneField.validate(p, required: true), isNull, reason: p);
      }
    });

    test('invalid phones rejected', () {
      for (final p in <String>['12345 67890', '98450 1289', '+1 98450 12890', '984501289012']) {
        expect(PhoneField.validate(p, required: true), isNotNull, reason: p);
      }
      expect(PhoneField.validate('', required: true), isNotNull);
      expect(PhoneField.validate('', required: false), isNull);
    });
  });
}
