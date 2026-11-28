import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/adaptive_scaffold.dart';
import '../../../../core/widgets/day_ticker.dart';
import '../../../borrowers/presentation/screens/borrowers_screen.dart';
import '../../../calendar/presentation/screens/calendar_screen.dart';
import '../../../company/application/company_providers.dart';
import '../../../company/presentation/widgets/company_switcher_sheet.dart';
import '../../../company/presentation/widgets/role_pill.dart';
import '../../../../domain/models/enums.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import 'dashboard_screen.dart';

/// The company shell: Dashboard · Calendar · Borrowers · Settings. The
/// header shows "{Company} ▾ · {Role}" and opens the company switcher.
/// Owners get the "New loan" FAB in the expanded rail.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({this.initialTab, super.key});

  /// `?tab=` of `/home`: `dashboard`, `today` (Dashboard scrolled to Due
  /// Today, the digest notification), `calendar`, `borrowers` or
  /// `settings`. Anything else keeps the current tab.
  final String? initialTab;

  /// Destination index for a `?tab=` value, or null.
  static int? indexForTab(String? tab) => switch (tab) {
    'dashboard' || 'today' => dashboardIndex,
    'calendar' => calendarIndex,
    'borrowers' => borrowersIndex,
    'settings' => settingsIndex,
    _ => null,
  };

  static const List<AdaptiveDestination> destinations = <AdaptiveDestination>[
    AdaptiveDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    AdaptiveDestination(
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      label: 'Calendar',
    ),
    AdaptiveDestination(
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'Borrowers',
    ),
    AdaptiveDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  static const int dashboardIndex = 0;
  static const int calendarIndex = 1;

  /// Index of the Borrowers destination.
  static const int borrowersIndex = 2;

  /// Index of the Settings destination.
  static const int settingsIndex = 3;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  /// Bumped to scroll the dashboard to Due Today.
  int _dueTodayFocus = 0;

  @override
  void initState() {
    super.initState();
    _applyTab(widget.initialTab);
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A notification can re-open `/home?tab=today` while already on /home.
    _applyTab(widget.initialTab);
  }

  void _applyTab(String? tab) {
    final i = HomeScreen.indexForTab(tab);
    if (i == null) return;
    _index = i;
    if (tab == 'today') _dueTodayFocus++;
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(activeCompanyNameProvider) ?? '';
    final role = ref.watch(currentRoleProvider);

    return DayTicker(
      child: AdaptiveScaffold(
        destinations: HomeScreen.destinations,
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        appBar: AppBar(
          titleSpacing: AppSpacing.md,
          title: Semantics(
            button: true,
            label: 'Switch company',
            child: InkWell(
              key: const ValueKey<String>('company_header'),
              borderRadius: AppRadii.baseAll,
              onTap: () => unawaited(showCompanySwitcher(context)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.minTouchTarget,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        name,
                        style: AppTextStyles.headlineSm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.textSecondary,
                    ),
                    if (role != null)
                      Text(
                        '· ${roleLabel(role)}',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: <Widget>[
            if (kDebugMode)
              IconButton(
                key: const ValueKey<String>('dev_gallery'),
                tooltip: 'Theme gallery (debug)',
                icon: const Icon(Icons.palette_outlined),
                onPressed: () =>
                    unawaited(context.push<void>(AppRoutes.devGallery)),
              ),
          ],
        ),
        floatingActionButton: role == Role.owner
            ? FloatingActionButton(
                key: const ValueKey<String>('rail_new_loan'),
                heroTag: 'rail_new_loan',
                tooltip: 'New loan',
                onPressed: () =>
                    unawaited(context.push<void>(AppRoutes.newContract())),
                child: const Icon(Icons.add),
              )
            : null,
        applyMargins: _index != HomeScreen.borrowersIndex,
        body: switch (_index) {
          HomeScreen.dashboardIndex => DashboardScreen(
            focusDueToday: _dueTodayFocus,
            onOpenCalendar: () =>
                setState(() => _index = HomeScreen.calendarIndex),
          ),
          HomeScreen.calendarIndex => const CalendarScreen(),
          HomeScreen.borrowersIndex => const BorrowersScreen(),
          _ => const SettingsScreen(),
        },
      ),
    );
  }
}
