import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/invite_message.dart';

typedef LaunchUrlFn = Future<bool> Function(Uri uri, LaunchMode mode);
typedef ShareTextFn = Future<void> Function(String text, String subject);
typedef CopyTextFn = Future<void> Function(String text);

/// Sends an invite from the owner's own phone: WhatsApp / SMS intents via
/// url_launcher, the system share sheet, or the clipboard. The platform
/// calls are injectable for tests.
class InviteShareService {
  InviteShareService({
    LaunchUrlFn? launch,
    ShareTextFn? share,
    CopyTextFn? copy,
  }) : _launch = launch ?? _defaultLaunch,
       _share = share ?? _defaultShare,
       _copy = copy ?? _defaultCopy;

  final LaunchUrlFn _launch;
  final ShareTextFn _share;
  final CopyTextFn _copy;

  /// Opens WhatsApp through the `wa.me` link. Android hands the https link
  /// to WhatsApp when it is installed and to the browser otherwise. Returns
  /// false when nothing could open it (the screen then suggests SMS).
  Future<bool> openWhatsApp(String phoneE164, String message) async {
    final uri = InviteMessage.whatsAppUri(phoneE164, message);
    if (await _tryLaunch(uri, LaunchMode.externalApplication)) return true;
    return _tryLaunch(uri, LaunchMode.platformDefault);
  }

  /// Opens the SMS app with the message pre-filled.
  Future<bool> openSms(String phoneE164, String message) => _tryLaunch(
    InviteMessage.smsUri(phoneE164, message),
    LaunchMode.externalApplication,
  );

  Future<void> share(String message, {required String subject}) =>
      _share(message, subject);

  Future<void> copy(String text) => _copy(text);

  Future<bool> _tryLaunch(Uri uri, LaunchMode mode) async {
    try {
      return await _launch(uri, mode);
    } on Object catch (e) {
      developer.log('Launch failed: ${uri.scheme}', name: 'invites', error: e);
      return false;
    }
  }

  static Future<bool> _defaultLaunch(Uri uri, LaunchMode mode) =>
      launchUrl(uri, mode: mode);

  static Future<void> _defaultShare(String text, String subject) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }

  static Future<void> _defaultCopy(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}
