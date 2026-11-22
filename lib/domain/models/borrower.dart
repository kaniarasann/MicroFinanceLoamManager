import 'package:freezed_annotation/freezed_annotation.dart';

part 'borrower.freezed.dart';
part 'borrower.g.dart';

/// `companies/{cid}/borrowers/{borrowerId}`.
///
/// Exposure, lifetime lent and collected are derived, never stored.
@freezed
abstract class Borrower with _$Borrower {
  const factory Borrower({
    @JsonKey(includeToJson: false) required String id,
    required String name,
    required String nameLower,
    required String phoneE164,
    String? locality,
    String? notes,
    @Default(false) bool archived,
    required String createdBy,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(1) int schemaVersion,
  }) = _Borrower;

  factory Borrower.fromJson(Map<String, dynamic> json) =>
      _$BorrowerFromJson(json);
}
