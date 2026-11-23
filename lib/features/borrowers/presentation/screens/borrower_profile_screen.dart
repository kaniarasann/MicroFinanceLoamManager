import 'package:flutter/material.dart';

import '../widgets/borrower_profile_view.dart';

/// Borrower profile as a page (`/borrowers/{id}`), used on compact and
/// medium windows. Tablets show [BorrowerProfileView] in the split view.
class BorrowerProfileScreen extends StatelessWidget {
  const BorrowerProfileScreen({required this.borrowerId, super.key});

  final String borrowerId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Borrower')),
    body: SafeArea(
      top: false,
      child: BorrowerProfileView(
        borrowerId: borrowerId,
        onArchived: () => Navigator.of(context).maybePop(),
      ),
    ),
  );
}
