import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/today_provider.dart';
import '../../../domain/ledger/ledger.dart';
import '../../borrowers/application/borrower_providers.dart';
import '../../borrowers/application/reminder_message.dart';
import '../../borrowers/presentation/widgets/borrower_profile_view.dart'
    show ContactCopy;
import '../../company/application/company_providers.dart';
import '../../contracts/application/ledger_providers.dart';

/// Opens the dialer for [phoneE164]; a snackbar explains a failure.
Future<void> callBorrower(
  BuildContext context,
  WidgetRef ref,
  String phoneE164,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!await ref.read(contactLauncherProvider).call(phoneE164)) {
    messenger?.showSnackBar(
      const SnackBar(content: Text(ContactCopy.callUnavailable)),
    );
  }
}

/// Opens WhatsApp with the polite reminder for [contractId]'s earliest
/// open installment (see [ReminderMessage.build]).
Future<void> whatsAppBorrower(
  BuildContext context,
  WidgetRef ref, {
  required String phoneE164,
  required String borrowerName,
  required String contractId,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final projection = ref.read(activeProjectionsProvider).value?[contractId];
  final text = ReminderMessage.build(
    borrowerName: borrowerName,
    companyName: ref.read(activeCompanyNameProvider) ?? '',
    active: <ContractProjection>[?projection],
    today: ref.read(todayProvider),
  );
  if (!await ref.read(contactLauncherProvider).whatsApp(phoneE164, text)) {
    messenger?.showSnackBar(
      const SnackBar(content: Text(ContactCopy.whatsAppUnavailable)),
    );
  }
}
