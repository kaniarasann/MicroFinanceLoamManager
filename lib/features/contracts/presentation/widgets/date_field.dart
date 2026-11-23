import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/civil_date.dart';

/// A 56dp read-only field showing a civil date; tapping opens the Material
/// date picker limited to [first]..[last].
class DateField extends StatelessWidget {
  const DateField({
    required this.label,
    required this.value,
    required this.first,
    required this.last,
    required this.onChanged,
    this.errorText,
    this.fieldKey,
    super.key,
  });

  final String label;
  final CivilDate value;
  final CivilDate first;
  final CivilDate last;
  final ValueChanged<CivilDate> onChanged;
  final String? errorText;
  final Key? fieldKey;

  static DateTime _dt(CivilDate d) => DateTime(d.year, d.month, d.day);

  Future<void> _pick(BuildContext context) async {
    final initial = value.isBefore(first)
        ? first
        : (value.isAfter(last) ? last : value);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dt(initial),
      firstDate: _dt(first),
      lastDate: _dt(last),
    );
    if (picked != null) {
      onChanged(CivilDate(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      key: fieldKey,
      borderRadius: AppRadii.baseAll,
      onTap: () => unawaited(_pick(context)),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
          constraints: const BoxConstraints(minHeight: AppSizes.inputHeight),
        ),
        child: Text(
          '${formatCivilDateWithWeekday(value)} ${value.year}',
          style: AppTextStyles.bodyLgTabular,
        ),
      ),
    ),
  );
}
