import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../application/session_controller.dart';
import '../widgets/auth_layout.dart';
import '../widgets/device_only_note.dart';
import '../widgets/google_g_mark.dart';
import '../widgets/inline_error.dart';

/// Google sign-in.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(sessionControllerProvider.notifier).signInWithGoogle();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final message = ref.watch(
      sessionControllerProvider.select((SessionState s) => s.message),
    );
    return AuthLayout(
      footer: const DeviceOnlyNote(showLinks: true),
      child: Column(
        children: <Widget>[
          const BrandMark(),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Nordic Ledger',
            style: AppTextStyles.headlineXl,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Lending ledger for your business',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey<String>('google_sign_in'),
              onPressed: _busy ? null : _signIn,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: AppSizes.googleMark,
                      child: CircularProgressIndicator(
                        strokeWidth: AppSpacing.xxs,
                      ),
                    )
                  : const GoogleGMark(),
              label: const Text('Continue with Google'),
            ),
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            InlineError(message: message),
          ],
        ],
      ),
    );
  }
}
