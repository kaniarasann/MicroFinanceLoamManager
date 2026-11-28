// Tester — Sprint 8: Settings UI, change MPIN and delete account.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/app.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/firebase/converters.dart';
import 'package:nordic_ledger/core/routing/app_router.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/features/auth/application/session_controller.dart';
import 'package:nordic_ledger/features/auth/data/mpin_store.dart';
import 'package:nordic_ledger/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:nordic_ledger/features/company/presentation/members_screen.dart';
import 'package:nordic_ledger/features/dashboard/presentation/screens/home_screen.dart';
import 'package:nordic_ledger/features/notifications/application/notification_providers.dart';
import 'package:nordic_ledger/features/payments/presentation/screens/record_payment_sheet.dart';
import 'package:nordic_ledger/features/settings/application/account_exit.dart';
import 'package:nordic_ledger/features/settings/application/settings_providers.dart';
import 'package:nordic_ledger/features/settings/data/account_repository.dart';
import 'package:nordic_ledger/features/settings/presentation/screens/change_mpin_screen.dart';
import 'package:nordic_ledger/features/settings/presentation/screens/delete_account_screen.dart';
import 'package:nordic_ledger/features/settings/presentation/screens/settings_screen.dart';

import '../../../domain/ledger/ledger_fixtures.dart';
import '../../borrowers/borrower_test_support.dart' show aggregatesFixture;
import '../../onboarding/onboarding_test_support.dart';
import '../settings_test_support.dart';

Finder key(String k) => find.byKey(ValueKey<String>(k));

Future<void> enter(WidgetTester tester, String pin) async {
  for (final k in pin.split('')) {
    await tester.tap(find.byKey(ValueKey<String>('pin_key_$k')));
    await tester.pump();
  }
  await settle(tester, 2);
}

Future<Map<String, dynamic>?> data(
  WidgetTester tester,
  AuthHarness h,
  String path,
) async => (await tester.runAsync(() => h.db.doc(path).get()))!.data();

Future<void> confirmDelete(WidgetTester tester) async {
  await tester.ensureVisible(key('delete_understood'));
  await tester.tap(key('delete_understood'));
  await tester.pump();
  await tester.ensureVisible(key('delete_confirm'));
  await tester.tap(key('delete_confirm'));
  await settle(tester, 6);
}

/// Writes a contract, a payment and a borrower in company `a`, stamped by
/// Asha (the ledger must survive her account deletion).
Future<void> seedLedger(WidgetTester tester, AuthHarness h) =>
    tester.runAsync(() async {
      final refs = TypedRefs(h.db);
      await refs
          .transaction('a', 't1')
          .set(tx('c1', rs(3500), d(2026, 11, 20), id: 't1'));
      await h.db.doc('companies/a/transactions/t1').update(<String, Object?>{
        'recordedBy': kAsha.uid,
        'recordedByName': 'Asha Rao',
      });
      await refs.contract('a', 'c1').set(
        makeContract(
          id: 'c1',
          loanNo: 1,
          sanctioned: rs(10000),
          installment: rs(1000),
          firstDue: d(2026, 11, 3),
        ),
      );
      await h.db.doc('companies/a/borrowers/b1').set(<String, Object?>{
        'name': 'Anita',
        'createdBy': kAsha.uid,
      });
    });

const List<String> ledgerPaths = <String>[
  'companies/a/transactions/t1',
  'companies/a/contracts/c1',
  'companies/a/borrowers/b1',
];

/// Account repository whose server reads fail as when offline.
final class OfflineAccountRepository extends AccountRepository {
  OfflineAccountRepository(FirebaseFirestore db) : super(firestore: db);
  int commits = 0;

  @override
  Future<List<CompanyExitFacts>> loadExitFacts(String uid) async =>
      throw const OfflineRequiredFailure();

  @override
  Future<void> commitExit(String uid, AccountExitPlan plan) async {
    commits++;
  }
}

/// A batch whose commit never reaches the server (queued offline).
final class QueuedBatch implements WriteBatch {
  QueuedBatch(this._inner);
  final WriteBatch _inner;
  int ops = 0;

  @override
  Future<void> commit() => Completer<void>().future;

