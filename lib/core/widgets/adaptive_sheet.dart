import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';
import '../theme/app_theme.dart';

/// Opens [builder]'s content as a modal bottom sheet (top radius 24) on
/// compact windows, or as a centred dialog (max width 560) on medium and
/// expanded windows. Used for Record Payment, Rollover, etc.
Future<T?> showAdaptiveSheet<T>(BuildContext context, WidgetBuilder builder) {
  if (WindowSize.of(context) == WindowSize.compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SingleChildScrollView(
          padding: AppInsets.sheet,
          child: builder(sheetContext),
        ),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (BuildContext dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.dialogMaxWidth),
        child: SingleChildScrollView(
          padding: AppInsets.cardSpacious,
          child: builder(dialogContext),
        ),
      ),
    ),
  );
}
