import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/lock_controller.dart';
import 'features/company/application/company_providers.dart';
import 'features/contracts/application/onboarding_resumer.dart';
import 'features/onboarding/application/onboarding_providers.dart';

/// Root widget: go_router driven by the session [AuthStage] and the company
/// gate.
class App extends ConsumerStatefulWidget {
  const App({super.key});

  static const Locale locale = Locale('en', 'IN');

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final GlobalKey<ScaffoldMessengerState> _messenger =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    // Start the auto-lock lifecycle listener, removed-member handling and
    // the one-time install-referrer read, and the onboarding resumer.
    ref
      ..watch(lockControllerProvider)
      ..watch(companyAccessGuardProvider)
      ..watch(installReferrerBootstrapProvider)
      // Finishes onboarding sync lists (owners) on change and app resume.
      ..watch(onboardingAutoResumeProvider)
      ..listen<String?>(companyNoticeProvider, (_, String? message) {
        if (message == null) return;
        _messenger.currentState?.showSnackBar(
          SnackBar(
            key: const ValueKey<String>('company_notice'),
            content: Text(message),
          ),
        );
        ref.read(companyNoticeProvider.notifier).consume();
      });
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Nordic Ledger',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      locale: App.locale,
      supportedLocales: const <Locale>[App.locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    );
  }
}
