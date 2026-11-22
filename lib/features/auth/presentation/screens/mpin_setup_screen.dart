import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/pin_pad.dart';
import '../../application/auth_providers.dart';
import '../../application/session_controller.dart';
import '../widgets/auth_layout.dart';
import '../widgets/device_only_note.dart';
import '../widgets/inline_error.dart';
import '../widgets/shake.dart';

enum _Step { enter, confirm, biometric }

/// Create MPIN → confirm → optional fingerprint opt-in.
class MpinSetupScreen extends ConsumerStatefulWidget {
  const MpinSetupScreen({super.key});

  static const String mismatchMessage = "MPINs didn't match. Try again.";

  @override
  ConsumerState<MpinSetupScreen> createState() => _MpinSetupScreenState();
}

class _MpinSetupScreenState extends ConsumerState<MpinSetupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  _Step _step = _Step.enter;
  String? _first;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _onEntered(String pin) {
    setState(() {
      _first = pin;
      _error = null;
      _step = _Step.confirm;
    });
  }

  Future<void> _onConfirmed(String pin) async {
    if (pin != _first) {
      setState(() {
        _first = null;
        _error = MpinSetupScreen.mismatchMessage;
        _step = _Step.enter;
      });
      unawaited(HapticFeedback.mediumImpact());
      _shake.forward(from: 0);
      return;
    }
    setState(() => _busy = true);
    final canUseBiometric = await ref.read(biometricServiceProvider).canCheck();
    if (!mounted) return;
    if (canUseBiometric) {
      setState(() {
        _busy = false;
        _step = _Step.biometric;
      });
    } else {
      await _finish(biometricEnabled: false);
    }
  }

  Future<void> _enableBiometric() async {
    setState(() => _busy = true);
    // Confirm the sensor works before turning it on.
    final ok = await ref.read(biometricServiceProvider).authenticate();
    if (!mounted) return;
    await _finish(biometricEnabled: ok);
  }

  Future<void> _finish({required bool biometricEnabled}) async {
    final pin = _first;
    if (pin == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .completeMpinSetup(pin, biometricEnabled: biometricEnabled);
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _first = null;
        _step = _Step.enter;
        _error = "Couldn't save your MPIN. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final (String title, String subtitle) = switch (_step) {
      _Step.enter => (
        'Create your 4-digit MPIN',
        "You'll use it to unlock Nordic Ledger on this device.",
      ),
      _Step.confirm => ('Confirm MPIN', 'Enter the same 4 digits again.'),
      _Step.biometric => (
        'Use fingerprint to unlock?',
        'You can always use your MPIN instead.',
      ),
    };

    return AuthLayout(
      footer: const DeviceOnlyNote(),
      child: Column(
        children: <Widget>[
          const BrandMark(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            key: const ValueKey<String>('mpin_setup_title'),
            style: AppTextStyles.headlineLg,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_step == _Step.biometric)
            _BiometricChoice(
              busy: _busy,
              onEnable: _enableBiometric,
              onSkip: () => _finish(biometricEnabled: false),
            )
          else
            Shake(
              animation: _shake,
              child: PinPad(
                key: ValueKey<_Step>(_step),
                length: AppConfig.mpinLength,
                enabled: !_busy,
                onCompleted: _step == _Step.enter ? _onEntered : _onConfirmed,
              ),
            ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            InlineError(message: _error!),
          ],
        ],
      ),
    );
  }
}

class _BiometricChoice extends StatelessWidget {
  const _BiometricChoice({
    required this.busy,
    required this.onEnable,
    required this.onSkip,
  });

  final bool busy;
  final VoidCallback onEnable;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: AppSizes.pinKey,
          height: AppSizes.pinKey,
          decoration: const BoxDecoration(
            color: AppColors.collectedTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.fingerprint,
            color: AppColors.collected,
            size: AppSizes.iconLg,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const ValueKey<String>('biometric_enable'),
            onPressed: busy ? null : onEnable,
            child: const Text('Use fingerprint'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            key: const ValueKey<String>('biometric_skip'),
            onPressed: busy ? null : onSkip,
            child: const Text('Not now'),
          ),
        ),
      ],
    );
  }
}
