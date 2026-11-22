import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/pin_pad.dart';
import '../../../company/application/company_providers.dart';
import '../../../company/presentation/widgets/role_pill.dart';
import '../../application/session_controller.dart';
import '../widgets/auth_layout.dart';
import '../widgets/device_only_note.dart';
import '../widgets/inline_error.dart';
import '../widgets/shake.dart';

/// "Wrong MPIN · 3 tries left" / "Wrong MPIN · 1 try left".
String wrongMpinMessage(int remaining) =>
    'Wrong MPIN · $remaining ${remaining == 1 ? 'try' : 'tries'} left';

/// Lock screen: MPIN pad (+ biometric key when enabled).
class MpinUnlockScreen extends ConsumerStatefulWidget {
  const MpinUnlockScreen({super.key});

  @override
  ConsumerState<MpinUnlockScreen> createState() => _MpinUnlockScreenState();
}

class _MpinUnlockScreenState extends ConsumerState<MpinUnlockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  String? _error;
  bool _busy = false;

  SessionController get _session =>
      ref.read(sessionControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Auto-prompt biometric on open when the user opted in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(sessionControllerProvider).biometricEnabled) {
        unawaited(_biometric());
      }
    });
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _onPin(String pin) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await _session.unlockWithPin(pin);
    if (!mounted) return;
    if (result.ok || result.lockedOut) {
      // The router takes over (home / sign-in).
      setState(() => _busy = false);
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    _shake.forward(from: 0);
    setState(() {
      _busy = false;
      _error = wrongMpinMessage(result.remaining);
    });
  }

  Future<void> _biometric() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _session.unlockWithBiometric();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _forgot() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await _session.forgotMpin();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final firstName = session.user?.firstName;
    final error = _error ?? session.message;
    final companyName = ref.watch(activeCompanyNameProvider);
    final role = ref.watch(currentRoleProvider);
    final companyLine = companyName == null
        ? null
        : role == null
        ? companyName
        : '$companyName · ${roleLabel(role)}';

    return AuthLayout(
      footer: const DeviceOnlyNote(),
      child: Column(
        children: <Widget>[
          const BrandMark(),
          const SizedBox(height: AppSpacing.md),
          Text(
            firstName == null ? 'Welcome back' : 'Welcome back, $firstName',
            style: AppTextStyles.headlineLg,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            companyLine ?? 'Lending ledger for your business',
            key: const ValueKey<String>('mpin_company_line'),
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          Shake(
            animation: _shake,
            child: PinPad(
              length: AppConfig.mpinLength,
              enabled: !_busy,
              onCompleted: _onPin,
              onBiometric: session.biometricEnabled ? _biometric : null,
              biometricLabel: 'Unlock with fingerprint',
            ),
          ),
          if (error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            InlineError(message: error),
          ],
          const SizedBox(height: AppSpacing.md),
          TextButton(
            key: const ValueKey<String>('forgot_mpin'),
            onPressed: _busy ? null : _forgot,
            child: const Text('Forgot MPIN? Sign in with Google again'),
          ),
        ],
      ),
    );
  }
}
