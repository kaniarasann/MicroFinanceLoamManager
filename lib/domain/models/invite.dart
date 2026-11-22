import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'invite.freezed.dart';
part 'invite.g.dart';

/// `invites/{code}`. [id] is the invite code.
@freezed
abstract class Invite with _$Invite {
  const factory Invite({
    @JsonKey(includeToJson: false) required String id,
    required String companyId,
    required String companyName,
    String? companyCity,
    required Role role,
    required String inviteeName,
    required String inviteePhoneE164,
    required String createdBy,
    required String createdByName,
    required DateTime createdAt,

    /// createdAt + 7 days.
    required DateTime expiresAt,
    @Default(InviteStatus.pending) InviteStatus status,
    String? acceptedBy,
    DateTime? acceptedAt,
    @Default(1) int schemaVersion,
  }) = _Invite;

  const Invite._();

  /// Validity window for a new invite.
  static const Duration validity = Duration(days: 7);

  /// Mirrors the rules check `expiresAt > request.time`: expired once [now]
  /// reaches [expiresAt].
  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  /// Pending and not yet expired.
  bool isAcceptable(DateTime now) =>
      status == InviteStatus.pending && !isExpired(now);

  factory Invite.fromJson(Map<String, dynamic> json) => _$InviteFromJson(json);
}
