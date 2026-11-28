import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'domain/ledger/notification_plan.dart';
import 'features/auth/application/lock_controller.dart';
import 'features/company/application/company_providers.dart';
import 'features/contracts/application/onboarding_resumer.dart';
import 'features/notifications/application/notification_providers.dart';
import 'features/onboarding/application/onboarding_providers.dart';

/// Shown when a tapped notification belongs to another company.
const String otherCompanyLinkMessage =
    'That reminder is for another company. Switch company to see it.';

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

  /// Opens the pending notification deep link on top of the shell, so Back
  /// returns to the dashboard.
  void _openDeepLink() {
    final tagged = ref.read(pendingDeepLinkProvider.notifier).consume();
    if (tagged == null) return;
    // A notification planned for another company (still in the tray from
    // before a switch) is dropped, never opened inside the active one.
    final planned = AppRoutes.companyOf(tagged);
    final active = ref.read(activeCompanyIdProvider).value;
    if (planned != null && planned != active) {
      ref.read(companyNoticeProvider.notifier).show(otherCompanyLinkMessage);
      return;
    }
    final link = AppRoutes.withoutCompany(tagged);
    final router = ref.read(appRouterProvider);
    if (link.startsWith(AppRoutes.home)) {
      router.go(link);
    } else {
      router.go(AppRoutes.home);
      unawaited(router.push<void>(link));
    }
  }

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
      // Local notifications: plugin + tap wiring, and the re-planner. Listened
      // (not watched), so a new plan never rebuilds the app.
      ..listen<AsyncValue<void>>(notificationBootstrapProvider, (_, _) {})
      ..listen<List<PlannedNotification>?>(
        collectionNotificationSchedulerProvider,
        (_, _) {},
      )
      // A notification deep link opens once unlocked with a company.
      ..listen<String?>(readyDeepLinkProvider, (_, String? link) {
        if (link != null) scheduleMicrotask(_openDeepLink);
      })
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
