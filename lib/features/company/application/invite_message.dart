import '../../../domain/models/models.dart';

/// How the owner sends an invite from their own phone.
enum InviteChannel { whatsApp, sms, share, copyCode }

/// Builds the invite message and the launch URIs for it. Pure; no I/O.
abstract final class InviteMessage {
  static const String appId = 'com.nordicledger.app';

  /// Custom-scheme deep link handled by the app's intent filter.
  static String deepLink(String code) => 'nordicledger://app/join?code=$code';

  /// Play Store listing carrying the code as an install referrer
  /// (`referrer=code%3D{CODE}`, read once by `InstallReferrerSource`).
  static String playLink(String code) =>
      'https://play.google.com/store/apps/details?id=$appId'
      '&referrer=${Uri.encodeComponent('code=$code')}';

  /// "Join *{companyName}* on Nordic Ledger as {Role}. Install: {playLink} ·
  /// Invite code: {CODE} · Open: nordicledger://app/join?code={CODE}".
  static String build({
    required String companyName,
    required Role role,
    required String code,
  }) =>
      'Join *$companyName* on Nordic Ledger as ${_role(role)}. '
      'Install: ${playLink(code)} · Invite code: $code · '
      'Open: ${deepLink(code)}';

  static String forInvite(Invite invite) => build(
    companyName: invite.companyName,
    role: invite.role,
    code: invite.id,
  );

  /// `https://wa.me/91XXXXXXXXXX?text=<urlencoded>` (wa.me wants the
  /// number without `+`).
  static Uri whatsAppUri(String phoneE164, String message) => Uri.parse(
    'https://wa.me/${_digits(phoneE164)}?text=${Uri.encodeComponent(message)}',
  );

  /// `sms:+91XXXXXXXXXX?body=<urlencoded>`.
  static Uri smsUri(String phoneE164, String message) => Uri.parse(
    'sms:+${_digits(phoneE164)}?body=${Uri.encodeComponent(message)}',
  );

  static String _role(Role role) => switch (role) {
    Role.owner => 'Owner',
    Role.collector => 'Collector',
  };

  static String _digits(String phone) => phone.replaceAll(RegExp(r'\D'), '');
}
