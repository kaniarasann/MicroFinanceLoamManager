// Regression tests for the Sprint 5 on-device bug: right after "Create
// company & continue" the member-doc listener got PERMISSION_DENIED (the
// server had not applied the register batch yet), the app treated that as
// "removed", showed "You no longer have access to …" and DELETED the user's
// membership docs.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_ledger/core/routing/app_router.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/auth/application/session_controller.dart';
import 'package:nordic_ledger/features/company/application/company_providers.dart';
import 'package:nordic_ledger/features/company/application/member_access_monitor.dart';
import 'package:nordic_ledger/features/onboarding/application/onboarding_providers.dart';
import 'package:nordic_ledger/features/onboarding/data/cache_reset_flag.dart';
import 'package:nordic_ledger/features/onboarding/data/company_repository.dart';
import 'package:nordic_ledger/features/onboarding/presentation/screens/register_company_screen.dart';

import '../auth/auth_fakes.dart';
import '../onboarding/onboarding_test_support.dart';

const String uid = 'uid-asha';

final Member _owner = Member(
  id: uid,
  uid: uid,
  role: Role.owner,
  displayName: 'Asha',
  joinedAt: DateTime.utc(2026, 11),
);

const MemberDocEvent _denied = MemberDocDenied();
MemberDocEvent _server(Member? m) =>
    MemberDocSnapshot(m, serverConfirmed: true);
MemberDocEvent _cache(Member? m) =>
    MemberDocSnapshot(m, serverConfirmed: false);

/// A member-doc stream the test drives; every attach opens a new one.
final class FakeMemberDocs {
  final Map<String, List<StreamController<MemberDocEvent>>> attaches =
      <String, List<StreamController<MemberDocEvent>>>{};

  Stream<MemberDocEvent> attach(String cid) {
    final c = StreamController<MemberDocEvent>();
    (attaches[cid] ??= <StreamController<MemberDocEvent>>[]).add(c);
    return c.stream;
  }

  int count(String cid) => attaches[cid]?.length ?? 0;

  /// Emits on the latest listener for [cid]. A denial also closes it, as
  /// the Firestore SDK does after a listener error.
  Future<void> emit(String cid, MemberDocEvent e) async {
    final c = attaches[cid]!.last;
    c.add(e);
    if (e is MemberDocDenied) unawaited(c.close());
    await pumpEventQueue();
  }
}

/// The real repository (fake Firestore) with the member-doc listener and,
/// optionally, the memberships stream replaced.
final class FakeCompanyRepository extends CompanyRepository {
  FakeCompanyRepository(
    AuthHarness h,
    this.docs, {
    this.memberships,
    this.serverCheck,
  }) : super(firestore: h.db, clock: h.clock);

  final FakeMemberDocs docs;
  final Stream<List<Membership>>? memberships;
  final MemberDocEvent? serverCheck;

  @override
  Stream<MemberDocEvent> watchMemberDoc(String cid, String uid) =>
      docs.attach(cid);

  @override
  Stream<List<Membership>> watchMemberships(String uid) =>
      memberships ?? super.watchMemberships(uid);

  @override
  Future<MemberDocEvent?> fetchMemberDocFromServer(String cid, String uid) =>
      Future<MemberDocEvent?>.value(serverCheck);
}

Future<void> seedTwo(AuthHarness h) async {
  await OnboardingFixtures.company(h.db, cid: 'a', name: 'A Co');
  await OnboardingFixtures.company(h.db, cid: 'b', name: 'B Co');
  await OnboardingFixtures.membership(
    h.db,
    uid: uid,
    cid: 'a',
    name: 'A Co',
    joinedAt: DateTime.utc(2026, 11, 1),
  );
  await OnboardingFixtures.membership(
    h.db,
    uid: uid,
    cid: 'b',
    name: 'B Co',
    role: 'collector',
    joinedAt: DateTime.utc(2026, 11, 2),
  );
}

Future<bool> _exists(AuthHarness h, String path) async =>
    (await h.db.doc(path).get()).exists;

