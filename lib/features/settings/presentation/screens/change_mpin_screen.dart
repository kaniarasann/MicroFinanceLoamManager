import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pin_pad.dart';
import '../../../auth/application/session_controller.dart';
import '../../../auth/presentation/screens/mpin_setup_screen.dart';
import '../../../auth/presentation/widgets/device_only_note.dart';
import '../../../auth/presentation/widgets/inline_error.dart';
import '../../../auth/presentation/widgets/shake.dart';

enum _Step { current, enter, confirm }

/// Settings → Change MPIN: current MPIN → new MPIN → confirm.
///
/// Wrong current MPINs count towards the same 5-try lockout as the unlock
/// screen (the 5th signs out and forces Google re-auth). A new MPIN equal
/// to the current one is refused.
class ChangeMpinScreen extends ConsumerStatefulWidget {
  const ChangeMpinScreen({super.key});

  static const String sameAsOldMessage =
      'Choose an MPIN different from your current one.';
  static const String changedMessage = 'MPIN changed';

  /// "Wrong MPIN. 3 tries left."
  static String wrongMessage(int remaining) =>
      'Wrong MPIN. $remaining ${remaining == 1 ? 'try' : 'tries'} left.';

  @override
  ConsumerState<ChangeMpinScreen> createState() => _ChangeMpinScreenState();
}

class _ChangeMpinScreenState extends ConsumerState<ChangeMpinScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  _Step _step = _Step.current;
  String? _current;
  String? _first;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _fail(String message, _Step step) {
    setState(() {
      _error = message;
      _step = step;
      _busy = false;
      if (step != _Step.confirm) _first = null;
    });
    unawaited(HapticFeedback.mediumImpact());
    _shake.forward(from: 0);
  }

  Future<void> _onCurrent(String pin) async {
    setState(() => _busy = true);
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .verifyCurrentMpin(pin);
    if (!mounted) return;
    if (result.ok) {
      setState(() {
        _current = pin;
        _busy = false;
        _error = null;
        _step = _Step.enter;
      });
    } else if (!result.lockedOut) {
      _fail(ChangeMpinScreen.wrongMessage(result.remaining), _Step.current);
    }
    // Locked out: the session is signed out and the router leaves.
  }

  void _onEntered(String pin) {
    if (pin == _current) {
      _fail(ChangeMpinScreen.sameAsOldMessage, _Step.enter);
      return;
    }
    setState(() {
      _first = pin;
      _error = null;
      _step = _Step.confirm;
    });
  }

  Future<void> _onConfirmed(String pin) async {
    if (pin != _first) {
      _fail(MpinSetupScreen.mismatchMessage, _Step.enter);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(sessionControllerProvider.notifier).changeMpin(pin);
    } on Object {
      if (!mounted) return;
      _fail("Couldn't save your MPIN. Please try again.", _Step.enter);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: ValueKey<String>('mpin_changed'),
        content: Text(ChangeMpinScreen.changedMessage),
      ),
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (String title, String subtitle) = switch (_step) {
      _Step.current => (
        'Enter your current MPIN',
        'To keep your ledger safe, confirm it is you.',
      ),
      _Step.enter => ('Choose a new MPIN', '4 digits you will remember.'),
      _Step.confirm => ('Confirm new MPIN', 'Enter the same 4 digits again.'),
    };
    final onCompleted = switch (_step) {
      _Step.current => (String p) => unawaited(_onCurrent(p)),
      _Step.enter => _onEntered,
      _Step.confirm => (String p) => unawaited(_onConfirmed(p)),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Change MPIN')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.authContentMaxWidth,
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    title,
                    key: const ValueKey<String>('change_mpin_title'),
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
                  Shake(
                    animation: _shake,
                    child: PinPad(
                      key: ValueKey<_Step>(_step),
                      length: AppConfig.mpinLength,
                      enabled: !_busy,
                      onCompleted: onCompleted,
                    ),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    InlineError(message: _error!),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  const DeviceOnlyNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
