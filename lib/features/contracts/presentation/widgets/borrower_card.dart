import 'package:flutter/material.dart';

import '../../../../core/phone/indian_phone.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../domain/models/models.dart';
import '../../../borrowers/presentation/widgets/borrower_form.dart';
import 'borrower_picker_sheet.dart';

/// "Borrower details" on the create-contract form: the selected borrower
/// with Change (picker) and New borrower (the existing borrower form).
class BorrowerCard extends StatelessWidget {
  const BorrowerCard({
    required this.borrower,
    required this.onPicked,
    this.loading = false,
    this.errorText,
    super.key,
  });

  final Borrower? borrower;
  final bool loading;
  final String? errorText;
  final ValueChanged<String> onPicked;

  Future<void> _pick(BuildContext context) async {
    final id = await showBorrowerPicker(context);
    if (id != null) onPicked(id);
  }

  Future<void> _create(BuildContext context) async {
    final id = await showBorrowerForm(context);
    if (id != null) onPicked(id);
  }

  @override
  Widget build(BuildContext context) {
    final b = borrower;
    final error = errorText;
    return AppCard(
      key: const ValueKey<String>('borrower_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Borrower details',
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (b != null) ...<Widget>[
            Text(b.name, style: AppTextStyles.titleMd),
            Text(
              <String>[
                IndianPhone.format(b.phoneE164),
                if (b.locality != null) b.locality!,
              ].join(' · '),
              style: AppTextStyles.bodyMdTabular.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ] else if (loading)
            const LinearProgressIndicator()
          else
            const Text('No borrower selected', style: AppTextStyles.bodyMd),
          if (error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              error,
              key: const ValueKey<String>('borrower_error'),
              style: AppTextStyles.bodySm.copyWith(color: AppColors.overdue),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              OutlinedButton.icon(
                key: const ValueKey<String>('borrower_change'),
                onPressed: () => _pick(context),
                icon: const Icon(Icons.person_search_outlined),
                label: Text(b == null ? 'Choose borrower' : 'Change'),
              ),
              TextButton.icon(
                key: const ValueKey<String>('borrower_new'),
                onPressed: () => _create(context),
                icon: const Icon(Icons.person_add_alt_outlined),
                label: const Text('New borrower'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
