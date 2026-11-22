import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Shell for sign-in and MPIN screens: a single centred column capped at
/// [AppSizes.authContentMaxWidth] (420dp), scrollable so it survives small
/// heights and 1.3x text, with an optional [footer] pinned below.
class AuthLayout extends StatelessWidget {
  const AuthLayout({required this.child, this.footer, super.key});

  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSpacing.lg * 2,
                ),
                child: Center(
                  child: ConstrainedBox(
                    key: const ValueKey<String>('auth_content'),
                    constraints: const BoxConstraints(
                      maxWidth: AppSizes.authContentMaxWidth,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        child,
                        if (footer != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.xl),
                          footer!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
