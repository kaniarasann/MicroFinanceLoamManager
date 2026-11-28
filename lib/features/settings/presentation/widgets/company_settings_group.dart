import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../domain/models/models.dart';
import '../../../company/application/company_providers.dart';
import '../../../company/application/members_providers.dart';
import '../../../company/presentation/widgets/company_switcher_sheet.dart';
import '../../../company/presentation/widgets/role_pill.dart';
import 'settings_group.dart';
import 'settings_tile.dart';

/// Company: active company (opens the switcher), Members & invites (owner;
/// "Members" for a collector), join another company, register a new one.
class CompanySettingsGroup extends ConsumerWidget {
  const CompanySettingsGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(activeCompanyNameProvider) ?? '';
    final role = ref.watch(currentRoleProvider);
    final isOwner = role == Role.owner;
    final members = ref.watch(companyMembersProvider).value;
    final invites = isOwner
        ? ref.watch(pendingInvitesProvider).value
        : const <Invite>[];

    String? membersLine;
    if (members != null) {
      final m = members.length == 1 ? '1 member' : '${members.length} members';
      final n = invites?.length ?? 0;
      membersLine = !isOwner || n == 0
          ? m
          : '$m · ${n == 1 ? '1 invite' : '$n invites'} pending';
    }

    return SettingsGroup(
      title: 'Company',
      children: <Widget>[
        SettingsTile(
          key: const ValueKey<String>('settings_company'),
          icon: Icons.storefront_outlined,
          title: name,
          subtitle: 'Active company · tap to switch',
          trailing: role == null ? null : RolePill(role: role),
          onTap: () => unawaited(showCompanySwitcher(context)),
        ),
        SettingsTile(
          key: const ValueKey<String>('settings_members'),
          icon: Icons.group_outlined,
          title: isOwner ? 'Members & invites' : 'Members',
          subtitle: membersLine,
          tabularSubtitle: true,
          onTap: () => unawaited(context.push<void>(AppRoutes.members)),
        ),
        SettingsTile(
          key: const ValueKey<String>('settings_join'),
          icon: Icons.group_add_outlined,
          title: 'Join another company with a code',
          onTap: () => unawaited(context.push<void>(AppRoutes.onboardingJoin)),
        ),
        SettingsTile(
          key: const ValueKey<String>('settings_register'),
          icon: Icons.add_business_outlined,
          title: 'Register a new company',
          onTap: () =>
              unawaited(context.push<void>(AppRoutes.onboardingRegister)),
        ),
      ],
    );
  }
}
