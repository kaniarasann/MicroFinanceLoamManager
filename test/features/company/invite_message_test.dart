import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/validation/onboarding_validators.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/company/application/invite_message.dart';
import 'package:nordic_ledger/features/company/data/invite_share_service.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  const play =
      'https://play.google.com/store/apps/details?id=com.nordicledger.app'
      '&referrer=code%3DK7Q2MD';

  test('exact message text', () {
    expect(
      InviteMessage.build(
        companyName: 'Sri Lakshmi Finance',
        role: Role.collector,
        code: 'K7Q2MD',
      ),
      'Join *Sri Lakshmi Finance* on Nordic Ledger as Collector. '
      'Install: $play · Invite code: K7Q2MD · '
      'Open: nordicledger://app/join?code=K7Q2MD',
    );
    expect(
      InviteMessage.build(companyName: 'A', role: Role.owner, code: 'K7Q2MD'),
      startsWith('Join *A* on Nordic Ledger as Owner. '),
    );
  });

  test('play link carries the code as an encoded referrer', () {
    final link = InviteMessage.playLink('K7Q2MD');
    expect(link, play);
    final referrer = Uri.parse(link).queryParameters['referrer'];
    expect(referrer, 'code=K7Q2MD');
    // The install-referrer reader gets the code back.
    expect(InviteCode.fromReferrer(referrer), 'K7Q2MD');
  });

  test('deep link', () {
    expect(
      InviteMessage.deepLink('K7Q2MD'),
      'nordicledger://app/join?code=K7Q2MD',
    );
  });

  final message = InviteMessage.build(
    companyName: 'Sri & Sons',
    role: Role.collector,
    code: 'K7Q2MD',
  );

  test('wa.me URI: digits only, url-encoded text', () {
    final uri = InviteMessage.whatsAppUri('+919845012890', message);
    final s = uri.toString();
    expect(s, startsWith('https://wa.me/919845012890?text='));
    expect(s, contains('Join%20*Sri%20%26%20Sons*'));
    expect(s, isNot(contains(' ')));
    expect(s, contains('referrer%3Dcode%253DK7Q2MD'));
    expect(uri.queryParameters['text'], message);
  });

  test('sms URI: +91 number, url-encoded body', () {
    final uri = InviteMessage.smsUri('+919845012890', message);
    final s = uri.toString();
    expect(s, startsWith('sms:+919845012890?body='));
    expect(s, isNot(contains(' ')));
    expect(uri.queryParameters['body'], message);
  });

  group('InviteShareService', () {
    test(
      'WhatsApp falls back to the browser when the app link fails',
      () async {
        final calls = <LaunchMode>[];
        final svc = InviteShareService(
          launch: (Uri uri, LaunchMode mode) async {
            calls.add(mode);
            return mode == LaunchMode.platformDefault;
          },
        );
        expect(await svc.openWhatsApp('+919845012890', 'hi'), isTrue);
        expect(calls, <LaunchMode>[
          LaunchMode.externalApplication,
          LaunchMode.platformDefault,
        ]);
      },
    );

    test('returns false when nothing can open the link', () async {
      final svc = InviteShareService(
        launch: (Uri uri, LaunchMode mode) async => throw StateError('none'),
      );
      expect(await svc.openWhatsApp('+919845012890', 'hi'), isFalse);
      expect(await svc.openSms('+919845012890', 'hi'), isFalse);
    });

    test('sms opens the sms: URI', () async {
      Uri? opened;
      final svc = InviteShareService(
        launch: (Uri uri, LaunchMode mode) async {
          opened = uri;
          return true;
        },
      );
      expect(await svc.openSms('+919845012890', 'hi there'), isTrue);
      expect(opened.toString(), 'sms:+919845012890?body=hi%20there');
    });
  });
}
