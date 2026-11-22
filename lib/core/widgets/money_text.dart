import 'package:flutter/material.dart';

import '../money/inr_format.dart';
import '../money/money.dart';
import '../theme/app_theme.dart';

/// Renders a [Money] amount, always with tabular figures.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.value, {
    this.style,
    this.color,
    this.short = false,
    this.textAlign,
    this.maxLines = 1,
    super.key,
  });

  final Money value;

  /// Defaults to [AppTextStyles.currencyItem].
  final TextStyle? style;
  final Color? color;

  /// Chart-axis short form (`₹1.5L`).
  final bool short;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final base = AppTextStyles.tabular(style ?? AppTextStyles.currencyItem);
    return Text(
      short ? formatInrShort(value) : formatInr(value),
      style: color == null ? base : base.copyWith(color: color),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }
}
