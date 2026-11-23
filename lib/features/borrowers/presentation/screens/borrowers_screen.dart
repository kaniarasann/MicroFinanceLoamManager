import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/list_detail_layout.dart';
import '../widgets/borrower_form.dart';
import '../widgets/borrower_list_pane.dart';
import '../widgets/borrower_profile_view.dart';

/// The shell's Borrowers destination. Phones push the profile page; on
/// expanded windows a [ListDetailLayout] shows the list (40%) and the
/// selected borrower's profile (60%), with the selected row highlighted.
class BorrowersScreen extends ConsumerStatefulWidget {
  const BorrowersScreen({super.key});

  @override
  ConsumerState<BorrowersScreen> createState() => _BorrowersScreenState();
}

class _BorrowersScreenState extends ConsumerState<BorrowersScreen> {
  String? _selectedId;

  bool get _split => WindowSize.of(context).isExpanded;

  void _open(String id) {
    if (_split) {
      setState(() => _selectedId = id);
    } else {
      unawaited(context.push<void>(AppRoutes.borrower(id)));
    }
  }

  Future<void> _add() async {
    final id = await showBorrowerForm(context);
    if (id != null && mounted && _split) setState(() => _selectedId = id);
  }

  @override
  Widget build(BuildContext context) {
    final split = _split;
    final selected = split ? _selectedId : null;
    return ListDetailLayout(
      list: BorrowerListPane(
        selectedId: selected,
        onSelect: _open,
        onAdd: () => unawaited(_add()),
      ),
      detail: selected == null
          ? null
          : BorrowerProfileView(
              key: ValueKey<String>('profile_pane_$selected'),
              borrowerId: selected,
              onArchived: () => setState(() => _selectedId = null),
            ),
      emptyDetail: const EmptyState(
        key: ValueKey<String>('borrowers_detail_empty'),
        icon: Icons.person_search_outlined,
        title: 'Select a borrower',
        message: 'Their loans, ledger and receipts appear here.',
      ),
    );
  }
}
