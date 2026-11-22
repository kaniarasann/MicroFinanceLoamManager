import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/validation/onboarding_validators.dart';

/// Uppercases, drops spaces / dashes / punctuation and caps at 6 characters.
/// Letters outside the invite alphabet (0, O, 1, I, L) are kept so the
/// screen can explain the mistake instead of silently eating keys.
class InviteCodeInputFormatter extends TextInputFormatter {
  const InviteCodeInputFormatter();

  static String normalize(String input) {
    final cleaned = input.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    return cleaned.length > InviteCode.length
        ? cleaned.substring(0, InviteCode.length)
        : cleaned;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = normalize(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Six character boxes over one invisible text field, so typing, the
/// keyboard's paste and autofill all work. Tap anywhere to focus.
class InviteCodeBoxes extends StatefulWidget {
  const InviteCodeBoxes({
    required this.controller,
    required this.onChanged,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool hasError;
  final bool enabled;
  final bool autofocus;

  @override
  State<InviteCodeBoxes> createState() => _InviteCodeBoxesState();
}

class _InviteCodeBoxesState extends State<InviteCodeBoxes> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_rebuild);
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(InviteCodeBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return Semantics(
      label: 'Invite code, ${code.length} of ${InviteCode.length} characters',
      child: Stack(
        children: <Widget>[
          IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (var i = 0; i < InviteCode.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: _Box(
                      index: i,
                      char: i < code.length ? code[i] : '',
                      active:
                          _focus.hasFocus &&
                          (i == code.length ||
                              (i == InviteCode.length - 1 &&
                                  code.length == InviteCode.length)),
                      error: widget.hasError,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                key: const ValueKey<String>('invite_code_field'),
                controller: widget.controller,
                focusNode: _focus,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                showCursor: false,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.visiblePassword,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: const <TextInputFormatter>[
                  InviteCodeInputFormatter(),
                ],
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  counterText: '',
                ),
                onChanged: widget.onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.index,
    required this.char,
    required this.active,
    required this.error,
  });

  final int index;
  final String char;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final borderColor = error
        ? AppColors.overdue
        : active
        ? AppColors.borderFocus
        : AppColors.border;
    return Container(
      key: ValueKey<String>('invite_code_box_$index'),
      constraints: const BoxConstraints(maxWidth: AppSizes.codeBoxWidth),
      height: AppSizes.codeBoxHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.baseAll,
        border: Border.all(
          color: borderColor,
          width: active ? AppSizes.borderWidth * 2 : AppSizes.borderWidth,
        ),
      ),
      child: Text(
        char,
        style: AppTextStyles.headlineSmTabular,
        textAlign: TextAlign.center,
      ),
    );
  }
}
