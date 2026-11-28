import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:nordic_ledger/core/firebase/firebase_providers.dart';
import 'package:nordic_ledger/features/company/application/company_providers.dart';
import 'package:nordic_ledger/features/onboarding/presentation/screens/register_company_screen.dart';
import 'package:nordic_ledger/features/settings/application/settings_providers.dart';
import 'package:nordic_ledger/features/settings/data/account_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/features/auth/application/session_controller.dart';
import 'package:nordic_ledger/features/auth/data/mpin_store.dart';
import 'package:nordic_ledger/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:nordic_ledger/features/onboarding/data/cache_reset_flag.dart';
import 'package:nordic_ledger/features/settings/application/account_exit.dart';
import 'package:nordic_ledger/features/settings/presentation/screens/delete_account_screen.dart';

import '../../domain/ledger/ledger_fixtures.dart';
import '../onboarding/onboarding_test_support.dart';
import 'settings_test_support.dart';

Finder key(String k) => find.byKey(ValueKey<String>(k));

CompanyExitFacts facts({
  bool readable = true,
  List<String> owners = const <String>['me'],
  int others = 0,
}) => CompanyExitFacts(
  companyId: 'c',
  companyName: 'A Co',
  readable: readable,
  ownerUids: owners,
  otherMembers: others,
);

Future<AuthHarness> openDelete(
  WidgetTester tester, {
  String role = 'owner',
  List<String> owners = const <String>[kAshaUid],
  List<String> otherMembers = const <String>[],
  double width = 400,
  double textScale = 1,
}) async {
  final h = await pumpSettingsApp(
    tester,
    role: role,
    owners: owners,
    otherMembers: otherMembers,
    width: width,
    textScale: textScale,
  );
  await tapSetting(tester, 'settings_delete_account');
  await settle(tester);
  expect(find.byType(DeleteAccountScreen), findsOneWidget);
  return h;
}

Future<bool> exists(WidgetTester tester, AuthHarness h, String path) async =>
    (await tester.runAsync(() => h.db.doc(path).get()))!.exists;

Future<void> confirm(WidgetTester tester) async {
  await tester.ensureVisible(key('delete_understood'));
  await tester.tap(key('delete_understood'));
  await tester.pump();
  await tester.ensureVisible(key('delete_confirm'));
  await tester.tap(key('delete_confirm'));
  await settle(tester, 6);
}

