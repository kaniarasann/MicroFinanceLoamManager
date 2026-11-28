import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/screens/mpin_setup_screen.dart';
import '../../features/auth/presentation/screens/mpin_unlock_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/borrowers/presentation/screens/borrower_profile_screen.dart';
import '../../features/company/application/company_providers.dart';
import '../../domain/models/enums.dart';
import '../../features/contracts/presentation/screens/contract_detail_screen.dart';
import '../../features/payments/presentation/screens/record_payment_sheet.dart';
import '../../features/rollover/presentation/screens/rollover_screen.dart';
import '../../features/contracts/presentation/screens/create_contract_screen.dart';
import '../../features/contracts/presentation/screens/onboard_contract_screen.dart';
import '../../features/company/presentation/members_screen.dart';
import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../../features/overdue/presentation/screens/overdue_screen.dart';
import '../../features/onboarding/application/onboarding_providers.dart';
import '../../features/onboarding/presentation/screens/join_company_screen.dart';
import '../../features/onboarding/presentation/screens/register_company_screen.dart';
import '../../features/settings/presentation/screens/change_mpin_screen.dart';
import '../../features/settings/presentation/screens/delete_account_screen.dart';
import '../../features/settings/presentation/screens/legal_screen.dart';
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

  /// Shell tabs: `/home?tab=…`.
  static const String tabParam = 'tab';
  static String homeTab(String tab) => '$home?$tabParam=$tab';

  /// Dashboard scrolled to Due Today (daily digest notification).
  static const String dueToday = '$home?$tabParam=today';

  /// Settings tab of the shell.
  static const String settings = '$home?$tabParam=settings';

  /// Members & invites (Settings → Company).
  static const String members = '/settings/members';

  /// Change MPIN (Settings → Security).
  static const String changeMpin = '/settings/mpin';

  /// Delete account (Settings → Account).
  static const String deleteAccount = '/settings/delete-account';

  /// Overdue tracker (dashboard; overdue-nudge notification).
  static const String overdue = '/overdue';

  /// In-app routes reachable once a company is ready.
  static const Set<String> companyShell = <String>{
    home,
    members,
    changeMpin,
    deleteAccount,
    overdue,
  };

  /// Privacy policy and terms: reachable in every auth stage (sign-in and
  /// MPIN screens link to them).
  static const String privacy = '/legal/privacy';
  static const String terms = '/legal/terms';
  static const Set<String> legal = <String>{privacy, terms};

  /// Borrower profile (compact windows; tablets show it in the split view).
  static const String borrowers = '/borrowers';
  static String borrower(String id) => '$borrowers/${Uri.encodeComponent(id)}';

  /// Contracts: create, detail, record payment (sheet / dialog) and
  /// rollover (owner only).
  static const String contracts = '/contracts';
  static const String newContractPath = '$contracts/new';
  static String newContract({String? borrowerId}) => borrowerId == null
      ? newContractPath
      : '$newContractPath?borrowerId=${Uri.encodeQueryComponent(borrowerId)}';

  /// Onboard an existing loan (owner only). Declared before
  /// `/contracts/:id`, like [newContractPath].
  static const String onboardContractPath = '$contracts/onboard';
  static String onboardContract({String? borrowerId}) => borrowerId == null
      ? onboardContractPath
      : '$onboardContractPath?borrowerId=${Uri.encodeQueryComponent(borrowerId)}';
  static String contract(String id) => '$contracts/${Uri.encodeComponent(id)}';
  static String recordPayment(String id) => '${contract(id)}/pay';
  static String rollover(String id) => '${contract(id)}/rollover';

  /// Whether [path] is inside the company shell (static or parameterised).
  static bool inCompanyShell(String path) =>
      companyShell.contains(path) ||
      path.startsWith('$borrowers/') ||
      path.startsWith('$contracts/');

  /// Whether [location] is a place a notification may open: Due Today,
  /// the overdue tracker or a contract's Record Payment. Anything else in a
  /// payload is ignored.
  ///
  /// A target may carry the company it was planned for as `c={cid}` (see
  /// [withCompany]); any other extra query parameter is refused.
  static bool isNotificationTarget(String location) {
    final uri = Uri.tryParse(location);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return false;
    if (uri.queryParameters.containsKey(companyParam) &&
        (uri.queryParameters[companyParam] ?? '').isEmpty) {
      return false;
    }
    final base = withoutCompany(location);
    if (base == dueToday || base == overdue) return true;
    final b = Uri.parse(base);
    final s = b.pathSegments;
    return !b.hasQuery &&
        s.length == 3 &&
        '/${s[0]}' == contracts &&
        s[1].isNotEmpty &&
        s[1] != 'new' &&
        s[1] != 'onboard' &&
        s[2] == 'pay';
  }

  /// Query parameter naming the company a notification was planned for.
  static const String companyParam = 'c';

  /// [location] with `c=$cid` appended.
  static String withCompany(String location, String cid) {
    final sep = location.contains('?') ? '&' : '?';
    return '$location$sep$companyParam=${Uri.encodeQueryComponent(cid)}';
  }

  /// The `c=` company of a notification location, or null.
  static String? companyOf(String location) =>
      Uri.tryParse(location)?.queryParameters[companyParam];

  /// [location] without its `c=` parameter.
  static String withoutCompany(String location) {
    final uri = Uri.parse(location);
    if (!uri.queryParameters.containsKey(companyParam)) return location;
    final rest = <String, String>{...uri.queryParameters}..remove(companyParam);
    final path = uri.path;
    if (rest.isEmpty) return path;
    return Uri(path: path, queryParameters: rest).toString();
  }

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
  if (AppRoutes.legal.contains(path)) return null;
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
      // Account deletion must stay reachable without a company (Play
      // account-deletion policy); legal pages are allowed above.
      if (onboarding || path == AppRoutes.deleteAccount) return null;
      return AppRoutes.onboardingRegister;
    case CompanyGate.ready:
      if (onboarding || AppRoutes.inCompanyShell(path)) return null;
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
        builder: (BuildContext context, GoRouterState state) => HomeScreen(
          initialTab: state.uri.queryParameters[AppRoutes.tabParam],
        ),
      ),
      GoRoute(
        path: '${AppRoutes.borrowers}/:id',
        builder: (BuildContext context, GoRouterState state) =>
            BorrowerProfileScreen(borrowerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.newContractPath,
        // Owner only (the rules enforce it too); collectors go home.
        redirect: (BuildContext context, GoRouterState state) =>
            ref.read(currentRoleProvider) == Role.collector
            ? AppRoutes.home
            : null,
        builder: (BuildContext context, GoRouterState state) =>
            CreateContractScreen(
              borrowerId: state.uri.queryParameters['borrowerId'],
            ),
      ),
      GoRoute(
        path: AppRoutes.onboardContractPath,
        // Owner only (the rules enforce it too). No redirect: the screen
        // tells a collector "Only owners can onboard loans." and leaves.
        builder: (BuildContext context, GoRouterState state) =>
            OnboardContractScreen(
              borrowerId: state.uri.queryParameters['borrowerId'],
            ),
      ),
      GoRoute(
        path: '${AppRoutes.contracts}/:id',
        builder: (BuildContext context, GoRouterState state) =>
            ContractDetailScreen(contractId: state.pathParameters['id']!),
        routes: <RouteBase>[
          GoRoute(
            path: 'pay',
            pageBuilder: (BuildContext context, GoRouterState state) =>
                recordPaymentPage(state),
          ),
          GoRoute(
            path: 'rollover',
            // Owner only (the rules enforce it too); collectors go back.
            redirect: (BuildContext context, GoRouterState state) =>
                ref.read(currentRoleProvider) == Role.collector
                ? AppRoutes.contract(state.pathParameters['id']!)
                : null,
            builder: (BuildContext context, GoRouterState state) =>
                RolloverScreen(contractId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.overdue,
        builder: (BuildContext context, GoRouterState state) =>
            const OverdueScreen(),
      ),
      GoRoute(
        path: AppRoutes.members,
        builder: (BuildContext context, GoRouterState state) =>
            const MembersScreen(),
      ),
      GoRoute(
        path: AppRoutes.changeMpin,
        builder: (BuildContext context, GoRouterState state) =>
            const ChangeMpinScreen(),
      ),
      GoRoute(
        path: AppRoutes.deleteAccount,
        builder: (BuildContext context, GoRouterState state) =>
            const DeleteAccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (BuildContext context, GoRouterState state) =>
            const LegalScreen(document: LegalDocument.privacy),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (BuildContext context, GoRouterState state) =>
            const LegalScreen(document: LegalDocument.terms),
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
