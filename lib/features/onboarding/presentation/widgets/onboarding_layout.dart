import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';

/// Register / join shell: a scrollable centred column (max 560dp) with a
/// sticky [footer] (primary action) pinned to the bottom edge. Shows a back
/// button when the screen was pushed (e.g. "Join another company").
class OnboardingLayout extends StatelessWidget {
  const OnboardingLayout({
    required this.children,
    required this.footer,
    super.key,
  });

  final List<Widget> children;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final margin = WindowSize.of(context).margin;
    final canPop = GoRouter.maybeOf(context)?.canPop() ?? false;
    Widget constrained(Widget child) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSizes.onboardingMaxWidth,
        ),
        child: child,
      ),
    );

    return Scaffold(
      appBar: canPop ? AppBar(leading: const BackButton()) : null,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: margin,
                  vertical: AppSpacing.lg,
                ),
                child: constrained(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: margin,
                  vertical: AppSpacing.md,
                ),
                child: constrained(footer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
