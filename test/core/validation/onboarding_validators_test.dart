import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/validation/onboarding_validators.dart';

void main() {
  group('companyName', () {
    test('2–80 chars after trim', () {
      expect(OnboardingValidators.companyName(null), isNotNull);
      expect(OnboardingValidators.companyName('   '), isNotNull);
      expect(OnboardingValidators.companyName(' A '), isNotNull);
      expect(OnboardingValidators.companyName(' AB '), isNull);
      expect(OnboardingValidators.companyName('A' * 80), isNull);
      expect(OnboardingValidators.companyName('  ${'A' * 80}  '), isNull);
      expect(OnboardingValidators.companyName('A' * 81), isNotNull);
    });
  });

  test('displayName required, max 60', () {
    expect(OnboardingValidators.displayName(''), isNotNull);
    expect(OnboardingValidators.displayName('Asha'), isNull);
    expect(OnboardingValidators.displayName('A' * 61), isNotNull);
  });

  group('InviteCode', () {
    test('alphabet excludes 0 O 1 I L', () {
      for (final ch in <String>['0', 'O', '1', 'I', 'L']) {
        expect(InviteCode.alphabet.contains(ch), isFalse, reason: ch);
      }
      expect(InviteCode.alphabet.length, 31);
    });

    test('isValid', () {
      expect(InviteCode.isValid('K7Q2MD'), isTrue);
      expect(InviteCode.isValid('k7q2md'), isFalse);
      expect(InviteCode.isValid('K7Q2M'), isFalse);
      expect(InviteCode.isValid('K7Q2MDX'), isFalse);
      expect(InviteCode.isValid('K7Q2M0'), isFalse);
      expect(InviteCode.isValid('K7Q2MI'), isFalse);
    });

    test('sanitize uppercases and drops non-alphabet chars', () {
      expect(InviteCode.sanitize('k7q-2md'), 'K7Q2MD');
      expect(InviteCode.sanitize(' k7 q2 md xyz'), 'K7Q2MD');
      expect(InviteCode.sanitize('o0i1l'), '');
    });

    test('fromReferrer reads code=', () {
      expect(InviteCode.fromReferrer('code=K7Q2MD'), 'K7Q2MD');
      expect(
        InviteCode.fromReferrer('utm_source=invite&code=k7q2md'),
        'K7Q2MD',
      );
      expect(
        InviteCode.fromReferrer('utm_source%3Dinvite%26code%3DK7Q2MD'),
        'K7Q2MD',
      );
      expect(InviteCode.fromReferrer('utm_source=google-play'), isNull);
      expect(InviteCode.fromReferrer('code=BAD0'), isNull);
      expect(InviteCode.fromReferrer(null), isNull);
      expect(InviteCode.fromReferrer('%E0%A4%A'), isNull);
    });
  });
}
