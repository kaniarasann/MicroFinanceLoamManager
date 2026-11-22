import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'membership.freezed.dart';
part 'membership.g.dart';

/// `users/{uid}/memberships/{companyId}`. [id] is the company id.
@freezed
abstract class Membership with _$Membership {
  const factory Membership({
    @JsonKey(includeToJson: false) required String id,
    required String companyId,
    required String companyName,
    required Role role,
    required DateTime joinedAt,
    @Default(1) int schemaVersion,
  }) = _Membership;

  factory Membership.fromJson(Map<String, dynamic> json) =>
      _$MembershipFromJson(json);
}
