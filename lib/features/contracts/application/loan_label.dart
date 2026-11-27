import '../../../core/time/civil_date.dart';
import '../../../domain/models/models.dart';

/// "#04": the display form of a contract's loan number.
String loanNumber(int loanNo) => '#${loanNo.toString().padLeft(2, '0')}';

/// "Loan #04".
String loanLabel(int loanNo) => 'Loan ${loanNumber(loanNo)}';

/// "Daily" / "Weekly" / "Monthly".
String frequencyLabel(Frequency f) => switch (f) {
  Frequency.daily => 'Daily',
  Frequency.weekly => 'Weekly',
  Frequency.monthly => 'Monthly',
};

/// "UPI" / "Cash" / "Bank".
String paymentModeLabel(PaymentMode m) => switch (m) {
  PaymentMode.upi => 'UPI',
  PaymentMode.cash => 'Cash',
  PaymentMode.bank => 'Bank',
};

/// "Onboarded 24 Nov 2026" for an onboarded contract, else null.
String? onboardedLabel(Contract c) {
  final on = c.onboardedOn;
  if (!c.isOnboarded || on == null) return null;
  return 'Onboarded ${formatCivilDate(on)}';
}

/// Ledger label of a payment written at onboarding: "Opening balance"
/// (spread opening total) or "Recorded at onboarding" (itemised), else
/// null for live payments and other types.
String? onboardingPaymentLabel(LedgerTransaction t) {
  if (t.type != TxType.payment || !t.isOnboarding) return null;
  return t.openingBalance ? 'Opening balance' : 'Recorded at onboarding';
}
