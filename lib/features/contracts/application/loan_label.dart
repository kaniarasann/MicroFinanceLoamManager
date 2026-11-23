import '../../../domain/models/enums.dart';

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
