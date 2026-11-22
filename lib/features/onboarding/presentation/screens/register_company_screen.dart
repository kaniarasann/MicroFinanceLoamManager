import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validation/onboarding_validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/phone_field.dart';
import '../../../auth/application/session_controller.dart';
import '../../../auth/presentation/widgets/inline_error.dart';
import '../../../company/application/company_providers.dart';
import '../widgets/account_chip.dart';
import '../widgets/onboarding_layout.dart';

/// "0. Register Your Company": creates the company with the user as owner.
class RegisterCompanyScreen extends ConsumerStatefulWidget {
  const RegisterCompanyScreen({super.key});

  @override
  ConsumerState<RegisterCompanyScreen> createState() =>
      _RegisterCompanyScreenState();
}

class _RegisterCompanyScreenState extends ConsumerState<RegisterCompanyScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  late final TextEditingController _displayName = TextEditingController(
    text: ref.read(sessionControllerProvider).user?.displayName ?? '',
  );
  final TextEditingController _mobile = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _phone.dispose();
    _displayName.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(companyActionsProvider)
          .registerCompany(
            name: _name.text,
            city: _city.text,
            phone: _phone.text,
            ownerDisplayName: _displayName.text,
            ownerPhone: _mobile.text,
          );
      if (!mounted) return;
      context.go(AppRoutes.home);
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_error != null) ...<Widget>[
            InlineError(message: _error!),
            const SizedBox(height: AppSpacing.sm),
          ],
          FilledButton(
            key: const ValueKey<String>('register_submit'),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: AppSizes.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create company & continue'),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'By continuing you agree to the Terms of Service and '
            'Privacy Policy.',
            style: AppTextStyles.bodySm,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      children: <Widget>[
        const AccountChip(),
        const SizedBox(height: AppSpacing.lg),
        const Text('Register your company', style: AppTextStyles.headlineXl),
        const SizedBox(height: AppSpacing.xs),
        Text(
          "Set up your lending business. You'll be its owner and can invite "
          'your staff next.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text('Company details', style: AppTextStyles.titleMd),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const ValueKey<String>('register_name'),
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      maxLength: OnboardingValidators.companyNameMax,
                      decoration: const InputDecoration(
                        labelText: 'Company name',
                        hintText: 'e.g. Sri Lakshmi Finance',
                        counterText: '',
                      ),
                      validator: OnboardingValidators.companyName,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const ValueKey<String>('register_city'),
                      controller: _city,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'City (optional)',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PhoneField(
                      fieldKey: const ValueKey<String>('register_phone'),
                      controller: _phone,
                      label: 'Business phone (optional)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text('Your profile', style: AppTextStyles.titleMd),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const ValueKey<String>('register_display_name'),
                      controller: _displayName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Your name'),
                      validator: OnboardingValidators.displayName,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PhoneField(
                      fieldKey: const ValueKey<String>('register_mobile'),
                      controller: _mobile,
                      label: 'Mobile number',
                      required: true,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _OwnerRightsCard(),
        const SizedBox(height: AppSpacing.sm),
        Align(
          child: TextButton(
            key: const ValueKey<String>('register_join_link'),
            onPressed: _busy
                ? null
                : () => context.go(AppRoutes.onboardingJoin),
            child: const Text(
              'Have an invite code? Join an existing company →',
            ),
          ),
        ),
      ],
    );
  }
}

class _OwnerRightsCard extends StatelessWidget {
  const _OwnerRightsCard();

  @override
  Widget build(BuildContext context) {
    Widget line(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.check_circle_outline,
            size: AppSizes.iconSm,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.bodyMd)),
        ],
      ),
    );

    return Container(
      key: const ValueKey<String>('owner_rights'),
      padding: AppInsets.cardCompact,
      decoration: const BoxDecoration(
        color: AppColors.primarySubtle,
        borderRadius: AppRadii.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.verified_user_outlined,
                size: AppSizes.iconSm,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'You will be the owner',
                style: AppTextStyles.labelLg.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          line('Create loans, rollovers and manage the ledger'),
          line(
            'Invite staff by SMS or WhatsApp and assign roles '
            '(Owner / Collector)',
          ),
        ],
      ),
    );
  }
}
