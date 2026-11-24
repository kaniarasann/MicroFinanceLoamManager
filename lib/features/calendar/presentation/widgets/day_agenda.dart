import 'package:flutter/material.dart';

import '../../../../core/money/inr_format.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../dashboard/presentation/widgets/due_row_card.dart';

/// One day's collections: a tinted header ("Tue, 24 Nov" · "3 collections
/// · ₹42,500") followed by a [DueRowCard] per scheduled row.
class DayAgenda extends StatelessWidget {
  const DayAgenda({
    required this.date,
    required this.items,
    this.today,
    this.onHeaderTap,
    super.key,
  });

  final CivilDate date;
  final List<DueRowItem> items;
  final CivilDate? today;

  /// Selects this day (list mode on tablets).
  final VoidCallback? onHeaderTap;

  @override
  Widget build(BuildContext context) {
    final total = Money.sum(items.map((DueRowItem i) => i.amount));
    final n = items.length;
    final title =
        '${formatCivilDateWithWeekday(date)}'
        '${date == today ? ' · Today' : ''}';
    final header = Material(
      color: AppColors.primarySubtle,
      borderRadius: AppRadii.mdAll,
      child: InkWell(
        borderRadius: AppRadii.mdAll,
        onTap: onHeaderTap,
        child: Padding(
          padding: AppInsets.banner,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTouchTarget - AppSpacing.md,
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(title, style: AppTextStyles.headlineSmTabular),
                ),
                Text(
                  n == 0
                      ? 'Nothing scheduled'
                      : '${n == 1 ? '1 collection' : '$n collections'} · '
                            '${formatInr(total)}',
                  style: AppTextStyles.labelLgTabular.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Column(
      key: ValueKey<String>('day_agenda_$date'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        header,
        const SizedBox(height: AppSpacing.sm),
        if (items.isEmpty)
          Padding(
            padding: AppInsets.listRow,
            child: Text(
              'No collections are scheduled for this day.',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          for (final item in items) ...<Widget>[
            DueRowCard(item: item),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}
