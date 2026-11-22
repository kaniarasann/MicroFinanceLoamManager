import '../../core/money/money.dart';
import '../models/enums.dart';

/// Basis points in 100%.
const int bpsScale = 10000;

/// Upfront interest deducted at disbursement.
///
/// - [UpfrontMode.flat]: [input] is paise and is returned as-is.
/// - [UpfrontMode.percent]: [input] is basis points (750 = 7.50%) and the
///   result is `sanctioned × bps / 10000`, rounded half-up to whole paise.
///
/// No validation here (see `validateContractTerms`); negative inputs are
/// returned unchanged so that the validator can report them.
Money computeUpfront(Money sanctioned, UpfrontMode mode, int input) {
  switch (mode) {
    case UpfrontMode.flat:
      return Money(input);
    case UpfrontMode.percent:
      return Money(_divRoundHalfUp(sanctioned.paise * input, bpsScale));
  }
}

/// Cash handed to the borrower: `sanctioned − upfront`.
Money computeNetDisbursed(Money sanctioned, Money upfront) =>
    sanctioned - upfront;

/// Upfront as basis points of [sanctioned], rounded half-up
/// (₹7,000 of ₹1,00,000 → 700 = 7.00%). 0 when [sanctioned] is not positive.
int effectiveBps(Money upfront, Money sanctioned) {
  if (sanctioned.paise <= 0) return 0;
  return _divRoundHalfUp(upfront.paise * bpsScale, sanctioned.paise);
}

/// Integer division rounding half away from zero (half-up for positives).
int _divRoundHalfUp(int numerator, int denominator) {
  final negative = (numerator < 0) != (denominator < 0);
  final n = numerator.abs();
  final d = denominator.abs();
  final q = (n * 2 + d) ~/ (d * 2);
  return negative ? -q : q;
}