void main() {
  group('decideExit', () {
    test('mirrors the last-owner rule', () {
      expect(decideExit('me', facts(readable: false)), ExitAction.stale);
      expect(
        decideExit('me', facts(owners: const <String>['boss'])),
        ExitAction.leave,
      );
      expect(
        decideExit('me', facts(owners: const <String>['me', 'boss'])),
        ExitAction.leaveOwner,
      );
      expect(decideExit('me', facts()), ExitAction.close);
      expect(decideExit('me', facts(others: 2)), ExitAction.blocked);
    });

    test('descriptions and the plan', () {
      final plan = AccountExitPlan('me', <CompanyExitFacts>[
        facts(others: 1),
        facts(readable: false),
      ]);
      expect(plan.isBlocked, isTrue);
      expect(plan.blocked.single.description, contains('1 other member'));
      expect(plan.exits.last.description, contains('no longer have access'));
      expect(
        CompanyExit(facts(others: 3), ExitAction.blocked).description,
        contains('3 other members'),
      );
      expect(
        CompanyExit(facts(), ExitAction.close).description,
        contains('closed'),
      );
      expect(
        CompanyExit(facts(), ExitAction.leave).description,
        contains('leave A Co'),
      );
    });
  });

  testWidgets('collector: leaves, deletes profile + settings, keeps the '
      'ledger, deletes the Auth user', (WidgetTester tester) async {
    final h = await openDelete(
      tester,
      role: 'collector',
      owners: const <String>['uid-owner'],
      otherMembers: const <String>['uid-owner'],
    );
    await tester.runAsync(
      () => TypedRefs(h.db)
          .transaction('a', 't1')
          .set(tx('c1', rs(3500), d(2026, 11, 20), id: 't1')),
    );
    expect(find.textContaining('You will leave A Co'), findsOneWidget);
    // Disabled until "I understand".
    final btn = tester.widget<FilledButton>(key('delete_confirm'));
    expect(btn.onPressed, isNull);

    await confirm(tester);

    expect(h.repo.reauthCalls, 1);
    expect(h.repo.deleteCalls, 1);
    expect(
      await exists(tester, h, 'companies/a/members/${kAsha.uid}'),
      isFalse,
    );
    expect(
      await exists(tester, h, 'users/${kAsha.uid}/memberships/a'),
      isFalse,
    );
    expect(await exists(tester, h, 'user_settings/${kAsha.uid}'), isFalse);
    expect(await exists(tester, h, 'users/${kAsha.uid}'), isFalse);
    expect(await exists(tester, h, 'companies/a/transactions/t1'), isTrue);
    expect(await exists(tester, h, 'companies/a'), isTrue);
    // Device clean-up.
    expect(h.storage.values[MpinStore.hashKey(kAsha.uid)], isNull);
    expect(h.storage.values[CacheResetFlag.key], '1');
    expect(h.notifications.scheduled, isEmpty);
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text(kAccountDeletedMessage), findsOneWidget);
  });

  testWidgets('one of two owners: drops out of ownerUids', (
    WidgetTester tester,
  ) async {
    final h = await openDelete(
      tester,
      owners: const <String>[kAshaUid, 'uid-ravi'],
      otherMembers: const <String>['uid-ravi'],
    );
    await confirm(tester);
    final c = await tester.runAsync(() => h.db.doc('companies/a').get());
    expect(c!.data()!['ownerUids'], <String>['uid-ravi']);
    expect(h.repo.deleteCalls, 1);
  });

  testWidgets('sole owner and only member: the company is closed', (
    WidgetTester tester,
  ) async {
    final h = await openDelete(tester);
    await tester.runAsync(
      () => OnboardingFixtures.invite(
        h.db,
        companyId: 'a',
        companyName: 'A Co',
        expiresAt: DateTime.utc(2026, 11, 28),
      ),
    );
    // Re-read the preview with the invite.
    await tester.pageBack();
    await settle(tester);
    await tapSetting(tester, 'settings_delete_account');
    expect(find.textContaining('it will be closed'), findsOneWidget);
    await confirm(tester);
    final c = (await tester.runAsync(() => h.db.doc('companies/a').get()))!;
    expect(c.data()!['ownerUids'], isEmpty);
    expect(c.data()!['closedBy'], kAsha.uid);
    final inv = await tester.runAsync(() => h.db.doc('invites/K7Q2MD').get());
    expect(inv!.data()!['status'], 'revoked');
    expect(h.repo.deleteCalls, 1);
  });

  testWidgets('sole owner with other members is blocked', (
    WidgetTester tester,
  ) async {
    final h = await openDelete(
      tester,
      otherMembers: const <String>['uid-kumar'],
    );
    expect(
      find.textContaining("You're the only owner of A Co"),
      findsOneWidget,
    );
    expect(key('delete_confirm'), findsNothing);
    expect(key('delete_open_members'), findsOneWidget);
    expect(h.repo.reauthCalls, 0);
  });

  testWidgets('cancelling the Google re-auth deletes nothing', (
    WidgetTester tester,
  ) async {
    final h = await openDelete(tester);
    h.repo.reauthResult = false;
    await confirm(tester);
    expect(h.repo.deleteCalls, 0);
    expect(await exists(tester, h, 'user_settings/${kAsha.uid}'), isTrue);
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
  });

  testWidgets('a re-auth failure is shown and nothing is deleted', (
    WidgetTester tester,
  ) async {
    final h = await openDelete(tester);
    h.repo.reauthFailure = const ValidationFailure(
      'account',
      'Use the same Google account you signed in with.',
    );
    await confirm(tester);
    expect(key('delete_error'), findsOneWidget);
    expect(h.repo.deleteCalls, 0);
    expect(await exists(tester, h, 'users/${kAsha.uid}'), isTrue);
  });

  testWidgets('Auth refusing the delete still signs out with a notice', (
    WidgetTester tester,
  ) async {
    final h = await openDelete(tester);
    h.repo.deleteFailure = const ExpiredFailure();
    await confirm(tester);
    expect(h.repo.signOutCalls, 1);
    expect(find.text(kAccountDeletionIncompleteMessage), findsOneWidget);
  });

  for (final (double width, double scale) in <(double, double)>[
    (1024, 1),
    (360, 1.3),
  ]) {
    testWidgets('lays out @${width.toInt()} ×$scale', (
      WidgetTester tester,
    ) async {
      await openDelete(
        tester,
        width: width,
        textScale: scale,
        otherMembers: const <String>['uid-kumar'],
      );
      expect(tester.takeException(), isNull);
      expect(key('delete_open_members'), findsOneWidget);
    });
  }

  testWidgets('F2: a commit that times out is pending, not failed; it '
      'finishes on the ack', (WidgetTester tester) async {
    late DelayedAccountRepository repo;
    final h = await pumpSettingsApp(
      tester,
      role: 'collector',
      owners: const <String>['uid-owner'],
      otherMembers: const <String>['uid-owner'],
      extraOverrides: <Override>[
        accountRepositoryProvider.overrideWith((Ref ref) {
          return repo = DelayedAccountRepository(ref.watch(firestoreProvider));
        }),
      ],
    );
    await tapSetting(tester, 'settings_delete_account');
    await settle(tester);
    await confirm(tester);
    expect(key('delete_pending'), findsOneWidget);
    expect(find.text(deletionPendingMessage), findsOneWidget);
    expect(h.repo.deleteCalls, 0);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(DeleteAccountScreen)),
    );
    expect(c.read(accountDeletionInProgressProvider), isTrue);
    expect(await exists(tester, h, 'user_settings/${kAsha.uid}'), isTrue);

    // Back online: the queued batch lands, then the clean-up runs.
    repo.ack.complete();
    await settle(tester, 6);
    expect(await exists(tester, h, 'user_settings/${kAsha.uid}'), isFalse);
    expect(h.repo.deleteCalls, 1);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('F2: offline up front is refused before the Google prompt', (
    WidgetTester tester,
  ) async {
    final h = await openDelete(tester);
    h.sync.setOnline(value: false);
    await tester.pump();
    await confirm(tester);
    expect(key('delete_error'), findsOneWidget);
    expect(find.textContaining('You need to be online'), findsOneWidget);
    expect(h.repo.reauthCalls, 0);
  });

  testWidgets('F3: a user with no company can delete their account from '
      'onboarding', (WidgetTester tester) async {
    final h = await pumpSettingsApp(
      tester,
      withCompany: false,
      openSettings: false,
    );
    expect(find.byType(RegisterCompanyScreen), findsOneWidget);
    final link = key('onboarding_delete_account');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await settle(tester);
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(key('delete_no_company'), findsOneWidget);
    await confirm(tester);
    expect(h.repo.deleteCalls, 1);
    expect(await exists(tester, h, 'users/${kAsha.uid}'), isFalse);
    expect(await exists(tester, h, 'user_settings/${kAsha.uid}'), isFalse);
    expect(find.byType(SignInScreen), findsOneWidget);
  });
}

/// Commits only when [ack] completes (a batch queued while offline).
final class DelayedAccountRepository extends AccountRepository {
  DelayedAccountRepository(FirebaseFirestore db)
    : super(firestore: db, ackTimeout: const Duration(milliseconds: 100));

  final Completer<void> ack = Completer<void>();

  @override
  Future<void> commitExit(String uid, AccountExitPlan plan) async {
    throw AckPendingFailure(
      ack.future.then((_) => super.commitExit(uid, plan)),
    );
  }
}
