import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../money/inr_format.dart';
import '../money/money.dart';
import '../theme/app_theme.dart';

/// 56dp rupee input: `₹` prefix (PJS 600, textSecondary), tabular digits,
/// Indian grouping applied live while typing. Reports the parsed amount via
/// [onChanged] (`null` when empty or invalid).
class CurrencyField extends StatefulWidget {
  const CurrencyField({
    this.controller,
    this.initialValue,
    this.onChanged,
    this.label,
    this.hintText = '0',
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction,
    this.large = false,
    super.key,
  });

  final TextEditingController? controller;
  final Money? initialValue;
  final ValueChanged<Money?>? onChanged;

  /// Shown above the field (sentence case).
  final String? label;
  final String hintText;
  final String? errorText;
  final String? helperText;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  /// Big amount entry (Record Payment): currencyDisplay digits.
  final bool large;

  @override
  State<CurrencyField> createState() => _CurrencyFieldState();
}

class _CurrencyFieldState extends State<CurrencyField> {
  TextEditingController? _ownController;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    if (initial != null && _controller.text.isEmpty && !initial.isNegative) {
      _controller.text = formatInrPlain(initial);
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      textInputAction: widget.textInputAction,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const <TextInputFormatter>[IndianGroupingFormatter()],
      style: widget.large
          ? AppTextStyles.currencyDisplayTabular
          : AppTextStyles.titleMdTabular,
      onChanged: (String text) => widget.onChanged?.call(parseInrInput(text)),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle:
            (widget.large
                    ? AppTextStyles.currencyDisplayTabular
                    : AppTextStyles.titleMdTabular)
                .copyWith(color: AppColors.textTertiary),
        errorText: widget.errorText,
        helperText: widget.helperText,
        prefixIcon: const Padding(
          padding: AppInsets.currencyPrefix,
          child: Text(rupeeSign, style: AppTextStyles.currencyPrefix),
        ),
        prefixIconConstraints: const BoxConstraints(),
        constraints: const BoxConstraints(minHeight: AppSizes.inputHeight),
      ),
    );
    final label = widget.label;
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.labelMd.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        field,
      ],
    );
  }
}

/// Live Indian digit grouping (`100000` → `1,00,000`) with up to two
/// decimals. Rejects edits that would make the text invalid.
class IndianGroupingFormatter extends TextInputFormatter {
  const IndianGroupingFormatter();

  static final RegExp _raw = RegExp(r'^(\d*)(\.\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) return newValue.copyWith(text: '');

    final match = _raw.firstMatch(raw);
    if (match == null) return oldValue;

    var intPart = match.group(1)!;
    final fraction = match.group(2) ?? '';
    if (intPart.length > maxInputRupeeDigits) return oldValue;
    if (intPart.isEmpty) intPart = '0';

    final formatted = '${groupIndianDigits(int.parse(intPart))}$fraction';

    // Keep the caret after the same number of non-comma characters from
    // the end as in the raw edit.
    final cursor = newValue.selection.end.clamp(0, newValue.text.length);
    final trailing = newValue.text.substring(cursor).replaceAll(',', '').length;
    var offset = formatted.length;
    var seen = 0;
    while (offset > 0 && seen < trailing) {
      offset--;
      if (formatted[offset] != ',') seen++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
