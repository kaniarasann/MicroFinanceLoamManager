import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../domain/models/models.dart';
import '../../../company/application/company_providers.dart';
import '../../application/borrower_providers.dart';
import 'borrower_row.dart';

/// Borrower list: title, "+ Add borrower" (owner only), the "Search name or
/// phone" field, filter chips and the rows.
class BorrowerListPane extends ConsumerStatefulWidget {
  const BorrowerListPane({
    required this.onSelect,
    required this.onAdd,
    this.selectedId,
    super.key,
  });

  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;
  final String? selectedId;

  @override
  ConsumerState<BorrowerListPane> createState() => _BorrowerListPaneState();
}

class _BorrowerListPaneState extends ConsumerState<BorrowerListPane> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: ref.read(borrowerQueryStateProvider).text,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(currentRoleProvider) == Role.owner;
    final query = ref.watch(borrowerQueryStateProvider);
    final all = ref.watch(borrowersProvider);
    final results = ref.watch(borrowerSearchProvider);
    final margin = WindowSize.of(context).margin;
    final hasAny = (all.value ?? const <Borrower>[]).isNotEmpty;

    final Widget body;
    if (results.hasValue && !hasAny) {
      body = EmptyState(
        key: const ValueKey<String>('borrowers_empty'),
        icon: Icons.people_outline,
        title: isOwner ? 'Add your first borrower' : 'No borrowers yet',
        message: isOwner
            ? 'Save a borrower to start lending to them.'
            : 'Borrowers added by an owner appear here.',
        action: isOwner
            ? FilledButton.icon(
                key: const ValueKey<String>('borrowers_empty_add'),
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add borrower'),
              )
            : null,
      );
    } else if (results.hasValue) {
      final items = results.requireValue;
      body = items.isEmpty
          ? const EmptyState(
              key: ValueKey<String>('borrowers_no_match'),
              icon: Icons.search_off,
              title: 'No matching borrowers',
              message: 'Try another name, number or filter.',
            )
          : ListView.separated(
              key: const ValueKey<String>('borrowers_list'),
              padding: EdgeInsets.fromLTRB(
                margin,
                AppSpacing.xs,
                margin,
                AppSpacing.xl,
              ),
              itemCount: items.length,
              separatorBuilder: (BuildContext _, int _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (BuildContext context, int i) {
                final item = items[i];
                return BorrowerRow(
                  key: ValueKey<String>('borrower_row_${item.borrower.id}'),
                  item: item,
                  selected: item.borrower.id == widget.selectedId,
                  onTap: () => widget.onSelect(item.borrower.id),
                );
              },
            );
    } else if (results.hasError) {
      body = const EmptyState(
        icon: Icons.cloud_off_outlined,
        title: "Borrowers can't be loaded right now",
        message: 'Check your connection and try again.',
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(margin, AppSpacing.md, margin, 0),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Text('Borrowers', style: AppTextStyles.headlineSm),
              ),
              if (isOwner)
                FilledButton.icon(
                  key: const ValueKey<String>('borrowers_add'),
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add borrower'),
                ),
            ],
          ),
        ),
        if (hasAny) ...<Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(margin, AppSpacing.md, margin, 0),
            child: TextField(
              key: const ValueKey<String>('borrowers_search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: ref.read(borrowerQueryStateProvider.notifier).setText,
              style: AppTextStyles.bodyLgTabular,
              decoration: InputDecoration(
                hintText: 'Search name or phone',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          ref
                              .read(borrowerQueryStateProvider.notifier)
                              .setText('');
                        },
                      ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(
              margin,
              AppSpacing.sm,
              margin,
              AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                for (final f in BorrowerFilter.values) ...<Widget>[
                  ChoiceChip(
                    key: ValueKey<String>('filter_${f.name}'),
                    label: Text(f.label),
                    selected: query.filter == f,
                    onSelected: (bool _) => ref
                        .read(borrowerQueryStateProvider.notifier)
                        .setFilter(f),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ],
        Expanded(child: body),
      ],
    );
  }
}
