import '../../../core/money/inr_format.dart';
import '../../../core/time/civil_date.dart';
import '../../../domain/ledger/ledger.dart';
import '../../company/application/invite_message.dart';
import '../../contracts/application/loan_label.dart';

/// Polite payment-reminder text and contact URIs. Pure; no I/O.
abstract final class ReminderMessage {
  /// The earliest open installment across [active] (overdue rows first by
  /// date), or null when nothing is open.
  static ({ContractProjection projection, ProjectedRow row})? nextOpen(
    Iterable<ContractProjection> active,
  ) {
    ({ContractProjection projection, ProjectedRow row})? best;
    for (final p in active) {
      final row = p.nextDue;
      if (row == null) continue;
      if (best == null || row.dueDate.isBefore(best.row.dueDate)) {
        best = (projection: p, row: row);
      }
    }
    return best;
  }

  /// "Hello {name}, this is a gentle reminder from {company}: ₹X for Loan
  /// #NN is due on 24 Oct 2023. Thank you." Overdue rows read "was due".
  /// Without an open installment, a plain greeting.
  static String build({
    required String borrowerName,
    required String companyName,
    required Iterable<ContractProjection> active,
    required CivilDate today,
  }) {
    final from = companyName.isEmpty ? '' : ' from $companyName';
    final next = nextOpen(active);
    if (next == null) return 'Hello $borrowerName, greetings$from. Thank you.';
    final amount = formatInr(next.row.remaining);
    final loan = loanNumber(next.projection.contract.loanNo);
    final when = formatCivilDate(next.row.dueDate);
    final verb = next.row.dueDate.isBefore(today) ? 'was due' : 'is due';
    return 'Hello $borrowerName, this is a gentle reminder$from: '
        '$amount for Loan $loan $verb on $when. Thank you.';
  }

  static Uri telUri(String phoneE164) => Uri(scheme: 'tel', path: phoneE164);

  static Uri whatsAppUri(String phoneE164, String message) =>
      InviteMessage.whatsAppUri(phoneE164, message);
}
