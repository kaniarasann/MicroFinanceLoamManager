import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/clock_provider.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/models/models.dart';
import '../application/company_providers.dart';
import '../application/members_providers.dart';
import '../data/members_repository.dart';
import 'invite_sender.dart';
import 'widgets/invite_form_card.dart';
import 'widgets/member_tile.dart';
import 'widgets/pending_invite_tile.dart';

/// Stitch "9. Members & Invite Staff" (`/settings/members`).
///
/// Owners: invite form, pending invites (resend / revoke) and the member
/// list with change-role / remove. Collectors: the member list, read-only.
/// Expanded windows show two columns (invite form | lists).
class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final Set<String> _busy = <String>{};

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _guarded(String key, Future<void> Function() action) async {
    setState(() => _busy.add(key));
    try {
      await action();
    } on AppFailure catch (f) {
      if (mounted) _snack(f.userMessage);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey<String>('confirm_action'),
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.overdue)
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _resend(Invite invite) => _guarded(
    'invite_${invite.id}',
    () async {
      final fresh = await ref.read(membersActionsProvider).resendInvite(invite);
      if (!mounted) return;
      if (fresh.id != invite.id) {
        _snack('The old code expired. New code ${fresh.id} created.');
      }
      await showInviteShareSheet(context, fresh);
    },
  );

  Future<void> _revoke(Invite invite) async {
    final ok = await _confirm(
      title: 'Revoke invite?',
      message:
          'Code ${invite.id} for ${invite.inviteeName} will stop working. '
          'You can send a new invite later.',
      confirmLabel: 'Revoke',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _guarded('invite_${invite.id}', () async {
      await ref.read(membersActionsProvider).revokeInvite(invite.id);
      if (mounted) _snack('Invite revoked');
    });
  }

  Future<void> _onMemberAction(
    Member member,
    MemberAction action, {
    required bool isSelf,
    required String companyName,
  }) async {
    final actions = ref.read(membersActionsProvider);
    switch (action) {
      case MemberAction.makeOwner:
        final ok = await _confirm(
          title: 'Make ${member.displayName} an owner?',
          message:
              'Owners can create loans and rollovers, reverse payments and '
              'manage members and invites.',
          confirmLabel: 'Make owner',
        );
        if (!ok || !mounted) return;
        await _guarded(
          'member_${member.uid}',
          () => actions.changeRole(member.uid, Role.owner),
        );
      case MemberAction.makeCollector:
        final ok = await _confirm(
          title: isSelf
              ? 'Make yourself a collector?'
              : 'Make ${member.displayName} a collector?',
          message: isSelf
              ? "You'll lose owner rights in $companyName. Another owner can "
                    'give them back.'
              : "Collectors can view dues and record payments. They can't "
                    'create loans or rollovers.',
          confirmLabel: 'Make collector',
        );
        if (!ok || !mounted) return;
        await _guarded(
          'member_${member.uid}',
          () => actions.changeRole(member.uid, Role.collector),
        );
      case MemberAction.remove:
        final ok = await _confirm(
          title: isSelf
              ? 'Leave $companyName?'
              : 'Remove ${member.displayName}?',
          message: isSelf
              ? "You'll lose access to $companyName on this device."
              : '${member.displayName} will lose access to $companyName on '
                    'their next sync. Their recorded payments stay in the '
                    'ledger.',
          confirmLabel: isSelf ? 'Leave' : 'Remove',
          destructive: true,
        );
        if (!ok || !mounted) return;
        await _guarded('member_${member.uid}', () async {
          await actions.removeMember(member.uid);
          if (mounted && !isSelf) _snack('${member.displayName} removed');
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyName = ref.watch(activeCompanyNameProvider) ?? '';
    final isOwner = ref.watch(currentRoleProvider) == Role.owner;
    final window = WindowSize.of(context);
    final twoColumns = isOwner && window.isExpanded;

    final lists = _Lists(
      isOwner: isOwner,
      busy: _busy,
      onResend: _resend,
      onRevoke: _revoke,
      onMemberAction: (Member m, MemberAction a, bool isSelf) => unawaited(
        _onMemberAction(m, a, isSelf: isSelf, companyName: companyName),
      ),
    );

    final Widget content;
    if (twoColumns) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Expanded(
            flex: 5,
            child: Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg),
              child: InviteFormCard(),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(flex: 7, child: lists),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (isOwner) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const InviteFormCard(),
          ],
          lists,
        ],
      );
    }

    return Scaffold(
      key: const ValueKey<String>('members_screen'),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Members'),
            if (companyName.isNotEmpty)
              Text(
                companyName,
                style: AppTextStyles.bodySm,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            window.margin,
            0,
            window.margin,
            AppSpacing.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: WindowSize.maxContentWidth,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pending invites (owners) + members.
class _Lists extends ConsumerWidget {
  const _Lists({
    required this.isOwner,
    required this.busy,
    required this.onResend,
    required this.onRevoke,
    required this.onMemberAction,
  });

  final bool isOwner;
  final Set<String> busy;
  final ValueChanged<Invite> onResend;
  final ValueChanged<Invite> onRevoke;
  final void Function(Member member, MemberAction action, bool isSelf)
  onMemberAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final owners = ref.watch(activeOwnerUidsProvider);
    final members = ref.watch(companyMembersProvider);
    final now = ref.watch(clockProvider).nowIst().toUtc();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (isOwner) ..._pending(ref, now),
        ...members.when(
          data: (List<Member> list) => <Widget>[
            SectionHeader(title: 'Members (${list.length})'),
            for (final m in list) ...<Widget>[
              MemberTile(
                member: m,
                isSelf: m.uid == uid,
                canManage: isOwner,
                isLastOwner: LastOwnerGuard.isLastOwner(
                  _ownerUids(owners, list),
                  m.uid,
                ),
                busy: busy.contains('member_${m.uid}'),
                onAction: (MemberAction a) =>
                    onMemberAction(m, a, m.uid == uid),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (!isOwner) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Only owners can invite staff or change roles.',
                style: AppTextStyles.bodySm,
              ),
            ],
          ],
          loading: () => const <Widget>[
            SectionHeader(title: 'Members'),
            Center(child: CircularProgressIndicator()),
          ],
          error: (Object e, StackTrace _) => <Widget>[
            const SectionHeader(title: 'Members'),
            Text(
              mapFirebaseException(e).userMessage,
              style: AppTextStyles.bodyMd,
            ),
          ],
        ),
      ],
    );
  }

  /// The company's ownerUids; before the company doc loads, the owners in
  /// the member list.
  static List<String> _ownerUids(List<String> owners, List<Member> list) =>
      owners.isNotEmpty
      ? owners
      : <String>[
          for (final m in list)
            if (m.role == Role.owner) m.uid,
        ];

  List<Widget> _pending(WidgetRef ref, DateTime now) {
    final invites = ref.watch(pendingInvitesProvider);
    return invites.when(
      data: (List<Invite> list) => <Widget>[
        SectionHeader(title: 'Pending invites (${list.length})'),
        if (list.isEmpty)
          const Text(
            'No pending invites. Codes you send show here until they are '
            'used, revoked or expire.',
            key: ValueKey<String>('no_pending_invites'),
            style: AppTextStyles.bodySm,
          ),
        for (final inv in list) ...<Widget>[
          PendingInviteTile(
            invite: inv,
            now: now,
            busy: busy.contains('invite_${inv.id}'),
            onResend: () => onResend(inv),
            onRevoke: () => onRevoke(inv),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
      loading: () => const <Widget>[
        SectionHeader(title: 'Pending invites'),
        Center(child: CircularProgressIndicator()),
      ],
      error: (Object e, StackTrace _) => <Widget>[
        const SectionHeader(title: 'Pending invites'),
        const Text(
          "Pending invites can't be loaded right now.",
          style: AppTextStyles.bodySm,
        ),
      ],
    );
  }
}
