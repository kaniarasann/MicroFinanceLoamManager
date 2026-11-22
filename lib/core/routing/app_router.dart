import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/screens/mpin_setup_screen.dart';
import '../../features/auth/presentation/screens/mpin_unlock_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/company/application/company_providers.dart';
import '../../features/company/presentation/members_screen.dart';
import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../../features/onboarding/application/onboarding_providers.dart';
import '../../features/onboarding/presentation/screens/join_company_screen.dart';
import '../../features/onboarding/presentation/screens/register_company_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/splash/presentation/theme_gallery_screen.dart';
import '../../firebase_options.dart';
import '../validation/onboarding_validators.dart';

part 'app_router.g.dart';

abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String signIn = '/sign-in';
  static const String mpinSetup = '/mpin/setup';
  static const String mpin = '/mpin';
  static const String home = '/home';

  /// Members & invites (Settings is Sprint 8; reached from the Home menu).
  static const String members = '/settings/members';

  /// In-app routes reachable once a company is ready.
  static const Set<String> companyShell = <String>{home, members};

  static const String onboardingRegister = '/onboarding/register';
  static const String onboardingJoin = '/onboarding/join';

  /// Deep link `/join?code=XXXXXX` (`nordicledger://app/join?code=…`).
  static const String joinLink = '/join';

  /// Theme gallery; debug builds only.
  static const String devGallery = '/dev/gallery';

  /// Routes that only make sense before the session is unlocked.
  static const Set<String> gate = <String>{splash, signIn, mpinSetup, mpin};

  static const Set<String> onboarding = <String>{
    onboardingRegister,
    onboardingJoin,
  };

  /// `/onboarding/join`, with `?code=` when [code] is a valid invite code.
  static String joinWithCode(String? code) {
    final c = code?.trim().toUpperCase();
    return c != null && InviteCode.isValid(c)
        ? '$onboardingJoin?code=$c'
        : onboardingJoin;
  }
}

/// Pure redirect rule (unit-tested). Returns the location to go to, or null
/// to stay on [uri].
///
/// 1. Auth stages pin the user to splash / sign-in / MPIN setup / MPIN.
/// 2. Unlocked:
///    - `/join?code=` → `/onboarding/join?code=`;
///    - a [pendingInviteCode] (deep link received while locked, or Play
///      install referrer) → the join screen;
///    - company loading → splash (onboarding screens stay put);
///    - no company → `/onboarding/register` (join is allowed too);
///    - company ready → `/home` for gate / unknown locations. Onboarding
///      stays reachable ("Join another company"); `/dev/gallery` only when
///      [devRoutes].
String? appRedirect({
  required AuthStage stage,
  required CompanyGate company,
  required Uri uri,
  String? pendingInviteCode,
  bool devRoutes = kDebugMode,
}) {
  final path = uri.path;
  final target = switch (stage) {
    AuthStage.loading => AppRoutes.splash,
    AuthStage.signedOut => AppRoutes.signIn,
    AuthStage.needsMpinSetup => AppRoutes.mpinSetup,
    AuthStage.locked => AppRoutes.mpin,
    AuthStage.unlocked => null,
  };
  if (target != null) return path == target ? null : target;

  if (path == AppRoutes.joinLink) {
    return AppRoutes.joinWithCode(uri.queryParameters['code']);
  }
  final onboarding = AppRoutes.onboarding.contains(path);
  if (pendingInviteCode != null && path != AppRoutes.onboardingJoin) {
    return AppRoutes.joinWithCode(pendingInviteCode);
  }
  switch (company) {
    case CompanyGate.loading:
      return onboarding || path == AppRoutes.splash ? null : AppRoutes.splash;
    case CompanyGate.none:
      return onboarding ? null : AppRoutes.onboardingRegister;
    case CompanyGate.ready:
      if (onboarding || AppRoutes.companyShell.contains(path)) return null;
      if (devRoutes && path == AppRoutes.devGallery) return null;
      return AppRoutes.home;
  }
}

/// Auth-only view of [appRedirect] for a user whose company is ready (kept
/// for the Sprint 3 redirect tests).
String? authRedirect(AuthStage stage, String location) => appRedirect(
  stage: stage,
  company: CompanyGate.ready,
  uri: Uri.parse(location),
  devRoutes: false,
);

/// Re-runs the redirect when the auth stage, company gate or pending invite
/// code changes.
class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// App router.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refresh = _RouterRefresh();
  ref
    ..listen<AuthStage>(
      sessionControllerProvider.select((SessionState s) => s.stage),
      (_, _) => refresh.ping(),
    )
    ..listen<CompanyGate>(companyGateProvider, (_, _) => refresh.ping())
    ..listen<String?>(pendingInviteCodeProvider, (_, _) => refresh.ping());

  String? redirect(BuildContext context, GoRouterState state) {
    final stage = ref.read(sessionControllerProvider).stage;
    final uri = state.uri;
    // A join link that arrives before unlock: keep the code for later.
    if (uri.path == AppRoutes.joinLink && stage != AuthStage.unlocked) {
      final code = uri.queryParameters['code'];
      Future<void>.microtask(
        () => ref.read(pendingInviteCodeProvider.notifier).offer(code),
      );
    }
    return appRedirect(
      stage: stage,
      company: ref.read(companyGateProvider),
      uri: uri,
      pendingInviteCode: ref.read(pendingInviteCodeProvider),
    );
  }

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: redirect,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (BuildContext context, GoRouterState state) =>
            const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (BuildContext context, GoRouterState state) =>
            const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.mpinSetup,
        builder: (BuildContext context, GoRouterState state) =>
            const MpinSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.mpin,
        builder: (BuildContext context, GoRouterState state) =>
            const MpinUnlockScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingRegister,
        builder: (BuildContext context, GoRouterState state) =>
            const RegisterCompanyScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingJoin,
        builder: (BuildContext context, GoRouterState state) =>
            JoinCompanyScreen(initialCode: state.uri.queryParameters['code']),
      ),
      // Always redirected (see appRedirect); declared so the link matches.
      GoRoute(
        path: AppRoutes.joinLink,
        redirect: (BuildContext context, GoRouterState state) =>
            AppRoutes.joinWithCode(state.uri.queryParameters['code']),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (BuildContext context, GoRouterState state) =>
            const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.members,
        builder: (BuildContext context, GoRouterState state) =>
            const MembersScreen(),
      ),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.devGallery,
          builder: (BuildContext context, GoRouterState state) =>
              ThemeGalleryScreen(
                projectId: DefaultFirebaseOptions.currentPlatform.projectId,
              ),
        ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
}
