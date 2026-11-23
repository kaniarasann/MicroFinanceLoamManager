import 'dart:developer' as developer;

import 'package:url_launcher/url_launcher.dart';

import '../../company/data/invite_share_service.dart' show LaunchUrlFn;
import '../application/reminder_message.dart';

/// Opens the dialer or WhatsApp for a borrower from the user's own phone.
/// The platform call is injectable for tests.
class ContactLauncher {
  ContactLauncher({LaunchUrlFn? launch}) : _launch = launch ?? _defaultLaunch;

  final LaunchUrlFn _launch;

  /// `tel:+91XXXXXXXXXX` in the dialer (the user still presses call).
  Future<bool> call(String phoneE164) =>
      _try(ReminderMessage.telUri(phoneE164), LaunchMode.externalApplication);

  /// `wa.me` with [message] pre-filled; falls back to the browser.
  Future<bool> whatsApp(String phoneE164, String message) async {
    final uri = ReminderMessage.whatsAppUri(phoneE164, message);
    if (await _try(uri, LaunchMode.externalApplication)) return true;
    return _try(uri, LaunchMode.platformDefault);
  }

  Future<bool> _try(Uri uri, LaunchMode mode) async {
    try {
      return await _launch(uri, mode);
    } on Object catch (e) {
      developer.log(
        'Launch failed: ${uri.scheme}',
        name: 'borrowers',
        error: e,
      );
      return false;
    }
  }

  static Future<bool> _defaultLaunch(Uri uri, LaunchMode mode) =>
      launchUrl(uri, mode: mode);
}
