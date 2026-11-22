import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/money/money.dart';
import 'package:nordic_ledger/core/time/civil_date.dart';
import 'package:nordic_ledger/domain/models/models.dart';

void main() {
  test('MoneyPaiseConverter', () {
    const c = MoneyPaiseConverter();
    expect(c.toJson(const Money(10000000)), 10000000);
    expect(c.fromJson(10000000), const Money.fromRupees(100000));
  });

  test('NullableMoneyPaiseConverter', () {
    const c = NullableMoneyPaiseConverter();
    expect(c.toJson(null), isNull);
    expect(c.fromJson(null), isNull);
    expect(c.fromJson(5), const Money(5));
    expect(c.toJson(const Money(5)), 5);
  });

  test('CivilDateConverter', () {
    const c = CivilDateConverter();
    expect(c.toJson(const CivilDate(2027, 1, 5)), '2027-01-05');
    expect(c.fromJson('2024-02-29'), const CivilDate(2024, 2, 29));
    expect(() => c.fromJson('05-01-2027'), throwsFormatException);
  });

  test('NullableCivilDateConverter', () {
    const c = NullableCivilDateConverter();
    expect(c.toJson(null), isNull);
    expect(c.fromJson(null), isNull);
    expect(c.fromJson('2026-11-21'), const CivilDate(2026, 11, 21));
    expect(c.toJson(const CivilDate(2026, 11, 21)), '2026-11-21');
  });
}
