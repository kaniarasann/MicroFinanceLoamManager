import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/time/clock_provider.dart';
import '../../../../core/validation/onboarding_validators.dart';
import '../../../auth/presentation/widgets/inline_error.dart';
import '../../../company/application/company_providers.dart';
import '../../application/onboarding_providers.dart';
import '../../data/invite_repository.dart';
import '../widgets/account_chip.dart';
import '../widgets/invite_code_boxes.dart';
import '../widgets/invite_preview_card.dart';
import '../widgets/onboarding_layout.dart';

/// Copy for each join failure.
abstract final class JoinCopy {
  static const String invalidChars =
      "That isn't a valid code. Codes never use 0, O, 1, I or L.";
  static const String notFound =
      "We couldn't find that invite. Check the code and try again.";
  static const String expired =
      'This invite has expired. Ask the owner to send a new one.';
  static const String unavailable =
      'This invite was already used or was revoked. Ask the owner for a '
      'new code.';
  static const String offline =
      "You're offline. An internet connection is needed to join.";
  static const String clipboardEmpty = 'No invite code found on the clipboard.';

  static String forFailure(AppFailure f) => switch (f) {
    NotFoundFailure() => notFound,
    ValidationFailure() => invalidChars,
    ExpiredFailure() => expired,
    InviteUnavailableFailure() => unavailable,
    OfflineRequiredFailure() => offline,
    PermissionDeniedFailure() => notFound,
    UnknownFailure() => f.userMessage,
  };
}

/// "0b. Join with Invite Code": 6-box code entry → online lookup → preview
/// → accept (online transaction).
class JoinCompanyScreen extends ConsumerStatefulWidget {
  const JoinCompanyScreen({this.initialCode, super.key});

  /// Pre-fill from `/join?code=` or the Play install referrer.
  final String? initialCode;

  @override
  ConsumerState<JoinCompanyScreen> createState() => _JoinCompanyScreenState();
}

class _JoinCompanyScreenState extends ConsumerState<JoinCompanyScreen> {
  final TextEditingController _code = TextEditingController();

  InvitePreview? _preview;
  String? _error;
  bool _looking = false;
  bool _joining = false;
  int _lookupSeq = 0;

  @override
  void initState() {
    super.initState();
    final fromRoute = InviteCodeInputFormatter.normalize(
      widget.initialCode ?? '',
    );
    if (fromRoute.isNotEmpty) _code.text = fromRoute;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Consume any pending deep-link / referrer code (after build: it
      // modifies a provider).
      final pending = ref.read(pendingInviteCodeProvider.notifier).take();
      final initial = fromRoute.isNotEmpty
          ? fromRoute
          : InviteCodeInputFormatter.normalize(pending ?? '');
      if (initial.isEmpty) return;
      if (_code.text != initial) _code.text = initial;
      _onChanged(initial);
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _onChanged(String code) {
    if (!mounted) return;
    final seq = ++_lookupSeq;
    setState(() {
      _preview = null;
      _error = null;
    });
    if (code.length < InviteCode.length) return;
    if (!InviteCode.isValid(code)) {
      setState(() => _error = JoinCopy.invalidChars);
      return;
    }
    unawaited(_lookup(code, seq));
  }

  Future<void> _lookup(String code, int seq) async {
    setState(() => _looking = true);
    try {
      final preview = await ref.read(companyActionsProvider).lookupInvite(code);
      if (!mounted || seq != _lookupSeq) return;
      setState(() => _preview = preview);
    } on AppFailure catch (f) {
      if (!mounted || seq != _lookupSeq) return;
      setState(() => _error = JoinCopy.forFailure(f));
    } finally {
      if (mounted && seq == _lookupSeq) setState(() => _looking = false);
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final code = InviteCodeInputFormatter.normalize(
      _extractCode(data?.text ?? ''),
    );
    if (code.isEmpty) {
      setState(() => _error = JoinCopy.clipboardEmpty);
      return;
    }
    _code.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    _onChanged(code);
  }

  /// A pasted WhatsApp/SMS message: prefer "code: XXXXXX" / "code=XXXXXX".
  static String _extractCode(String text) {
    final match = RegExp(
      r'code[\s:=]*([A-Za-z0-9]{6})\b',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1) ?? text.trim();
  }

  Future<void> _join() async {
    final preview = _preview;
    if (preview == null || _joining) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      await ref.read(companyActionsProvider).acceptInvite(preview.code);
      if (!mounted) return;
      context.go(AppRoutes.home);
    } on AppFailure catch (f) {
      if (!mounted) return;
      setState(() {
        _error = JoinCopy.forFailure(f);
        if (f is! OfflineRequiredFailure) _preview = null;
      });
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final now = ref.watch(clockProvider).nowIst();
    return OnboardingLayout(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FilledButton(
            key: const ValueKey<String>('join_submit'),
            onPressed: preview == null || _joining ? null : _join,
            child: _joining
                ? const SizedBox.square(
                    dimension: AppSizes.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    preview == null
                        ? 'Join company'
                        : 'Join ${preview.companyName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const ValueKey<String>('join_register_instead'),
            onPressed: _joining
                ? null
                : () => context.go(AppRoutes.onboardingRegister),
            child: const Text('Register a new company instead'),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.wifi,
                size: AppSizes.iconSm,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'An internet connection is needed to join.',
                  style: AppTextStyles.bodySm,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
      children: <Widget>[
        const AccountChip(),
        const SizedBox(height: AppSpacing.lg),
        const Text('Join your company', style: AppTextStyles.headlineXl),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Enter the 6-character invite code your owner sent you by SMS or '
          'WhatsApp.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        InviteCodeBoxes(
          controller: _code,
          onChanged: _onChanged,
          hasError: _error != null,
          enabled: !_joining,
          autofocus: widget.initialCode == null,
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          child: TextButton.icon(
            key: const ValueKey<String>('join_paste'),
            onPressed: _joining ? null : _paste,
            icon: const Icon(Icons.content_paste, size: AppSizes.iconSm),
            label: const Text('Paste from clipboard'),
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          InlineError(message: _error!),
        ],
        if (_looking) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          const Center(child: CircularProgressIndicator()),
        ],
        if (preview != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          InvitePreviewCard(preview: preview, now: now),
        ],
      ],
    );
  }
}
