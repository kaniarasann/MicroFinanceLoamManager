import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';
import '../theme/app_theme.dart';

Widget _sheetBody(BuildContext sheetContext, WidgetBuilder builder) => Padding(
  padding: EdgeInsets.only(
    bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
  ),
  child: SingleChildScrollView(
    padding: AppInsets.sheet,
    child: builder(sheetContext),
  ),
);

Widget _dialogBody(BuildContext dialogContext, WidgetBuilder builder) => Dialog(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: AppSizes.dialogMaxWidth),
    child: SingleChildScrollView(
      padding: AppInsets.cardSpacious,
      child: builder(dialogContext),
    ),
  ),
);

/// Opens [builder]'s content as a modal bottom sheet (top radius 24) on
/// compact windows, or as a centred dialog (max width 560) on medium and
/// expanded windows. Used for Record Payment, Rollover, etc.
Future<T?> showAdaptiveSheet<T>(BuildContext context, WidgetBuilder builder) {
  if (WindowSize.of(context) == WindowSize.compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext c) => _sheetBody(c, builder),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (BuildContext c) => _dialogBody(c, builder),
  );
}

/// The same adaptive presentation as [showAdaptiveSheet], as a router
/// [Page] (go_router `pageBuilder`), so a deep link such as
/// `/contracts/{id}/pay` opens as a sheet / dialog over the previous page.
class AdaptiveSheetPage<T> extends Page<T> {
  const AdaptiveSheetPage({required this.builder, super.key, super.name});

  final WidgetBuilder builder;

  @override
  Route<T> createRoute(BuildContext context) {
    if (WindowSize.of(context) == WindowSize.compact) {
      return ModalBottomSheetRoute<T>(
        settings: this,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (BuildContext c) => _sheetBody(c, builder),
      );
    }
    return DialogRoute<T>(
      context: context,
      settings: this,
      builder: (BuildContext c) => _dialogBody(c, builder),
    );
  }
}
