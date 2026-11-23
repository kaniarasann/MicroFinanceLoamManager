import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../contracts/application/contract_providers.dart';
import '../../../contracts/application/loan_label.dart';

/// "Rolled over → Loan #M" (on the old contract) or "Rolled over from
/// Loan #K" (on the new one). Tapping opens the linked contract.
class RolloverLinkBanner extends ConsumerWidget {
  const RolloverLinkBanner({
    required this.linkedContractId,
    required this.forward,
    super.key,
  });

  final String linkedContractId;

  /// True on the old contract (points to its successor).
  final bool forward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked = ref.watch(contractDocProvider(linkedContractId)).value;
    final loan = linked == null ? 'another loan' : loanLabel(linked.loanNo);
    final text = forward ? 'Rolled over → $loan' : 'Rolled over from $loan';
    return Material(
      color: AppColors.primarySubtle,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      child: InkWell(
        key: ValueKey<String>(forward ? 'rolled_over_to' : 'rolled_over_from'),
        customBorder: const RoundedRectangleBorder(
          borderRadius: AppRadii.mdAll,
        ),
        onTap: () =>
            unawaited(context.push<void>(AppRoutes.contract(linkedContractId))),
        child: Padding(
          padding: AppInsets.cardCompact,
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.autorenew,
                size: AppSizes.iconMd,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.labelLgTabular.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
