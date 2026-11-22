import 'package:freezed_annotation/freezed_annotation.dart';

part 'company.freezed.dart';
part 'company.g.dart';

/// `companies/{companyId}`.
@freezed
abstract class Company with _$Company {
  const factory Company({
    @JsonKey(includeToJson: false) required String id,
    required String name,
    required String nameLower,
    String? city,
    String? phoneE164,
    required List<String> ownerUids,

    /// Display counter, only ever `increment(1)`-ed per contract.
    @Default(1) int nextLoanNo,
    required String createdBy,
    required DateTime createdAt,
    @Default(1) int schemaVersion,
  }) = _Company;

  factory Company.fromJson(Map<String, dynamic> json) =>
      _$CompanyFromJson(json);
}
