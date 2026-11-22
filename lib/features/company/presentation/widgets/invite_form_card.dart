import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/phone/indian_phone.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validation/onboarding_validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/phone_field.dart';
import '../../../../core/widgets/segmented_toggle.dart';
import '../../../../domain/models/models.dart';
import '../../application/invite_message.dart';
import '../../application/members_providers.dart';
import '../invite_sender.dart';
import 'invite_message_card.dart';
import 'invite_send_buttons.dart';

/// One-line description under the role toggle.
String inviteRoleDescription(Role role) => switch (role) {
  Role.collector =>
    "Collectors can view dues and record payments. They can't create loans "
        'or rollovers.',
  Role.owner =>
    'Owners can do everything, including loans, rollovers and managing '
        'members.',
};

/// Owner-only "Invite a staff member" card: name, +91 mobile, role, the
/// send buttons and, once created, the message preview.
///
/// The first send creates the invite (online). Later sends reuse it until
/// the name, mobile or role changes.
class InviteFormCard extends ConsumerStatefulWidget {
  const InviteFormCard({super.key});

  @override
  ConsumerState<InviteFormCard> createState() => _InviteFormCardState();
}

class _InviteFormCardState extends ConsumerState<InviteFormCard> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  Role _role = Role.collector;
  InviteChannel? _busy;
  Invite? _created;
  String? _createdFor;

  String get _fingerprint =>
      '${_name.text.trim()}|${IndianPhone.toE164(_phone.text)}|${_role.name}';

  @override
  void initState() {
    super.initState();
    _name.addListener(_onEdited);
    _phone.addListener(_onEdited);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _onEdited() {
    if (_created != null && _createdFor != _fingerprint) {
      setState(() {
        _created = null;
        _createdFor = null;
      });
    }
  }

  void _setRole(Role role) {
    setState(() => _role = role);
    _onEdited();
  }

  Future<void> _send(InviteChannel channel) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = channel);
    try {
      var invite = _created;
      if (invite == null || _createdFor != _fingerprint) {
        invite = await ref
            .read(membersActionsProvider)
            .createInvite(
              inviteeName: _name.text,
              inviteePhone: _phone.text,
              role: _role,
            );
        if (!mounted) return;
        setState(() {
          _created = invite;
          _createdFor = _fingerprint;
        });
      }
      await sendInvite(context, ref, invite, channel);
    } on AppFailure catch (f) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(f.userMessage)));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _reset() {
    _formKey.currentState?.reset();
    _name.clear();
    _phone.clear();
    setState(() {
      _role = Role.collector;
      _created = null;
      _createdFor = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    return AppCard(
      key: const ValueKey<String>('invite_form_card'),
      padding: AppCardPadding.spacious,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: const Text(
                'Invite a staff member',
                style: AppTextStyles.headlineSm,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'They get a code to join from their own phone.',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey<String>('invite_name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: OnboardingValidators.inviteeName,
            ),
            const SizedBox(height: AppSpacing.md),
            PhoneField(
              fieldKey: const ValueKey<String>('invite_phone'),
              controller: _phone,
              label: 'Mobile',
              required: true,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Role', style: AppTextStyles.labelMd),
            const SizedBox(height: AppSpacing.sm),
            SegmentedToggle<Role>(
              key: const ValueKey<String>('invite_role'),
              expand: true,
              segments: const <ToggleSegment<Role>>[
                ToggleSegment<Role>(value: Role.collector, label: 'Collector'),
                ToggleSegment<Role>(value: Role.owner, label: 'Owner'),
              ],
              selected: _role,
              onChanged: _setRole,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              inviteRoleDescription(_role),
              key: const ValueKey<String>('invite_role_description'),
              style: AppTextStyles.bodySm,
            ),
            const SizedBox(height: AppSpacing.lg),
            InviteSendButtons(onSend: _send, busy: _busy),
            const SizedBox(height: AppSpacing.xs),
            const Row(
              children: <Widget>[
                Icon(
                  Icons.wifi_outlined,
                  size: AppSizes.iconSm,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'An internet connection is needed to create invites.',
                    style: AppTextStyles.bodySm,
                  ),
                ),
              ],
            ),
            if (created != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              InviteMessageCard(invite: created),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey<String>('invite_new'),
                  onPressed: _reset,
                  child: const Text('Invite someone else'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
