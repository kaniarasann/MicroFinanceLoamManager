import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

/// `users/{uid}`. [id] is the uid (doc id, not stored in the body).
@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    @JsonKey(includeToJson: false) required String id,
    required String displayName,
    required String email,
    String? photoUrl,
    String? phoneE164,
    required DateTime createdAt,
    @Default(1) int schemaVersion,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}
