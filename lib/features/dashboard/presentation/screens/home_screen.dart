import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/adaptive_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../company/application/company_providers.dart';
import '../../../company/presentation/widgets/company_switcher_sheet.dart';
import '../../../company/presentation/widgets/role_pill.dart';
import '../../../../domain/models/enums.dart';

/// Placeholder Dashboard inside the app shell. The header shows
/// "{Company} ▾ · {Role}" and opens the company switcher.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

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

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(activeCompanyNameProvider) ?? '';
    final role = ref.watch(currentRoleProvider);
    final label = HomeScreen.destinations[_index].label;

    return AdaptiveScaffold(
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
          // Temporary entry point until Settings (Sprint 8).
          PopupMenuButton<String>(
            key: const ValueKey<String>('home_menu'),
            tooltip: 'More',
            icon: const Icon(Icons.more_vert),
            onSelected: (String route) => unawaited(context.push<void>(route)),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                key: const ValueKey<String>('menu_members'),
                value: AppRoutes.members,
                child: Text(
                  role == Role.owner ? 'Members & invites' : 'Members',
                ),
              ),
            ],
          ),
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
      body: EmptyState(
        key: ValueKey<String>('home_placeholder_$_index'),
        icon: HomeScreen.destinations[_index].icon,
        title: _index == 0
            ? 'Dashboard coming in Sprint 7'
            : '$label is on its way',
        message:
            'Your company is set up. Lending features arrive in the '
            'next sprints.',
      ),
    );
  }
}
