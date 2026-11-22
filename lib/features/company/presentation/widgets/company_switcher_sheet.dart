import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/adaptive_sheet.dart';
import '../../../../domain/models/models.dart';
import '../../application/company_providers.dart';
import 'company_avatar.dart';
import 'role_pill.dart';

/// Opens the company switcher (bottom sheet on compact, dialog otherwise).
Future<void> showCompanySwitcher(BuildContext context) =>
    showAdaptiveSheet<void>(
      context,
      (BuildContext _) => const CompanySwitcherSheet(),
    );

/// Memberships with role pills (active one checked), plus "Join another
/// company" and "Register a new company".
class CompanySwitcherSheet extends ConsumerWidget {
  const CompanySwitcherSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships =
        ref.watch(membershipsProvider).value ?? const <Membership>[];
    final activeId = ref.watch(activeCompanyIdProvider).value;
    final router = GoRouter.of(context);

    void close() => Navigator.of(context).pop();

    return Column(
      key: const ValueKey<String>('company_switcher'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('Switch company', style: AppTextStyles.headlineSm),
        const SizedBox(height: AppSpacing.sm),
        for (final m in memberships)
          _CompanyRow(
            membership: m,
            active: m.id == activeId,
            onTap: () {
              if (m.id != activeId) {
                unawaited(ref.read(companyActionsProvider).switchTo(m.id));
              }
              close();
            },
          ),
        const SizedBox(height: AppSpacing.sm),
        const Divider(),
        ListTile(
          key: const ValueKey<String>('switcher_join'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.group_add_outlined),
          title: const Text('Join another company'),
          onTap: () {
            close();
            unawaited(router.push<void>(AppRoutes.onboardingJoin));
          },
        ),
        ListTile(
          key: const ValueKey<String>('switcher_register'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.add_business_outlined),
          title: const Text('Register a new company'),
          onTap: () {
            close();
            unawaited(router.push<void>(AppRoutes.onboardingRegister));
          },
        ),
      ],
    );
  }
}

class _CompanyRow extends StatelessWidget {
  const _CompanyRow({
    required this.membership,
    required this.active,
    required this.onTap,
  });

  final Membership membership;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      button: true,
      child: InkWell(
        key: ValueKey<String>('switcher_company_${membership.id}'),
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: active ? AppColors.primarySubtle : null,
            borderRadius: AppRadii.mdAll,
          ),
          child: Row(
            children: <Widget>[
              const SizedBox(width: AppSpacing.sm),
              CompanyAvatar(name: membership.companyName),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      membership.companyName,
                      style: AppTextStyles.titleMd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    RolePill(role: membership.role),
                  ],
                ),
              ),
              if (active)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  semanticLabel: 'Active company',
                ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
