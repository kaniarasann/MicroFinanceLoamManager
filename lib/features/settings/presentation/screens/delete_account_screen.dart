import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../application/account_exit.dart';
import '../../application/settings_providers.dart';

/// Settings → Delete account & data (Google Play account deletion).
///
/// Shows, from a fresh server read, what happens to each company (leave,
/// close, or blocked until ownership is handed over), what is deleted and
/// what is kept, then deletes after a confirmation and a Google re-auth.
/// Online only.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _understood = false;
  bool _busy = false;
  bool _pending = false;
  String? _error;

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(settingsActionsProvider).deleteAccount();
      if (!mounted) return;
      switch (result) {
        case DeleteAccountResult.cancelled:
          setState(() => _busy = false);
        case DeleteAccountResult.pending:
          // Stays busy: the clean-up runs when the batch is acknowledged.
          setState(() => _pending = true);
        case DeleteAccountResult.deleted:
          break;
      }
      // Deleted: the session is signed out and the router leaves.
    } on AppFailure catch (f) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = f.userMessage;
      });
      ref.invalidate(accountExitPlanProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(accountExitPlanProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: plan.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace _) => EmptyState(
            key: const ValueKey<String>('delete_account_error'),
            icon: Icons.cloud_off_outlined,
            title: "Couldn't check your companies",
            message: e is AppFailure
                ? e.userMessage
                : 'Deleting your account needs an internet connection.',
            action: OutlinedButton(
              onPressed: () => ref.invalidate(accountExitPlanProvider),
              child: const Text('Try again'),
            ),
          ),
          data: (AccountExitPlan p) => _body(context, p),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AccountExitPlan p) {
    final blocked = p.isBlocked;
    return SingleChildScrollView(
      key: const ValueKey<String>('delete_account'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Delete your account?',
                style: AppTextStyles.headlineLg.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const _Facts(
                icon: Icons.delete_outline,
                title: 'Deleted',
                lines: <String>[
                  'Your sign-in and profile',
                  'Your settings and company memberships',
                  'Your MPIN and reminders on this phone',
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const _Facts(
                icon: Icons.inventory_2_outlined,
                title: 'Kept for your companies',
                lines: <String>[
                  'Loans, payments and borrowers you recorded, with your '
                      'name on them',
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Your companies', style: AppTextStyles.headlineSm),
              const SizedBox(height: AppSpacing.sm),
              if (p.exits.isEmpty)
                Text(
                  "You're not a member of any company.",
                  key: const ValueKey<String>('delete_no_company'),
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              for (final e in p.exits) ...<Widget>[
                _ExitRow(exit: e),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (blocked) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  key: const ValueKey<String>('delete_open_members'),
                  onPressed: () =>
                      unawaited(context.push<void>(AppRoutes.members)),
                  icon: const Icon(Icons.group_outlined),
                  label: const Text('Open Members & invites'),
                ),
              ] else ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                CheckboxListTile(
                  key: const ValueKey<String>('delete_understood'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _understood,
                  onChanged: _busy
                      ? null
                      : (bool? v) => setState(() => _understood = v ?? false),
                  title: const Text(
                    "I understand this can't be undone",
                    style: AppTextStyles.bodyLg,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  key: const ValueKey<String>('delete_confirm'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.overdue,
                    foregroundColor: AppColors.onPrimary,
                  ),
                  onPressed: _understood && !_busy
                      ? () => unawaited(_delete())
                      : null,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: AppSizes.iconMd,
                          child: CircularProgressIndicator(
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Text('Delete my account'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "You'll confirm with Google first. Needs an internet "
                  'connection.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_pending) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.cloud_upload_outlined,
                      color: AppColors.upcoming,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        deletionPendingMessage,
                        key: ValueKey<String>('delete_pending'),
                        style: AppTextStyles.bodyMd,
                      ),
                    ),
                  ],
                ),
              ],
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  key: const ValueKey<String>('delete_error'),
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.overdue,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.icon, required this.title, required this.lines});

  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTextStyles.titleMd),
                for (final l in lines)
                  Text(
                    '· $l',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExitRow extends StatelessWidget {
  const _ExitRow({required this.exit});

  final CompanyExit exit;

  @override
  Widget build(BuildContext context) {
    final blocked = exit.action == ExitAction.blocked;
    final (IconData icon, Color color) = switch (exit.action) {
      ExitAction.blocked => (Icons.block, AppColors.overdue),
      ExitAction.close => (Icons.lock_outline, AppColors.upcoming),
      _ => (Icons.logout, AppColors.textSecondary),
    };
    return Container(
      key: ValueKey<String>('exit_${exit.facts.companyId}'),
      padding: AppInsets.cardCompact,
      decoration: BoxDecoration(
        color: blocked ? AppColors.overdueTint : AppColors.surface,
        border: Border.all(
          color: blocked ? AppColors.overdueBorder : AppColors.border,
        ),
        borderRadius: AppRadii.lgAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(exit.facts.companyName, style: AppTextStyles.titleMd),
                Text(exit.description, style: AppTextStyles.bodyMd),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
