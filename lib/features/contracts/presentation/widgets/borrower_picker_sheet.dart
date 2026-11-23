import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/phone/indian_phone.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/adaptive_sheet.dart';
import '../../../../domain/models/models.dart';
import '../../../borrowers/application/borrower_providers.dart';

/// Picks a borrower of the active company. Resolves to the borrower id, or
/// null when dismissed.
Future<String?> showBorrowerPicker(BuildContext context) =>
    showAdaptiveSheet<String>(
      context,
      (BuildContext _) => const BorrowerPickerSheet(),
    );

/// Searchable list (name or phone) of the company's borrowers.
class BorrowerPickerSheet extends ConsumerStatefulWidget {
  const BorrowerPickerSheet({super.key});

  @override
  ConsumerState<BorrowerPickerSheet> createState() =>
      _BorrowerPickerSheetState();
}

class _BorrowerPickerSheetState extends ConsumerState<BorrowerPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(borrowersProvider).value ?? const <Borrower>[];
    final matches = <Borrower>[
      for (final b in all)
        if (matchesBorrowerQuery(b, _query)) b,
    ];
    return Column(
      key: const ValueKey<String>('borrower_picker'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('Choose borrower', style: AppTextStyles.headlineSm),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey<String>('borrower_picker_search'),
          autofocus: true,
          onChanged: (String v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Search name or phone',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (matches.isEmpty)
          Padding(
            padding: AppInsets.emptyState,
            child: Text(
              all.isEmpty ? 'No borrowers yet.' : 'No matching borrowers.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        for (final b in matches)
          ListTile(
            key: ValueKey<String>('pick_${b.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(b.name, style: AppTextStyles.titleMd),
            subtitle: Text(
              IndianPhone.format(b.phoneE164),
              style: AppTextStyles.bodySmTabular,
            ),
            onTap: () => Navigator.of(context).pop(b.id),
          ),
      ],
    );
  }
}
