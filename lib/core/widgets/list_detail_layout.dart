import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';

/// List-detail pattern.
///
/// compact / medium: single pane ([detail] when selected, else [list]).
/// expanded: 40/60 split with a 1px divider; [emptyDetail] fills the right
/// pane when nothing is selected.
class ListDetailLayout extends StatelessWidget {
  const ListDetailLayout({
    required this.list,
    required this.emptyDetail,
    this.detail,
    super.key,
  });

  final Widget list;
  final Widget? detail;
  final Widget emptyDetail;

  @override
  Widget build(BuildContext context) {
    if (WindowSize.of(context) != WindowSize.expanded) {
      return detail ?? list;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(flex: 2, child: list),
        const VerticalDivider(),
        Expanded(flex: 3, child: detail ?? emptyDetail),
      ],
    );
  }
}
