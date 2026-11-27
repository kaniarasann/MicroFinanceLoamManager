import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/phone/indian_phone.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/today_provider.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/kpi_tile.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/segmented_toggle.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../domain/ledger/ledger.dart';
import '../../../../domain/models/models.dart';
import '../../../company/application/company_providers.dart';
import '../../../company/presentation/widgets/member_avatar.dart';
import '../../application/borrower_providers.dart';
import '../../application/reminder_message.dart';
import 'active_contract_card.dart';
import 'borrower_form.dart';
import 'closed_contract_card.dart';
import 'ledger_entry_tile.dart';
import 'standing_pill.dart';

/// Profile tabs.
enum ProfileTab { active, ledger, closed }

/// Snackbar copy for contact actions.
abstract final class ContactCopy {
  static const String callUnavailable = "Couldn't open the dialer.";
  static const String whatsAppUnavailable = "Couldn't open WhatsApp.";
}

/// Borrower profile: header, Active exposure / Lifetime lent / Collected,
/// Call / WhatsApp / + New loan, Active / Ledger / Closed tabs and recent
/// receipts. Used as a page on phones and as the detail pane on tablets.
class BorrowerProfileView extends ConsumerStatefulWidget {
  const BorrowerProfileView({
    required this.borrowerId,
    this.onArchived,
    super.key,
  });

  final String borrowerId;

  /// Called after the borrower was archived (leave the profile).
  final VoidCallback? onArchived;

  @override
  ConsumerState<BorrowerProfileView> createState() =>
      _BorrowerProfileViewState();
}

class _BorrowerProfileViewState extends ConsumerState<BorrowerProfileView> {
  ProfileTab _tab = ProfileTab.active;