void main() {
  group('watchMemberAccess (pure rule)', () {
    late FakeMemberDocs docs;
    late Set<String> confirmed;
    late List<int> backoffCalls;
    late List<MemberWatch> out;
    late StreamSubscription<MemberWatch> sub;

    void start() {
      sub = watchMemberAccess(
        cid: 'a',
        attach: () => docs.attach('a'),
        confirmed: confirmed,
        backoff: (int attempt) {
          backoffCalls.add(attempt);
          return Duration.zero;
        },
      ).listen(out.add);
    }

    setUp(() {
      docs = FakeMemberDocs();
      confirmed = <String>{};
      backoffCalls = <int>[];
      out = <MemberWatch>[];
    });
    tearDown(() => sub.cancel());

    test('permission-denied before any server confirmation: no removal, '
        'the listener re-attaches with backoff', () async {
      start();
      await pumpEventQueue();
      // Register: the local write is visible at once (pending), then the
      // server, not having applied the batch, denies the listener.
      await docs.emit('a', _cache(_owner));
      await docs.emit('a', _denied);
      await pumpEventQueue();
      expect(out.where((MemberWatch w) => w.removed), isEmpty);
      expect(docs.count('a'), 2, reason: 're-attached');
      await docs.emit('a', _denied);
      await pumpEventQueue();
      expect(docs.count('a'), 3);
      expect(backoffCalls, <int>[0, 1], reason: 'growing backoff');
      expect(out.where((MemberWatch w) => w.removed), isEmpty);

      // The batch lands: the server confirms the doc.
      await docs.emit('a', _server(_owner));
      expect(out.last.member?.role, Role.owner);
      expect(confirmed, contains('a'));
    });

    test('not-exists from the cache (or an unconfirmed server miss) is '
        'never a removal', () async {
      start();
      await pumpEventQueue();
      await docs.emit('a', _cache(null));
      await docs.emit('a', _server(null));
      expect(out.where((MemberWatch w) => w.removed), isEmpty);
      expect(confirmed, isEmpty);
    });

    test('a pending (cache) exists does not count as confirmation', () async {
      start();
      await pumpEventQueue();
      await docs.emit('a', _cache(_owner));
      await docs.emit('a', _server(null));
      expect(out.where((MemberWatch w) => w.removed), isEmpty);
    });

    test(
      'server-confirmed exists, then server-confirmed missing → removal',
      () async {
        start();
        await pumpEventQueue();
        await docs.emit('a', _server(_owner));
        await docs.emit('a', _cache(null)); // cache noise: ignored
        expect(out.where((MemberWatch w) => w.removed), isEmpty);
        await docs.emit('a', _server(null));
        expect(out.last.removed, isTrue);
        expect(out.last.cid, 'a');
      },
    );

    test('server-confirmed exists, then permission-denied → removal', () async {
      start();
      await pumpEventQueue();
      await docs.emit('a', _server(_owner));
      await docs.emit('a', _denied);
      expect(out.last.removed, isTrue);
      expect(docs.count('a'), 1, reason: 'no re-attach after removal');
    });

    test('confirmation survives a re-attach (session-wide set)', () async {
      confirmed.add('a');
      start();
      await pumpEventQueue();
      await docs.emit('a', _cache(_owner));
      await docs.emit('a', _denied);
      expect(out.last.removed, isTrue);
    });

    test('other listener errors re-attach and never remove', () async {
      start();
      await pumpEventQueue();
      await docs.emit('a', _server(_owner));
      docs.attaches['a']!.last.addError(StateError('unavailable'));
      await pumpEventQueue();
      expect(out.where((MemberWatch w) => w.removed), isEmpty);
      expect(docs.count('a'), 2);
    });

    test('default backoff: 1, 2, 4, 8, 16, then 30 s', () {
      expect(
        <int>[
          for (var i = 0; i < 8; i++) defaultMemberRetryBackoff(i).inSeconds,
        ],
        <int>[1, 2, 4, 8, 16, 30, 30, 30],
      );
    });
  });

  group('CompanyAccessGuard with a fake member-doc stream', () {
    late AuthHarness h;
    late FakeMemberDocs docs;

    Future<ProviderContainer> start({
      Stream<List<Membership>>? memberships,
      MemberDocEvent? serverCheck,
    }) async {
      final c = ProviderContainer(
        overrides: <Override>[
          ...h.overrides,
          companyRepositoryProvider.overrideWithValue(
            FakeCompanyRepository(
              h,
              docs,
              memberships: memberships,
              serverCheck: serverCheck,
            ),
          ),
          memberRetryBackoffProvider.overrideWithValue((_) => Duration.zero),
        ],
      );
      addTearDown(c.dispose);
      c
        ..listen(sessionControllerProvider, (_, _) {})
        ..listen(companyAccessGuardProvider, (_, _) {})
        ..listen(companyGateProvider, (_, _) {})
        ..listen(currentRoleProvider, (_, _) {});
      await pumpEventQueue();
      return c;
    }

    setUp(() {
      h = AuthHarness(signedIn: kAsha);
      docs = FakeMemberDocs();
    });

    test('permission-denied before confirmation: stays in the company, no '
        'notice, membership docs untouched', () async {
      await seedTwo(h);
      final c = await start();
      final notices = <String?>[];
      c.listen(companyNoticeProvider, (_, String? n) => notices.add(n));
      expect(c.read(activeCompanyIdProvider).value, 'a');

      await docs.emit('a', _cache(_owner));
      await docs.emit('a', _denied);
      await pumpEventQueue();

      expect(c.read(activeCompanyIdProvider).value, 'a');
      expect(c.read(companyGateProvider), CompanyGate.ready);
      expect(c.read(currentRoleProvider), Role.owner);
      expect(notices, isEmpty);
      expect(c.read(removedCompaniesProvider), isEmpty);
      expect(await CacheResetFlag(h.storage).isPending(), isFalse);
      expect(await _exists(h, 'users/$uid/memberships/a'), isTrue);
      expect(await _exists(h, 'users/$uid/memberships/b'), isTrue);
      expect(docs.count('a'), greaterThanOrEqualTo(2), reason: 'retried');
    });

    test('confirmed removal: switch, notify once, cache flag; membership '
        'docs are NEVER deleted', () async {
      await seedTwo(h);
      final c = await start();
      final notices = <String?>[];
      c.listen(companyNoticeProvider, (_, String? n) => notices.add(n));

      await docs.emit('a', _server(_owner));
      await docs.emit('a', _server(null));
      await pumpEventQueue();

      expect(c.read(activeCompanyIdProvider).value, 'b');
      expect(notices.whereType<String>(), <String>[
        'You no longer have access to A Co',
      ]);
      expect(await CacheResetFlag(h.storage).isPending(), isTrue);
      expect(await _exists(h, 'users/$uid/memberships/a'), isTrue);
      expect(await _exists(h, 'users/$uid/memberships/b'), isTrue);
      expect(
        c.read(membershipsProvider).value!.map((Membership m) => m.id),
        <String>['b'],
      );
    });

    test('active company drops from the list without prior server '
        'confirmation: silent switch, no removal handling', () async {
      await seedTwo(h);
      final c = await start(serverCheck: _denied);
      final notices = <String?>[];
      c.listen(companyNoticeProvider, (_, String? n) => notices.add(n));
      await h.db.doc('users/$uid/memberships/a').delete();
      await pumpEventQueue();
      expect(notices, isEmpty);
      expect(await CacheResetFlag(h.storage).isPending(), isFalse);
    });

    test('router: memberships only in the local cache (pending, server '
        'denies the member doc) → stays on /home, not register', () async {
      final pendingMembership = Membership(
        id: 'new',
        companyId: 'new',
        companyName: 'New Co',
        role: Role.owner,
        joinedAt: DateTime.utc(2026, 11, 22),
      );
      final c = await start(
        // What the SDK yields for a locally written, unacknowledged doc.
        memberships: Stream<List<Membership>>.value(<Membership>[
          pendingMembership,
        ]),
      );
      await docs.emit('new', _cache(_owner));
      for (var i = 0; i < 3; i++) {
        await docs.emit('new', _denied);
      }
      await pumpEventQueue();

      final gate = c.read(companyGateProvider);
      expect(gate, CompanyGate.ready);
      String? go(String location) => appRedirect(
        stage: AuthStage.unlocked,
        company: gate,
        uri: Uri.parse(location),
        pendingInviteCode: null,
        devRoutes: false,
      );
      expect(go(AppRoutes.home), isNull);
      expect(go(AppRoutes.splash), AppRoutes.home);
      expect(c.read(currentRoleProvider), Role.owner);
      expect(c.read(removedCompaniesProvider), isEmpty);
    });
  });

  group('register', () {
    test('the member listener attaches only after the register batch '
        'resolves; concurrent calls create ONE company', () async {
      final h = AuthHarness(signedIn: kAsha);
      final docs = FakeMemberDocs();
      final c = ProviderContainer(
        overrides: <Override>[
          ...h.overrides,
          companyRepositoryProvider.overrideWithValue(
            FakeCompanyRepository(h, docs),
          ),
        ],
      );
      addTearDown(c.dispose);
      c
        ..listen(sessionControllerProvider, (_, _) {})
        ..listen(companyAccessGuardProvider, (_, _) {})
        ..listen(companyGateProvider, (_, _) {});
      await pumpEventQueue();

      final actions = c.read(companyActionsProvider);
      final first = actions.registerCompany(
        name: 'Asha Finance',
        ownerDisplayName: 'Asha',
      );
      final second = actions.registerCompany(
        name: 'Asha Finance',
        ownerDisplayName: 'Asha',
      );
      final cid = await first;
      expect(await second, cid);
      await pumpEventQueue();

      final companies = await h.db.collection('companies').get();
      expect(companies.docs, hasLength(1));
      expect(c.read(pendingRegistrationsProvider), isEmpty);
      expect(docs.count(cid), 1, reason: 'attached after the ack');
      expect(c.read(companyGateProvider), CompanyGate.ready);
    });

    testWidgets('register double-tap → only one registerCompany call', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(tester.view.reset);
      final h = AuthHarness(signedIn: kAsha);
      final gate = Completer<String>();
      var calls = 0;
      final router = GoRouter(
        initialLocation: AppRoutes.onboardingRegister,
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.onboardingRegister,
            builder: (_, _) => const RegisterCompanyScreen(),
          ),
          GoRoute(
            path: AppRoutes.home,
            builder: (_, _) => const Scaffold(body: Text('HOME')),
          ),
        ],
      );
      addTearDown(router.dispose);
      final container = ProviderContainer(
        overrides: <Override>[
          ...h.overrides,
          companyActionsProvider.overrideWith(
            (Ref ref) => _CountingActions(ref, () {
              calls++;
              return gate.future;
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(sessionControllerProvider, (_, _) {});
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey<String>('register_name')),
        'Sri Lakshmi Finance',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('register_mobile')),
        '9845012890',
      );
      final submit = find.byKey(const ValueKey<String>('register_submit'));
      await tester.ensureVisible(submit);
      await tester.pump();
      // Two taps in the same frame, then a third once the button rebuilt.
      await tester.tap(submit);
      await tester.tap(submit, warnIfMissed: false);
      await tester.pump();
      await tester.tap(submit, warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);
      expect(
        tester.widget<FilledButton>(submit).onPressed,
        isNull,
        reason: 'disabled while registering',
      );

      gate.complete('cid-1');
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(calls, 1);
    });
  });
}

final class _CountingActions extends CompanyActions {
  _CountingActions(super.ref, this._onRegister);

  final Future<String> Function() _onRegister;

  @override
  Future<String> registerCompany({
    required String name,
    String? city,
    String? phone,
    required String ownerDisplayName,
    String? ownerPhone,
  }) => _onRegister();
}
