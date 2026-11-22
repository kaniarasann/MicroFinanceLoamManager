import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Section title with an optional trailing action ("View all").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Custom trailing widget; takes precedence over [actionLabel].
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final action =
        trailing ??
        (actionLabel == null
            ? null
            : TextButton(onPressed: onAction, child: Text(actionLabel!)));
    return Padding(
      padding: AppInsets.sectionHeader,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: AppTextStyles.headlineSm),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