  @override
  void didUpdateWidget(BorrowerProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.borrowerId != widget.borrowerId) _tab = ProfileTab.active;
  }

  @override
  Widget build(BuildContext context) {
    final borrowerAsync = ref.watch(borrowerProvider(widget.borrowerId));
    final summaryAsync = ref.watch(borrowerSummaryProvider(widget.borrowerId));
    final isOwner = ref.watch(currentRoleProvider) == Role.owner;
    final margin = WindowSize.of(context).margin;

    final borrower = borrowerAsync.value;
    if (borrower == null) {
      if (borrowerAsync.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const EmptyState(
        icon: Icons.person_off_outlined,
        title: 'Borrower not found',
        message: 'They may have been archived.',
      );
    }
    final summary = summaryAsync.value;

    return ListView(
      key: ValueKey<String>('borrower_profile_${borrower.id}'),
      padding: EdgeInsets.fromLTRB(
        margin,
        AppSpacing.md,
        margin,
        AppSpacing.xl,
      ),
      children: <Widget>[
        _Header(
          borrower: borrower,
          summary: summary,
          isOwner: isOwner,
          onEdit: () =>
              unawaited(showBorrowerForm(context, existing: borrower)),
          onArchive: () => unawaited(_archive(borrower, summary)),
        ),
        const SizedBox(height: AppSpacing.md),
        if (summary == null)
          summaryAsync.hasError
              ? const AppCard(
                  child: Text(
                    "Loan figures can't be loaded right now.",
                    style: AppTextStyles.bodyMd,
                  ),
                )
              : const Padding(
                  padding: AppInsets.cardSpacious,
                  child: Center(child: CircularProgressIndicator()),
                )
        else ...<Widget>[
          _StatTiles(summary: summary),
          const SizedBox(height: AppSpacing.md),
          _Actions(borrower: borrower, summary: summary, isOwner: isOwner),
          const SizedBox(height: AppSpacing.lg),
          SegmentedToggle<ProfileTab>(
            key: const ValueKey<String>('profile_tabs'),
            expand: true,
            selected: _tab,
            onChanged: (ProfileTab t) => setState(() => _tab = t),
            segments: <ToggleSegment<ProfileTab>>[
              ToggleSegment<ProfileTab>(
                value: ProfileTab.active,
                label: 'Active (${summary.active.length})',
              ),
              const ToggleSegment<ProfileTab>(
                value: ProfileTab.ledger,
                label: 'Ledger',
              ),
              ToggleSegment<ProfileTab>(
                value: ProfileTab.closed,
                label: 'Closed (${summary.closed.length})',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ..._tabContent(context, summary),
          if (_tab != ProfileTab.ledger) ...<Widget>[
            const SectionHeader(title: 'Recent receipts'),
            _Receipts(entries: summary.recentReceipts),
          ],
        ],
      ],
    );
  }

  List<Widget> _tabContent(BuildContext context, BorrowerSummary summary) {
    switch (_tab) {
      case ProfileTab.active:
        if (summary.active.isEmpty) {
          return const <Widget>[_InlineEmpty(text: 'No active loans.')];
        }
        return <Widget>[
          for (final p in summary.active) ...<Widget>[
            ActiveContractCard(
              projection: p,
              onOpen: () => unawaited(
                context.push<void>(AppRoutes.contract(p.contract.id)),
              ),
              onRecord: () => unawaited(
                context.push<void>(AppRoutes.recordPayment(p.contract.id)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ];
      case ProfileTab.ledger:
        if (summary.ledger.isEmpty) {
          return const <Widget>[_InlineEmpty(text: 'No transactions yet.')];
        }
        return <Widget>[
          AppCard(
            child: Column(
              children: <Widget>[
                for (var i = 0; i < summary.ledger.length; i++) ...<Widget>[
                  if (i > 0) const Divider(),
                  LedgerEntryTile(entry: summary.ledger[i]),
                ],
              ],
            ),
          ),
        ];
      case ProfileTab.closed:
        if (summary.closed.isEmpty) {
          return const <Widget>[_InlineEmpty(text: 'No closed loans.')];
        }
        return <Widget>[
          for (final c in summary.closed) ...<Widget>[
            ClosedContractCard(
              contract: c,
              successor: c.rolledOverToContractId == null
                  ? null
                  : summary.contractsById[c.rolledOverToContractId],
              onOpen: () =>
                  unawaited(context.push<void>(AppRoutes.contract(c.id))),
              onOpenSuccessor: c.rolledOverToContractId == null
                  ? null
                  : () => unawaited(
                      context.push<void>(
                        AppRoutes.contract(c.rolledOverToContractId!),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ];
    }
  }

  Future<void> _archive(Borrower borrower, BorrowerSummary? summary) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if ((summary?.active.length ?? 0) > 0) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Close or roll over active loans before archiving.'),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Archive ${borrower.name}?'),
        content: const Text(
          'They disappear from the borrower list. Their loan history is kept.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey<String>('archive_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final outcome = await ref
          .read(borrowerActionsProvider)
          .archive(borrower.id);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(BorrowerCopy.saved(outcome, BorrowerCopy.archived)),
        ),
      );
      widget.onArchived?.call();
    } on Object {
      messenger?.showSnackBar(
        const SnackBar(content: Text("Couldn't archive. Please try again.")),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.borrower,
    required this.summary,
    required this.isOwner,
    required this.onEdit,
    required this.onArchive,
  });

  final Borrower borrower;
  final BorrowerSummary? summary;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final stats = summary?.stats;
    final locality = borrower.locality;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MemberAvatar(name: borrower.name, size: AppSizes.avatarLg),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  borrower.name,
                  style: AppTextStyles.headlineSm,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  IndianPhone.format(borrower.phoneE164),
                  style: AppTextStyles.bodyMdTabular.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (locality != null)
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.place_outlined,
                        size: AppSizes.iconSm,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          locality,
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (stats != null && stats.activeCount > 0) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  StandingPill(
                    standing: stats.standing,
                    daysOverdue: stats.maxDaysOverdue,
                  ),
                ],
              ],
            ),
          ),
          if (isOwner)
            PopupMenuButton<String>(
              key: const ValueKey<String>('borrower_menu'),
              tooltip: 'Borrower options',
              icon: const Icon(Icons.more_vert),
              onSelected: (String v) => v == 'edit' ? onEdit() : onArchive(),
              itemBuilder: (BuildContext context) =>
                  const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      key: ValueKey<String>('borrower_edit'),
                      value: 'edit',
                      child: Text('Edit details'),
                    ),
                    PopupMenuItem<String>(
                      key: ValueKey<String>('borrower_archive'),
                      value: 'archive',
                      child: Text('Archive borrower'),
                    ),
                  ],
            ),
        ],
      ),
    );
  }
}