  @override
  void delete(DocumentReference<Object?> document) {
    ops++;
    _inner.delete(document);
  }

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    ops++;
    _inner.set(document, data, options);
  }

  @override
  void update<T>(DocumentReference<T> document, T data) {
    ops++;
    _inner.update(document, data);
  }
}

final class OfflineFirestore extends FakeFirebaseFirestore {
  @override
  WriteBatch batch() => QueuedBatch(super.batch());
}

void main() {
  group('change MPIN', () {
    Future<AuthHarness> open(WidgetTester tester) async {
      final h = await pumpSettingsApp(tester);
      await tapSetting(tester, 'settings_change_mpin');
      expect(find.byType(ChangeMpinScreen), findsOneWidget);
      return h;
    }

    testWidgets('S8-U1 wrong tries persist across screens: 4 wrong, leave, '
        'reopen, 1 wrong → lockout', (WidgetTester tester) async {
      final h = await open(tester);
      for (var i = 0; i < 4; i++) {
        await enter(tester, '0000');
      }
      expect(await tester.runAsync(() => h.mpin.failedAttempts(kAsha.uid)), 4);
      await tester.pageBack();
      await settle(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tapSetting(tester, 'settings_change_mpin');
      await enter(tester, '1111');
      await settle(tester);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text(kLockoutMessage), findsOneWidget);
      expect(h.repo.signOutCalls, 1);
    });

    testWidgets('S8-U2 a correct current MPIN resets the counter', (
      WidgetTester tester,
    ) async {
      final h = await open(tester);
      await enter(tester, '0000');
      await enter(tester, '0000');
      await enter(tester, '2468');
      expect(find.text('Choose a new MPIN'), findsOneWidget);
      expect(await tester.runAsync(() => h.mpin.failedAttempts(kAsha.uid)), 0);
    });

    testWidgets('S8-U3 mismatched confirm keeps the old MPIN', (
      WidgetTester tester,
    ) async {
      final h = await open(tester);
      await enter(tester, '2468');
      await enter(tester, '1357');
      await enter(tester, '1358');
      expect(find.text('Choose a new MPIN'), findsOneWidget);
      final oldOk = await tester.runAsync(() => h.mpin.verify(kAsha.uid, '2468'));
      expect(oldOk!.ok, isTrue);
      final newOk = await tester.runAsync(() => h.mpin.verify(kAsha.uid, '1357'));
      expect(newOk!.ok, isFalse);
    });
  });

  group('security', () {
    testWidgets('S8-U4 biometric: a failed prompt leaves it off', (
      WidgetTester tester,
    ) async {
      final h = await pumpSettingsApp(tester, biometricAvailable: true);
      h.biometric.result = false;
      await tapSetting(tester, 'settings_biometric');
      expect(h.biometric.authCalls, 1);
      expect(h.storage.values[MpinStore.biometricKey(kAsha.uid)], isNot('true'));
      final s = tester.widget<Switch>(
        find.descendant(of: key('settings_biometric'), matching: find.byType(Switch)),
      );
      expect(s.value, isFalse);
    });

    testWidgets('S8-U5 biometric: turning it off needs no prompt', (
      WidgetTester tester,
    ) async {
      final h = await pumpSettingsApp(tester, biometricAvailable: true);
      await tapSetting(tester, 'settings_biometric');
      expect(h.biometric.authCalls, 1);
      h.biometric.result = false;
      await tapSetting(tester, 'settings_biometric');
      expect(h.biometric.authCalls, 1);
      expect(h.storage.values[MpinStore.biometricKey(kAsha.uid)], 'false');
    });

    testWidgets('S8-U6 auto-lock: every option persists device-locally', (
      WidgetTester tester,
    ) async {
      final h = await pumpSettingsApp(tester);
      for (final (int m, String label) in <(int, String)>[
        (0, 'Immediately'),
        (15, 'After 15 min'),
        (1, 'After 1 min'),
      ]) {
        await tapSetting(tester, 'settings_autolock');
        await tester.tap(key('autolock_$m'));
        await settle(tester);
        expect(h.storage.values[MpinStore.autoLockKey(kAsha.uid)], '$m');
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // Nothing about auto-lock goes to Firestore.
      final s = await data(tester, h, 'user_settings/${kAsha.uid}');
      expect(s!.containsKey('autoLockMinutes'), isFalse);
    });
  });

  group('notifications', () {
    testWidgets('S8-U7 the time picker saves 18:30 to user_settings and '
        're-plans', (WidgetTester tester) async {
      final h = await pumpSettingsApp(tester);
      await tapSetting(tester, 'notif_time');
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pump();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '6');
      await tester.enterText(fields.at(1), '30');
      await tester.tap(find.text('PM'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await settle(tester);
      final s = await data(tester, h, 'user_settings/${kAsha.uid}');
      final n = s!['notifications'] as Map<String, dynamic>;
      expect(n['digestTime'], '18:30');
      expect(n['digestEnabled'], isTrue);
      expect(n['perInstallmentEnabled'], isFalse);
      expect(s['activeCompanyId'], 'a');
      expect(find.text('6:30 PM'), findsOneWidget);
      for (final x in h.notifications.scheduled) {
        expect(x.plan.time, const DigestTime(18, 30));
      }
    });

    testWidgets('S8-U8 cancelling the picker writes nothing', (
      WidgetTester tester,
    ) async {
      final h = await pumpSettingsApp(tester);
      await tapSetting(tester, 'notif_time');
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      final s = await data(tester, h, 'user_settings/${kAsha.uid}');
      expect(s!.containsKey('notifications'), isFalse);
    });

    testWidgets('S8-U9 permission blocked: banner shows; turning a kind on '
        're-requests; granted shows no banner', (WidgetTester tester) async {
      final h = await pumpSettingsApp(tester);
      expect(key('notifications_blocked'), findsNothing);
      h.notifications.permissionGranted = false;
      await tester.tap(find.text('Dashboard'));
      await settle(tester);
      await tester.tap(find.text('Settings').last);
      await settle(tester);
      expect(key('notifications_blocked'), findsOneWidget);
      expect(find.textContaining('Notifications are off'), findsOneWidget);
      final before = h.notifications.permissionRequests;
      await tapSetting(tester, 'notif_installment');
      expect(h.notifications.permissionRequests, before + 1);
      // Turning a kind off never prompts.
      await tapSetting(tester, 'notif_installment');
      expect(h.notifications.permissionRequests, before + 1);
    });
  });

  group('roles', () {
    testWidgets('S8-U10 owner: Members & invites + Owner pill', (
      WidgetTester tester,
    ) async {
      await pumpSettingsApp(tester);
      expect(find.text('Members & invites'), findsOneWidget);
      expect(find.text('Owner'), findsWidgets);
      expect(find.text('Collector'), findsNothing);
    });

    testWidgets('S8-U11 collector: Members, Collector pill, same '
        'notification kinds', (WidgetTester tester) async {
      await pumpSettingsApp(
        tester,
        role: 'collector',
        owners: const <String>['uid-owner'],
        otherMembers: const <String>['uid-owner'],
      );
      expect(find.text('Members & invites'), findsNothing);
      expect(find.text('Collector'), findsWidgets);
      for (final k in <String>['notif_digest', 'notif_installment', 'notif_overdue']) {
        await tester.ensureVisible(key(k));
        expect(key(k), findsOneWidget, reason: k);
      }
    });
  });

  testWidgets('S8-U12 sign-out cancel keeps the session and the '
      'notifications', (WidgetTester tester) async {
    final h = await pumpSettingsApp(tester);
    final scheduled = h.notifications.scheduled.length;
    final cancels = h.notifications.cancelCalls;
    await tapSetting(tester, 'settings_sign_out');
    expect(key('sign_out_dialog'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(h.notifications.cancelCalls, cancels);
    expect(h.repo.signOutCalls, 0);
    expect(h.notifications.scheduled.length, scheduled);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  group('delete account', () {
    Future<void> openDelete(WidgetTester tester) async {
      await tapSetting(tester, 'settings_delete_account');
      await settle(tester);
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
    }

    testWidgets('S8-A1 collector leaves; ledger docs identical after', (
      WidgetTester tester,
    ) async {
      final h = await pumpSettingsApp(
        tester,
        role: 'collector',
        owners: const <String>['uid-owner'],
        otherMembers: const <String>['uid-owner'],
      );
      await seedLedger(tester, h);
      final before = <String, Map<String, dynamic>?>{
        for (final p in ledgerPaths) p: await data(tester, h, p),
        'companies/a': await data(tester, h, 'companies/a'),
      };
      await openDelete(tester);
      await confirmDelete(tester);
      expect(h.repo.deleteCalls, 1);
      for (final e in before.entries) {
        expect(await data(tester, h, e.key), e.value, reason: e.key);
      }
      expect(await data(tester, h, 'companies/a/members/uid-owner'), isNotNull);
      expect(await data(tester, h, 'companies/a/members/${kAsha.uid}'), isNull);
      final t = await data(tester, h, 'companies/a/transactions/t1');
      expect(t!['recordedByName'], 'Asha Rao');
    });

    testWidgets('S8-A2 one of two owners: co-owner keeps everything, '
        'company not closed', (WidgetTester tester) async {
      final h = await pumpSettingsApp(
        tester,
        owners: const <String>[kAshaUid, 'uid-ravi'],
        otherMembers: const <String>['uid-ravi'],
      );
      await seedLedger(tester, h);
      await openDelete(tester);
      await confirmDelete(tester);
      final c = await data(tester, h, 'companies/a');
      expect(c!['ownerUids'], <String>['uid-ravi']);
      expect(c.containsKey('closedAt'), isFalse);
      expect(c.containsKey('closedBy'), isFalse);
      expect(await data(tester, h, 'companies/a/members/uid-ravi'), isNotNull);
      for (final p in ledgerPaths) {
        expect(await data(tester, h, p), isNotNull, reason: p);
      }
    });

    testWidgets('S8-A3 sole owner, only member: company closed, ledger kept', (
      WidgetTester tester,
    ) async {
      final h = await pumpSettingsApp(tester);
      await seedLedger(tester, h);
      final before = <String, Map<String, dynamic>?>{
        for (final p in ledgerPaths) p: await data(tester, h, p),
      };
      await openDelete(tester);
      expect(find.textContaining('it will be closed'), findsOneWidget);
      await confirmDelete(tester);
      final c = await data(tester, h, 'companies/a');
      expect(c!['ownerUids'], isEmpty);
      expect(c['closedBy'], kAsha.uid);
      expect(c['closedAt'], isNotNull);
      expect(c['name'], 'A Co');
      for (final e in before.entries) {
        expect(await data(tester, h, e.key), e.value, reason: e.key);
      }
      expect(await data(tester, h, 'user_settings/${kAsha.uid}'), isNull);
      expect(find.text(kAccountDeletedMessage), findsOneWidget);
    });

    testWidgets('S8-A4 sole owner with a member in a 2nd company blocks the '
        'whole deletion', (WidgetTester tester) async {
      final h = await pumpSettingsApp(
        tester,
        owners: const <String>[kAshaUid, 'uid-ravi'],
        otherMembers: const <String>['uid-ravi'],
      );
      await tester.runAsync(() async {
        await OnboardingFixtures.company(
          h.db,
          cid: 'b',
          name: 'B Co',
          owners: <String>[kAsha.uid],
        );
        await OnboardingFixtures.membership(
          h.db,
          uid: kAsha.uid,
          cid: 'b',
          name: 'B Co',
        );
        await OnboardingFixtures.membership(
          h.db,
          uid: 'uid-kumar',
          cid: 'b',
          name: 'B Co',
          role: 'collector',
        );
      });
      await openDelete(tester);
      expect(find.textContaining("You're the only owner of B Co"), findsOneWidget);
      expect(key('delete_confirm'), findsNothing);
      expect(h.repo.reauthCalls, 0);
      // Company A (deletable on its own) is untouched.
      expect(await data(tester, h, 'companies/a/members/${kAsha.uid}'), isNotNull);
      expect((await data(tester, h, 'companies/a'))!['ownerUids'],
          <String>[kAshaUid, 'uid-ravi']);
    });

    Future<(AuthHarness, OfflineAccountRepository)> pumpOffline(
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 1400);
      addTearDown(tester.view.reset);
      final h = AuthHarness(signedIn: kAsha);
      final repo = OfflineAccountRepository(h.db);
      await tester.runAsync(() async {
        await h.mpin.setMpin(kAsha.uid, '2468');
        await OnboardingFixtures.company(h.db, cid: 'a', name: 'A Co', owners: <String>[kAsha.uid]);
        await OnboardingFixtures.membership(h.db, uid: kAsha.uid, cid: 'a', name: 'A Co');
        await h.db.doc('user_settings/${kAsha.uid}').set(<String, Object?>{
          'activeCompanyId': 'a',
        });
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            ...h.overrides,
            accountRepositoryProvider.overrideWithValue(repo),
          ],
          child: const App(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await enter(tester, '2468');
      await settle(tester);
      await tester.tap(find.text('Settings').last);
      await settle(tester);
      await openDelete(tester);
      return (h, repo);
    }

    testWidgets(
      'S8-A5b offline: the "needs a connection" error shows within 5 s',
      (WidgetTester tester) async {
        await pumpOffline(tester);
        await tester.pump(const Duration(seconds: 5));
        expect(key('delete_account_error'), findsOneWidget);
      },
      // S8-B2 fixed in attempt 2: accountExitPlanProvider has retry: noRetry.
    );

    testWidgets('S8-A5 offline: deletion is refused with the online message '
        'and nothing is deleted', (WidgetTester tester) async {
      final (h, repo) = await pumpOffline(tester);
      // Riverpod's default retry delays the error (see S8-A5b).
      await tester.pump(const Duration(seconds: 45));
      await tester.pump();
      expect(key('delete_account_error'), findsOneWidget);
      expect(find.textContaining('You need to be online'), findsOneWidget);
      expect(key('delete_confirm'), findsNothing);
      expect(repo.commits, 0);
      expect(h.repo.reauthCalls, 0);
      expect(h.repo.deleteCalls, 0);
      expect(await data(tester, h, 'user_settings/${kAsha.uid}'), isNotNull);
    });

    test('S8-A6 offline at commit: a queued batch times out as '
        'OfflineRequiredFailure (never reported as deleted)', () async {
      final db = OfflineFirestore();
      final repo = AccountRepository(
        firestore: db,
        ackTimeout: const Duration(milliseconds: 50),
      );
      final plan = AccountExitPlan('me', const <CompanyExitFacts>[
        CompanyExitFacts(
          companyId: 'a',
          companyName: 'A Co',
          readable: true,
          ownerUids: <String>['other'],
        ),
      ]);
      await expectLater(
        repo.commitExit('me', plan),
        throwsA(isA<OfflineRequiredFailure>()),
      );
    });

    test('S8-A7 the batch never touches a ledger path', () async {
      final db = FakeFirebaseFirestore();
      final paths = <String>[];
      final repo = AccountRepository(firestore: _Recording(db, paths));
      final plan = AccountExitPlan('me', const <CompanyExitFacts>[
        CompanyExitFacts(companyId: 'a', companyName: 'A', readable: true, ownerUids: <String>['other']),
        CompanyExitFacts(companyId: 'b', companyName: 'B', readable: true, ownerUids: <String>['me', 'x']),
        CompanyExitFacts(companyId: 'c', companyName: 'C', readable: true, ownerUids: <String>['me'], pendingInviteCodes: <String>['K7Q2MD']),
        CompanyExitFacts(companyId: 'd', companyName: 'D'),
      ]);
      for (final p in <String>['companies/b', 'companies/c', 'invites/K7Q2MD']) {
        await db.doc(p).set(<String, Object?>{'ownerUids': <String>['me']});
      }
      await repo.commitExit('me', plan);
      expect(paths, isNotEmpty);
      for (final p in paths) {
        expect(
          RegExp('/(transactions|contracts|installments|borrowers)/').hasMatch(p),
          isFalse,
          reason: p,
        );
      }
      expect(paths, contains('companies/c'));
      expect(paths, contains('invites/K7Q2MD'));
      expect(paths, isNot(contains('companies/a')));
    });

    test('S8-A8 commitExit refuses a blocked plan', () async {
      final repo = AccountRepository(firestore: FakeFirebaseFirestore());
      final plan = AccountExitPlan('me', const <CompanyExitFacts>[
        CompanyExitFacts(companyId: 'a', companyName: 'A', readable: true, ownerUids: <String>['me'], otherMembers: 2),
      ]);
      expect(plan.isBlocked, isTrue);
      expect(plan.blocked.single.description, contains('2 other members'));
      await expectLater(
        repo.commitExit('me', plan),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  // Screens the developer's sprint8_responsive_test did not cover. Any
  // RenderFlex overflow or layout exception fails the test.
  group('responsive (missed by sprint8_responsive_test)', () {
    Future<void> scrollToEnd(WidgetTester tester) async {
      final s = find.byWidgetPredicate(
        (Widget w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      for (var i = 0; i < s.evaluate().length; i++) {
        final pos = tester.state<ScrollableState>(s.at(i)).position;
        if (!pos.hasContentDimensions || pos.maxScrollExtent <= 0) continue;
        pos.jumpTo(pos.maxScrollExtent);
        await tester.pump();
      }
    }

    for (final (double w, double scale, double h) in <(double, double, double)>[
      (360, 1.3, 740),
      (1024, 1, 768),
    ]) {
      final label = '@${w.toInt()} ×$scale';

      testWidgets('S8-R1 Members & invites $label', (WidgetTester tester) async {
        await pumpSettingsApp(
          tester,
          width: w,
          height: h,
          textScale: scale,
          owners: const <String>[kAshaUid, 'uid-ravi'],
          otherMembers: const <String>['uid-ravi', 'uid-kumar'],
        );
        await tapSetting(tester, 'settings_members');
        expect(find.byType(MembersScreen), findsOneWidget);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      },
          // S8-B3 fixed in attempt 2: the member tile wraps.
          );

      testWidgets('S8-R2 Terms of service $label', (WidgetTester tester) async {
        await pumpSettingsApp(tester, width: w, height: h, textScale: scale);
        await tapSetting(tester, 'settings_terms');
        expect(find.text('Terms of service'), findsWidgets);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('S8-R3 Settings worst case: blocked banner + offline card '
          '$label', (WidgetTester tester) async {
        final hs = await pumpSettingsApp(
          tester,
          width: w,
          height: h,
          textScale: scale,
          openSettings: false,
        );
        hs.notifications.permissionGranted = false;
        hs.sync.setOnline(value: false);
        await tester.tap(find.text('Settings').last);
        await settle(tester);
        expect(key('notifications_blocked'), findsOneWidget);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('S8-R4 Record Payment deep-link target (overdue loan) '
          '$label', (WidgetTester tester) async {
        final hs = await pumpSettingsApp(
          tester,
          width: w,
          height: h,
          textScale: scale,
          openSettings: false,
        );
        await tester.runAsync(
          () => aggregatesFixture().writeTo(hs.db, cid: 'a'),
        );
        await settle(tester);
        final c = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        c.read(pendingDeepLinkProvider.notifier).offer(
          AppRoutes.recordPayment('c2'),
        );
        await settle(tester, 6);
        expect(find.byType(RecordPaymentSheet), findsOneWidget);
        await scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// Records every path a batch writes (and forwards to the fake).
final class _Recording extends FakeFirebaseFirestore {
  _Recording(this._db, this.paths);
  final FakeFirebaseFirestore _db;
  final List<String> paths;

  @override
  DocumentReference<Map<String, dynamic>> doc(String path) => _db.doc(path);

  @override
  WriteBatch batch() => _PathBatch(_db.batch(), paths);
}

final class _PathBatch implements WriteBatch {
  _PathBatch(this._inner, this.paths);
  final WriteBatch _inner;
  final List<String> paths;

  @override
  Future<void> commit() => _inner.commit();

  @override
  void delete(DocumentReference<Object?> document) {
    paths.add(document.path);
    _inner.delete(document);
  }

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    paths.add(document.path);
    _inner.set(document, data, options);
  }

  @override
  void update<T>(DocumentReference<T> document, T data) {
    paths.add(document.path);
    _inner.update(document, data);
  }
}
