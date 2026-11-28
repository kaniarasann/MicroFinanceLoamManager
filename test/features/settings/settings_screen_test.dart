import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/features/auth/data/mpin_store.dart';
import 'package:nordic_ledger/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:nordic_ledger/features/company/presentation/members_screen.dart';
import 'package:nordic_ledger/features/settings/presentation/screens/legal_screen.dart';
import 'package:nordic_ledger/features/settings/presentation/screens/settings_screen.dart';
import 'package:nordic_ledger/features/settings/presentation/widgets/notification_settings_group.dart';

import 'settings_test_support.dart';

Finder key(String k) => find.byKey(ValueKey<String>(k));

void main() {
  for (final (double width, double scale) in <(double, double)>[
    (400, 1),
    (1024, 1),
    (360, 1.3),
  ]) {
    testWidgets('Settings lays out @${width.toInt()} ×$scale', (
      WidgetTester tester,
    ) async {
      await pumpSettingsApp(tester, width: width, textScale: scale);
      expect(find.byType(SettingsScreen), findsOneWidget);
      for (final k in <String>[
        'settings_profile',
        'settings_sync',
        'settings_company',
        'settings_members',
        'notif_digest',
        'notif_installment',
        'notif_overdue',
        'settings_change_mpin',
        'settings_biometric',
        'settings_autolock',
        'settings_privacy',
        'settings_terms',
        'settings_version',
        'settings_sign_out',
        'settings_delete_account',
      ]) {
        await tester.ensureVisible(key(k));
        await tester.pump();
        expect(key(k), findsOneWidget, reason: k);
      }
      expect(tester.takeException(), isNull);
      if (width >= 840) {
        // Two columns: Security sits right of the profile card.
        expect(
          tester.getTopLeft(key('settings_change_mpin')).dx,
          greaterThan(tester.getTopRight(key('settings_profile')).dx),
        );
      }
    });
  }

  testWidgets('copy: reminders are device notifications, never borrower SMS', (
    WidgetTester tester,
  ) async {
    await pumpSettingsApp(tester);
    expect(find.text(NotificationSettingsGroup.footnote), findsOneWidget);
    expect(find.textContaining('SMS'), findsNothing);
    expect(find.textContaining('SQLite'), findsNothing);
    expect(find.textContaining('All changes synced'), findsOneWidget);
    expect(find.text('Asha Rao'), findsNothing); // member doc name wins
    expect(find.text(kAsha.uid), findsOneWidget);
    expect(find.text('Members & invites'), findsOneWidget);
    expect(find.text('1 member'), findsOneWidget);
  });

  testWidgets('a collector sees "Members"', (WidgetTester tester) async {
    await pumpSettingsApp(
      tester,
      role: 'collector',
      owners: const <String>['uid-owner'],
      otherMembers: const <String>['uid-owner'],
    );
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Members & invites'), findsNothing);
    await tapSetting(tester, 'settings_members');
    expect(find.byType(MembersScreen), findsOneWidget);
  });

  testWidgets('toggles write user_settings.notifications', (
    WidgetTester tester,
  ) async {
    final h = await pumpSettingsApp(tester);
    await tapSetting(tester, 'notif_installment');
    await tapSetting(tester, 'notif_overdue');
    final doc = await tester.runAsync(
      () => h.db.doc('user_settings/${kAsha.uid}').get(),
    );
    final n = doc!.data()!['notifications'] as Map<String, dynamic>;
    expect(n['perInstallmentEnabled'], isTrue);
    expect(n['overdueNudgeEnabled'], isFalse);
    expect(n['digestEnabled'], isTrue);
    expect(n['digestTime'], '08:00');
    expect(doc.data()!['activeCompanyId'], 'a'); // merge kept it
    final s = tester.widget<Switch>(
      find.descendant(
        of: key('notif_installment'),
        matching: find.byType(Switch),
      ),
    );
    expect(s.value, isTrue);
  });

  testWidgets('the time chip opens the IST time picker', (
    WidgetTester tester,
  ) async {
    await pumpSettingsApp(tester);
    expect(find.text('8:00 AM'), findsOneWidget);
    await tapSetting(tester, 'notif_time');
    expect(find.text('Digest time (IST)'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
  });

  testWidgets('blocked notifications show an Allow action', (
    WidgetTester tester,
  ) async {
    tester.view.reset();
    final h = await pumpSettingsApp(tester);
    h.notifications.permissionGranted = false;
    // Re-read the permission.
    await tester.tap(find.text('Dashboard'));
    await settle(tester);
    await tester.tap(find.text('Settings').last);
    await settle(tester);
    expect(key('notifications_blocked'), findsOneWidget);
    final before = h.notifications.permissionRequests;
    await tapSetting(tester, 'notifications_allow');
    expect(h.notifications.permissionRequests, before + 1);
  });

  testWidgets('auto-lock picker stores the device-local delay', (
    WidgetTester tester,
  ) async {
    final h = await pumpSettingsApp(tester);
    expect(find.text('After 1 min'), findsOneWidget);
    await tapSetting(tester, 'settings_autolock');
    expect(key('autolock_sheet'), findsOneWidget);
    await tester.tap(key('autolock_5'));
    await settle(tester);
    expect(h.storage.values[MpinStore.autoLockKey(kAsha.uid)], '5');
    expect(find.text('After 5 min'), findsOneWidget);
  });

  testWidgets('biometric toggle runs a prompt before enabling', (
    WidgetTester tester,
  ) async {
    final h = await pumpSettingsApp(tester, biometricAvailable: true);
    await tapSetting(tester, 'settings_biometric');
    expect(h.biometric.authCalls, 1);
    expect(h.storage.values[MpinStore.biometricKey(kAsha.uid)], 'true');
    await tapSetting(tester, 'settings_biometric');
    expect(h.storage.values[MpinStore.biometricKey(kAsha.uid)], 'false');
  });

  testWidgets('biometric off and disabled when the phone has none', (
    WidgetTester tester,
  ) async {
    await pumpSettingsApp(tester);
    expect(find.text('Not set up on this phone'), findsOneWidget);
    final s = tester.widget<Switch>(
      find.descendant(
        of: key('settings_biometric'),
        matching: find.byType(Switch),
      ),
    );
    expect(s.onChanged, isNull);
  });

  testWidgets('privacy and terms open in-app pages', (
    WidgetTester tester,
  ) async {
    await pumpSettingsApp(tester);
    await tapSetting(tester, 'settings_privacy');
    expect(find.byType(LegalScreen), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    await tapSetting(tester, 'settings_terms');
    expect(find.text('Terms of service'), findsOneWidget);
  });

  testWidgets('sign out asks first, cancels notifications, signs out', (
    WidgetTester tester,
  ) async {
    final h = await pumpSettingsApp(tester);
    await tapSetting(tester, 'settings_sign_out');
    expect(key('sign_out_dialog'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(h.repo.signOutCalls, 0);

    await tapSetting(tester, 'settings_sign_out');
    await tester.tap(key('sign_out_confirm'));
    await settle(tester);
    expect(h.repo.signOutCalls, 1);
    expect(h.notifications.cancelCalls, greaterThanOrEqualTo(1));
    expect(h.notifications.scheduled, isEmpty);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('sync card: offline, waiting to sync, synced', (
    WidgetTester tester,
  ) async {
    final h = await pumpSettingsApp(tester);
    expect(key('sync_synced'), findsOneWidget);

    h.sync.addPending();
    await settle(tester, 2);
    expect(key('sync_pending'), findsOneWidget);
    expect(find.text('Changes waiting to sync'), findsOneWidget);

    h.sync.setOnline(value: false);
    await settle(tester, 2);
    expect(find.text('Offline · changes will sync'), findsOneWidget);

    h.sync.setOnline(value: true);
    h.sync.flush();
    await settle(tester, 2);
    expect(key('sync_synced'), findsOneWidget);
    // FixedClock 10:00 IST.
    expect(find.text('Last synced at 10:00 AM'), findsOneWidget);
  });
}
