import '../../core/money/inr_format.dart';
import '../../core/money/money.dart';
import '../models/enums.dart';
import 'contract_projection.dart';
import 'upfront.dart';

/// Result of a rollover quote. When [isValid] is false, [error] explains why
/// and the rollover must not be written.
final class RolloverQuote {
  const RolloverQuote({
    required this.settledOldOutstanding,
    required this.newUpfront,
    required this.netCash,
    required this.isValid,
    this.error,
  });

  /// Old contract's outstanding, settled by the new loan
  /// (the `rolloverSettlement` amount).
  final Money settledOldOutstanding;
  final Money newUpfront;

  /// Cash handed over: newSanctioned − newUpfront − oldOutstanding.
  final Money netCash;
  final bool isValid;
  final String? error;
}

/// netCash = newSanctioned − newUpfront − oldOutstanding; must be ≥ 0.
///
/// Example: old outstanding ₹18,000, new ₹1,00,000 at flat ₹7,000 → ₹75,000.
RolloverQuote computeRollover({
  required ContractProjection oldProjection,
  required Money newSanctioned,
  required UpfrontMode upfrontMode,
  required int upfrontInput,
}) {
  final old = oldProjection.outstanding;
  final upfront = computeUpfront(newSanctioned, upfrontMode, upfrontInput);
  final net = newSanctioned - upfront - old;

  String? error;
  if (!newSanctioned.isPositive) {
    error = 'New sanctioned amount must be more than ₹0.';
  } else if (upfrontMode == UpfrontMode.percent &&
      (upfrontInput < 0 || upfrontInput > bpsScale)) {
    error = 'Upfront percentage must be between 0% and 100%.';
  } else if (upfront.isNegative) {
    error = 'Upfront interest cannot be negative.';
  } else if (upfront >= newSanctioned) {
    error = 'Upfront interest must be less than the new sanctioned amount.';
  } else if (net.isNegative) {
    error =
        'The new loan of ${formatInr(newSanctioned)} minus upfront '
        '${formatInr(upfront)} does not cover the old outstanding '
        '${formatInr(old)}. Increase the new amount by at least '
        '${formatInr(-net)}.';
  }

  return RolloverQuote(
    settledOldOutstanding: old,
    newUpfront: upfront,
    netCash: net,
    isValid: error == null,
    error: error,
  );
}
