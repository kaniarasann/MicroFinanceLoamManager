import 'package:flutter/widgets.dart';

import 'app_theme.dart';

/// Material 3 window size classes.
///
/// compact < 600dp, medium 600–839dp, expanded >= 840dp. Consumed via
/// `AdaptiveScaffold` / `ListDetailLayout`, not per-screen MediaQuery maths.
enum WindowSize {
  compact,
  medium,
  expanded;

  static const double mediumMinWidth = 600;
  static const double expandedMinWidth = 840;

  /// Body content never grows wider than this.
  static const double maxContentWidth = 1280;

  static WindowSize fromWidth(double width) {
    if (width >= expandedMinWidth) return WindowSize.expanded;
    if (width >= mediumMinWidth) return WindowSize.medium;
    return WindowSize.compact;
  }

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  /// Heights below this (dp) are "short", e.g. a phone in landscape
  /// (~410dp). Navigation chrome goes compact there whatever the width.
  static const double shortHeightMax = 480;

  static bool isShortHeightValue(double height) => height < shortHeightMax;

  /// True when the window is too short for the full expanded rail.
  static bool isShortHeight(BuildContext context) =>
      isShortHeightValue(MediaQuery.sizeOf(context).height);

  /// Horizontal page margin: 16 / 24 / 32.
  double get margin => switch (this) {
    WindowSize.compact => AppSpacing.md,
    WindowSize.medium => AppSpacing.lg,
    WindowSize.expanded => AppSpacing.xl,
  };

  /// Columns for simple tile grids (KPI tiles etc.): 2 / 2 / 4.
  int get tileColumns => switch (this) {
    WindowSize.compact => 2,
    WindowSize.medium => 2,
    WindowSize.expanded => 4,
  };

  bool get isCompact => this == WindowSize.compact;
  bool get isExpanded => this == WindowSize.expanded;
}
