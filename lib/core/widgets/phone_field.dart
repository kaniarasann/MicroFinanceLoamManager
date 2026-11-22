import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../phone/indian_phone.dart';
import '../theme/app_theme.dart';

/// +91 mobile input: fixed `+91` prefix, digits grouped `98450 12890`,
/// tabular figures. Validates to a 10-digit Indian mobile; empty is allowed
/// unless [required].
class PhoneField extends StatelessWidget {
  const PhoneField({
    required this.controller,
    required this.label,
    this.required = false,
    this.textInputAction = TextInputAction.next,
    this.fieldKey,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final TextInputAction textInputAction;
  final Key? fieldKey;

  /// Validator used by the field (exposed for tests).
  static String? validate(String? value, {required bool required}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Enter a mobile number.' : null;
    return IndianPhone.toE164(v) == null ? IndianPhone.invalidMessage : null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      autofillHints: const <String>[AutofillHints.telephoneNumberNational],
      style: AppTextStyles.bodyLgTabular,
      inputFormatters: const <TextInputFormatter>[IndianMobileInputFormatter()],
      decoration: InputDecoration(
        labelText: label,
        hintText: '98450 12890',
        prefixText: '${IndianPhone.countryCode} ',
        prefixStyle: AppTextStyles.bodyLgTabular.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      validator: (String? v) => validate(v, required: required),
    );
  }
}
