import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';
import '../theme/app_theme.dart';

/// A top-level navigation destination.
class AdaptiveDestination {
  const AdaptiveDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
}

/// App shell that adapts navigation to the window size:
/// - compact: bottom [NavigationBar];
/// - medium: [NavigationRail] (icons only);
/// - expanded: [NavigationRail] with labels and optional [floatingActionButton];
/// - short height (< 480dp, e.g. phone landscape): compact rail, FAB moves to
///   the content pane. The rail scrolls rather than overflowing.
///
/// The body is centred, capped at [WindowSize.maxContentWidth] and given
/// the breakpoint margin (16 / 24 / 32).
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.applyMargins = true,
    super.key,
  }) : assert(destinations.length >= 2, 'Navigation needs 2+ destinations');

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final PreferredSizeWidget? appBar;

  /// Shown at the top of the rail on expanded windows; on short expanded
  /// windows it is shown in the content pane instead. Hidden otherwise.
  final Widget? floatingActionButton;

  /// Set false when [body] manages its own horizontal padding
  /// (e.g. a [ListDetailLayout]).
  final bool applyMargins;

  @override
  Widget build(BuildContext context) {
    final size = WindowSize.of(context);
    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: WindowSize.maxContentWidth),
        child: applyMargins
            ? Padding(
                padding: EdgeInsets.symmetric(horizontal: size.margin),
                child: body,
              )
            : body,
      ),
    );

    if (size == WindowSize.compact) {
      return Scaffold(
        appBar: appBar,
        body: content,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: <Widget>[
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon ?? d.icon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    final expanded = size == WindowSize.expanded;
    final shortHeight = WindowSize.isShortHeight(context);
    // Full rail (labels + FAB in the rail) only when there is room for it.
    final fullRail = expanded && !shortHeight;
    final railFab = fullRail ? floatingActionButton : null;
    // On short expanded windows the FAB moves into the content pane.
    final contentFab = expanded && shortHeight ? floatingActionButton : null;

    return Scaffold(
      floatingActionButton: contentFab,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SafeArea(
            right: false,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Scrolls instead of overflowing if even the compact rail
                // is taller than the window.
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: selectedIndex,
                        onDestinationSelected: onDestinationSelected,
                        labelType: fullRail
                            ? NavigationRailLabelType.all
                            : NavigationRailLabelType.none,
                        groupAlignment: -1,
                        leading: railFab != null
                            ? Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: railFab,
                              )
                            : null,
                        destinations: <NavigationRailDestination>[
                          for (final d in destinations)
                            NavigationRailDestination(
                              icon: Icon(d.icon),
                              selectedIcon: Icon(d.selectedIcon ?? d.icon),
                              label: Text(d.label),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const VerticalDivider(),
          // The page title (app bar) lives in the content pane so the rail
          // runs the full body height from the top edge.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ?appBar,
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
