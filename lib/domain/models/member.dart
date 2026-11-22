import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'member.freezed.dart';
part 'member.g.dart';

/// `companies/{cid}/members/{uid}`. [id] is the uid (also stored as [uid]).
@freezed
abstract class Member with _$Member {
  const factory Member({
    @JsonKey(includeToJson: false) required String id,
    required String uid,
    required Role role,
    required String displayName,
    String? phoneE164,

    /// Always `'active'` in schema v1.
    @Default('active') String status,
    String? inviteCode,
    String? invitedBy,
    required DateTime joinedAt,
    @Default(1) int schemaVersion,
  }) = _Member;

  factory Member.fromJson(Map<String, dynamic> json) => _$MemberFromJson(json);
}
