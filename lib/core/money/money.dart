/// Immutable money amount in integer paise (1 rupee = 100 paise).
///
/// Pure Dart (usable from `lib/domain/`). Never use `double` for money.
final class Money implements Comparable<Money> {
  const Money(this.paise);

  const Money.fromPaise(this.paise);

  /// Whole rupees to paise.
  const Money.fromRupees(int rupees) : paise = rupees * 100;

  static const Money zero = Money(0);

  final int paise;

  /// Whole-rupee part, truncated toward zero.
  int get rupeesPart => paise ~/ 100;

  /// Absolute paise remainder (0–99).
  int get paisePart => paise.remainder(100).abs();

  bool get isZero => paise == 0;
  bool get isNegative => paise < 0;
  bool get isPositive => paise > 0;

  Money abs() => Money(paise.abs());

  Money operator +(Money other) => Money(paise + other.paise);
  Money operator -(Money other) => Money(paise - other.paise);
  Money operator -() => Money(-paise);

  /// Multiplies by an integer factor (e.g. instalment count).
  Money operator *(int factor) => Money(paise * factor);

  bool operator <(Money other) => paise < other.paise;
  bool operator <=(Money other) => paise <= other.paise;
  bool operator >(Money other) => paise > other.paise;
  bool operator >=(Money other) => paise >= other.paise;

  /// This amount as basis points of [total] (10000 = 100%), truncated toward
  /// zero. Returns 0 when [total] is zero.
  int percentOf(Money total) {
    if (total.paise == 0) return 0;
    return (paise * 10000) ~/ total.paise;
  }

  static Money min(Money a, Money b) => a <= b ? a : b;
  static Money max(Money a, Money b) => a >= b ? a : b;

  static Money sum(Iterable<Money> values) =>
      values.fold(Money.zero, (Money acc, Money m) => acc + m);

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  @override
  bool operator ==(Object other) => other is Money && other.paise == paise;

  @override
  int get hashCode => paise.hashCode;

  @override
  String toString() => 'Money($paise paise)';
}
