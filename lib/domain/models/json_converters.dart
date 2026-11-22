import 'package:json_annotation/json_annotation.dart';

import '../../core/money/money.dart';
import '../../core/time/civil_date.dart';

/// `Money` <-> `int` paise (the stored form).
final class MoneyPaiseConverter implements JsonConverter<Money, int> {
  const MoneyPaiseConverter();

  @override
  Money fromJson(int json) => Money(json);

  @override
  int toJson(Money object) => object.paise;
}

/// Nullable variant of [MoneyPaiseConverter].
final class NullableMoneyPaiseConverter implements JsonConverter<Money?, int?> {
  const NullableMoneyPaiseConverter();

  @override
  Money? fromJson(int? json) => json == null ? null : Money(json);

  @override
  int? toJson(Money? object) => object?.paise;
}

/// `CivilDate` <-> `'yyyy-MM-dd'` (IST civil date).
final class CivilDateConverter implements JsonConverter<CivilDate, String> {
  const CivilDateConverter();

  @override
  CivilDate fromJson(String json) => CivilDate.parse(json);

  @override
  String toJson(CivilDate object) => object.toString();
}

/// Nullable variant of [CivilDateConverter].
final class NullableCivilDateConverter
    implements JsonConverter<CivilDate?, String?> {
  const NullableCivilDateConverter();

  @override
  CivilDate? fromJson(String? json) =>
      json == null ? null : CivilDate.parse(json);

  @override
  String? toJson(CivilDate? object) => object?.toString();
}
