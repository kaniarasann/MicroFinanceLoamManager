import 'package:flutter/material.dart';

import '../../../../core/widgets/empty_state.dart';

/// Stand-in page for `/contracts/{id}/pay` until Sprint 6. The `newLoan` and
/// `detail` variants are kept for tests that stub those routes.
class ContractPlaceholderScreen extends StatelessWidget {
  const ContractPlaceholderScreen._({
    required this.title,
    required this.message,
    this.icon = Icons.description_outlined,
    super.key,
  });

  factory ContractPlaceholderScreen.newLoan({String? borrowerId, Key? key}) =>
      ContractPlaceholderScreen._(
        key: key ?? ValueKey<String>('contract_new_${borrowerId ?? ''}'),
        title: 'New loan',
        message: 'Creating a loan arrives with the contracts screen.',
        icon: Icons.add_card_outlined,
      );

  factory ContractPlaceholderScreen.detail({
    required String contractId,
    Key? key,
  }) => ContractPlaceholderScreen._(
    key: key ?? ValueKey<String>('contract_detail_$contractId'),
    title: 'Loan details',
    message: 'The installment timeline arrives with the contracts screen.',
  );

  factory ContractPlaceholderScreen.payment({
    required String contractId,
    Key? key,
  }) => ContractPlaceholderScreen._(
    key: key ?? ValueKey<String>('contract_pay_$contractId'),
    title: 'Record payment',
    message: 'Recording payments arrives in the next sprint.',
    icon: Icons.payments_outlined,
  );

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: EmptyState(title: title, message: message, icon: icon),
  );
}