class _StatTiles extends StatelessWidget {
  const _StatTiles({required this.summary});

  final BorrowerSummary summary;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: KpiTile(
              key: const ValueKey<String>('tile_exposure'),
              label: 'Active exposure',
              value: summary.activeExposure,
              valueKind: summary.stats.standing == Standing.overdue
                  ? StatusKind.overdue
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: KpiTile(
              key: const ValueKey<String>('tile_lent'),
              label: 'Lifetime lent',
              value: summary.lifetimeLent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: KpiTile(
              key: const ValueKey<String>('tile_collected'),
              label: 'Collected',
              value: summary.collected,
              valueKind: StatusKind.collected,
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({
    required this.borrower,
    required this.summary,
    required this.isOwner,
  });

  final Borrower borrower;
  final BorrowerSummary summary;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> call() async {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (!await ref.read(contactLauncherProvider).call(borrower.phoneE164)) {
        messenger?.showSnackBar(
          const SnackBar(content: Text(ContactCopy.callUnavailable)),
        );
      }
    }

    Future<void> whatsApp() async {
      final messenger = ScaffoldMessenger.maybeOf(context);
      final text = ReminderMessage.build(
        borrowerName: borrower.name,
        companyName: ref.read(activeCompanyNameProvider) ?? '',
        active: summary.active,
        today: ref.read(todayProvider),
      );
      if (!await ref
          .read(contactLauncherProvider)
          .whatsApp(borrower.phoneE164, text)) {
        messenger?.showSnackBar(
          const SnackBar(content: Text(ContactCopy.whatsAppUnavailable)),
        );
      }
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        OutlinedButton.icon(
          key: const ValueKey<String>('borrower_call'),
          onPressed: () => unawaited(call()),
          icon: const Icon(Icons.call_outlined),
          label: const Text('Call'),
        ),
        OutlinedButton.icon(
          key: const ValueKey<String>('borrower_whatsapp'),
          onPressed: () => unawaited(whatsApp()),
          icon: const Icon(Icons.chat_outlined),
          label: const Text('WhatsApp'),
        ),
        if (isOwner)
          FilledButton.icon(
            key: const ValueKey<String>('borrower_new_loan'),
            onPressed: () => unawaited(
              context.push<void>(
                AppRoutes.newContract(borrowerId: borrower.id),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('New loan'),
          ),
        if (isOwner)
          OutlinedButton.icon(
            key: const ValueKey<String>('borrower_existing_loan'),
            onPressed: () => unawaited(
              context.push<void>(
                AppRoutes.onboardContract(borrowerId: borrower.id),
              ),
            ),
            icon: const Icon(Icons.history),
            label: const Text('Existing loan'),
          ),
      ],
    );
  }
}

class _Receipts extends StatelessWidget {
  const _Receipts({required this.entries});

  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _InlineEmpty(text: 'No payments recorded yet.');
    }
    return AppCard(
      key: const ValueKey<String>('recent_receipts'),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < entries.length; i++) ...<Widget>[
            if (i > 0) const Divider(),
            LedgerEntryTile(entry: entries[i]),
          ],
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Text(
      text,
      style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
    ),
  );
}
