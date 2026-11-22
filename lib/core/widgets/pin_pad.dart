import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 4-dot MPIN entry with a 3×4 keypad of circular 64dp keys.
///
/// Bottom row: optional biometric key (collected tint), 0, backspace.
/// [onCompleted] fires once [length] digits are entered; the pad then
/// clears itself for the next attempt.
class PinPad extends StatefulWidget {
  const PinPad({
    required this.onCompleted,
    this.length = 4,
    this.onBiometric,
    this.biometricIcon = Icons.fingerprint,
    this.biometricLabel = 'Unlock with biometrics',
    this.enabled = true,
    super.key,
  });

  final ValueChanged<String> onCompleted;
  final int length;

  /// When non-null, shows the biometric key bottom-left.
  final VoidCallback? onBiometric;
  final IconData biometricIcon;
  final String biometricLabel;
  final bool enabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';

  void _onDigit(String digit) {
    if (!widget.enabled || _pin.length >= widget.length) return;
    final next = _pin + digit;
    if (next.length == widget.length) {
      setState(() => _pin = '');
      widget.onCompleted(next);
    } else {
      setState(() => _pin = next);
    }
  }

  void _onBackspace() {
    if (!widget.enabled || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    Widget digit(String d) => _PinKey(
      key: ValueKey<String>('pin_key_$d'),
      semanticLabel: d,
      onTap: () => _onDigit(d),
      child: Text(d, style: AppTextStyles.headlineLgTabular),
    );

    final biometric = widget.onBiometric == null
        ? const SizedBox(width: AppSizes.pinKey, height: AppSizes.pinKey)
        : _PinKey(
            key: const ValueKey<String>('pin_biometric'),
            semanticLabel: widget.biometricLabel,
            color: AppColors.collectedTint,
            bordered: false,
            onTap: widget.enabled ? widget.onBiometric! : () {},
            child: Icon(
              widget.biometricIcon,
              color: AppColors.collected,
              size: AppSizes.iconLg,
            ),
          );

    final backspace = _PinKey(
      key: const ValueKey<String>('pin_backspace'),
      semanticLabel: 'Delete',
      color: AppColors.transparent,
      bordered: false,
      onTap: _onBackspace,
      child: const Icon(
        Icons.backspace_outlined,
        color: AppColors.textSecondary,
        size: AppSizes.iconMd,
      ),
    );

    Widget row(List<Widget> keys) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          keys[0],
          const SizedBox(width: AppSpacing.lg),
          keys[1],
          const SizedBox(width: AppSpacing.lg),
          keys[2],
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          label: '${_pin.length} of ${widget.length} digits entered',
          liveRegion: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var i = 0; i < widget.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                _PinDot(filled: i < _pin.length, index: i),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        row(<Widget>[digit('1'), digit('2'), digit('3')]),
        row(<Widget>[digit('4'), digit('5'), digit('6')]),
        row(<Widget>[digit('7'), digit('8'), digit('9')]),
        row(<Widget>[biometric, digit('0'), backspace]),
      ],
    );
  }
}

class _PinDot extends StatelessWidget {
  const _PinDot({required this.filled, required this.index});

  final bool filled;
  final int index;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: ValueKey<String>('pin_dot_${index}_${filled ? 'on' : 'off'}'),
      duration: const Duration(milliseconds: 120),
      width: AppSizes.pinDot,
      height: AppSizes.pinDot,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.primary : AppColors.surface,
        border: Border.all(
          color: filled ? AppColors.primary : AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    required this.onTap,
    required this.child,
    required this.semanticLabel,
    this.color = AppColors.surface,
    this.bordered = true,
    super.key,
  });

  final VoidCallback onTap;
  final Widget child;
  final String semanticLabel;
  final Color color;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: AppSizes.pinKey,
        height: AppSizes.pinKey,
        child: Material(
          color: color,
          shape: CircleBorder(
            side: bordered
                ? const BorderSide(color: AppColors.border)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            highlightColor: AppColors.pressed,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
