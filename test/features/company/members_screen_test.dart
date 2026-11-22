import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/phone/indian_phone.dart';
import 'package:nordic_ledger/core/routing/app_router.dart';
import 'package:nordic_ledger/features/company/application/company_providers.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/auth/application/session_controller.dart';
import 'package:nordic_ledger/features/company/application/members_providers.dart';
import 'package:nordic_ledger/features/company/data/invite_share_service.dart';
import 'package:nordic_ledger/features/company/data/members_repository.dart';
import 'package:nordic_ledger/features/company/presentation/members_screen.dart';
import 'package:nordic_ledger/features/company/presentation/widgets/invite_form_card.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_fakes.dart';
import '../onboarding/onboarding_test_support.dart';

/// Records what the screen asked the platform to open / share / copy.
final class ShareLog {
  final List<Uri> launched = <Uri>[];
  final List<String> shared = <String>[];
  final List<String> copied = <String>[];
  bool launchResult = true;

  InviteShareService service() => InviteShareService(
    launch: (Uri uri, LaunchMode mode) async {
      launched.add(uri);
      return launchResult;
    },
    share: (String text, String subject) async => shared.add(text),
    copy: (String text) async => copied.add(text),
  );
}

const Key _name = ValueKey<String>('invite_name');
const Key _phone = ValueKey<String>('invite_phone');
const Key _whatsApp = ValueKey<String>('invite_send_whatsapp');

Future<(AuthHarness, ShareLog)> pumpMembers(
  WidgetTester tester, {
  required double width,
  String role = 'owner',
  bool withCoOwner = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1400);
  addTearDown(tester.view.reset);
  final h = AuthHarness(signedIn: kAsha);
  final log = ShareLog();
  final owners = <String>[
    if (role == 'owner') kAsha.uid else 'uid-ravi',
    if (withCoOwner) 'uid-ravi',
  ];
  await tester.runAsync(() async {
    await OnboardingFixtures.company(
      h.db,
      cid: 'a',
      name: 'A Co',
      owners: owners,
    );
    await OnboardingFixtures.membership(
      h.db,
      uid: kAsha.uid,
      cid: 'a',
      name: 'A Co',
      role: role,
    );
    await h.db.doc('companies/a/members/${kAsha.uid}').update(<String, Object?>{
      'displayName': 'Asha Rao',
      'phoneE164': '+919845012890',
    });
    await h.db.doc('companies/a/members/uid-meena').set(<String, Object?>{
      'uid': 'uid-meena',
      'role': 'collector',
      'displayName': 'Meena',
      'phoneE164': '+919845012891',
      'status': 'active',
      'inviteCode': 'K7Q2MD',
      'invitedBy': kAsha.uid,
      'joinedAt': DateTime.utc(2026, 11, 2),
      'schemaVersion': 1,
    });
    if (withCoOwner || role != 'owner') {
      await OnboardingFixtures.membership(
        h.db,
        uid: 'uid-ravi',
        cid: 'a',
        name: 'A Co',
      );
    }
    await OnboardingFixtures.invite(
      h.db,
      code: 'PEND22',
      companyId: 'a',
      companyName: 'A Co',
      expiresAt: h.clock.nowIst().toUtc().add(
        const Duration(days: 5, hours: 2),
      ),
    );
  });
  final container = ProviderContainer(
    overrides: <Override>[
      ...h.overrides,
      inviteShareServiceProvider.overrideWithValue(log.service()),
    ],
  );
  addTearDown(container.dispose);
  container.listen(sessionControllerProvider, (_, _) {});
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light, home: const MembersScreen()),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return (h, log);
}

void main() {
  test('/settings/members is reachable once a company is ready', () {
    String? go(CompanyGate gate, AuthStage stage) => appRedirect(
      stage: stage,
      company: gate,
      uri: Uri.parse(AppRoutes.members),
      devRoutes: false,
    );
    expect(go(CompanyGate.ready, AuthStage.unlocked), isNull);
    expect(
      go(CompanyGate.none, AuthStage.unlocked),
      AppRoutes.onboardingRegister,
    );
    expect(go(CompanyGate.ready, AuthStage.locked), AppRoutes.mpin);
  });

  for (final width in <double>[400, 1200]) {
    group('@${width.toInt()}', () {
      testWidgets('owner sees invite form, pending invites and members', (
        WidgetTester tester,
      ) async {
        await pumpMembers(tester, width: width);
        expect(find.text('Members'), findsOneWidget);
        expect(find.text('A Co'), findsOneWidget);
        expect(find.byType(InviteFormCard), findsOneWidget);
        expect(find.text('Invite a staff member'), findsOneWidget);
        expect(
          find.text(inviteRoleDescription(Role.collector)),
          findsOneWidget,
        );
        expect(find.text('Pending invites (1)'), findsOneWidget);
        expect(find.text('Code PEND22 · expires in 6 days'), findsOneWidget);
        expect(find.text('Members (2)'), findsOneWidget);
        expect(find.text('You'), findsOneWidget);
        expect(find.text(IndianPhone.format('+919845012891')), findsOneWidget);
        expect(
          find.byKey(ValueKey<String>('member_menu_${kAsha.uid}')),
          findsOneWidget,
        );
        // Expanded: invite form and lists side by side.
        final form = tester.getTopLeft(find.byType(InviteFormCard));
        final members = tester.getTopLeft(find.text('Members (2)'));
        if (width >= 840) {
          expect(members.dx, greaterThan(form.dx + 200));
        } else {
          expect(members.dy, greaterThan(form.dy));
        }
      });

      testWidgets('collector sees a read-only member list', (
        WidgetTester tester,
      ) async {
        await pumpMembers(tester, width: width, role: 'collector');
        expect(find.byType(InviteFormCard), findsNothing);
        expect(find.textContaining('Pending invites'), findsNothing);
        expect(find.text('Members (3)'), findsOneWidget);
        expect(find.byIcon(Icons.more_vert), findsNothing);
        expect(
          find.text('Only owners can invite staff or change roles.'),
          findsOneWidget,
        );
      });
    });
  }

  testWidgets('invite form validates empty name and bad phone', (
    WidgetTester tester,
  ) async {
    final (h, log) = await pumpMembers(tester, width: 400);
    await tester.tap(find.byKey(_whatsApp));
    await tester.pump();
    expect(find.text("Enter the staff member's name."), findsOneWidget);
    expect(find.text('Enter a mobile number.'), findsOneWidget);

    await tester.enterText(find.byKey(_name), 'Arun');
    await tester.enterText(find.byKey(_phone), '12345');
    await tester.tap(find.byKey(_whatsApp));
    await tester.pump();
    expect(find.text(IndianPhone.invalidMessage), findsOneWidget);
    expect(log.launched, isEmpty);
    final all = await tester.runAsync(() => h.db.collection('invites').get());
    expect(all!.docs, hasLength(1)); // only the seeded one
  });

  testWidgets('send via WhatsApp creates the invite, shows the preview and '
      'opens wa.me', (WidgetTester tester) async {
    final (h, log) = await pumpMembers(tester, width: 400);
    await tester.enterText(find.byKey(_name), 'Arun');
    await tester.enterText(find.byKey(_phone), '98450 12899');
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('invite_role')),
        matching: find.text('Owner'),
      ),
    );
    await tester.pump();
    expect(find.text(inviteRoleDescription(Role.owner)), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(_whatsApp));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump();

    expect(log.launched, hasLength(1));
    final uri = log.launched.single;
    expect(uri.host, 'wa.me');
    expect(uri.path, '/919845012899');
    expect(uri.queryParameters['text'], contains('as Owner'));
    expect(
      find.byKey(const ValueKey<String>('invite_message_preview')),
      findsOneWidget,
    );
    final code = tester
        .widget<Text>(find.byKey(const ValueKey<String>('invite_code_chip')))
        .data!;
    final doc = await tester.runAsync(() => h.db.doc('invites/$code').get());
    expect(doc!['inviteeName'], 'Arun');
    expect(doc['role'], 'owner');

    // Copy code reuses the same invite.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey<String>('invite_copy')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(log.copied, <String>[code]);
    expect(find.text('Invite code $code copied'), findsOneWidget);
    final all = await tester.runAsync(() => h.db.collection('invites').get());
    expect(all!.docs, hasLength(2));
  });

  testWidgets('WhatsApp unavailable suggests SMS', (WidgetTester tester) async {
    final (_, log) = await pumpMembers(tester, width: 400);
    log.launchResult = false;
    await tester.enterText(find.byKey(_name), 'Arun');
    await tester.enterText(find.byKey(_phone), '9845012899');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(_whatsApp));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.textContaining('Try Send via SMS'), findsOneWidget);
  });

  testWidgets('last owner: demote / remove disabled with the explanation', (
    WidgetTester tester,
  ) async {
    await pumpMembers(tester, width: 400);
    expect(
      find.byKey(ValueKey<String>('last_owner_note_${kAsha.uid}')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(ValueKey<String>('member_menu_${kAsha.uid}')),
    );
    await tester.tap(find.byKey(ValueKey<String>('member_menu_${kAsha.uid}')));
    await tester.pumpAndSettle();
    final remove = tester.widget<PopupMenuItem<Object?>>(
      find.byKey(const ValueKey<String>('menu_remove')),
    );
    expect(remove.enabled, isFalse);
    final demote = tester.widget<PopupMenuItem<Object?>>(
      find.byKey(const ValueKey<String>('menu_make_collector')),
    );
    expect(demote.enabled, isFalse);
    expect(find.text(LastOwnerGuard.message), findsOneWidget);
  });

  testWidgets('with a co-owner, the owner can be demoted', (
    WidgetTester tester,
  ) async {
    await pumpMembers(tester, width: 400, withCoOwner: true);
    expect(
      find.byKey(ValueKey<String>('last_owner_note_${kAsha.uid}')),
      findsNothing,
    );
    await tester.ensureVisible(
      find.byKey(ValueKey<String>('member_menu_${kAsha.uid}')),
    );
    await tester.tap(find.byKey(ValueKey<String>('member_menu_${kAsha.uid}')));
    await tester.pumpAndSettle();
    final demote = tester.widget<PopupMenuItem<Object?>>(
      find.byKey(const ValueKey<String>('menu_make_collector')),
    );
    expect(demote.enabled, isTrue);
  });

  testWidgets('revoke asks for confirmation and revokes', (
    WidgetTester tester,
  ) async {
    final (h, _) = await pumpMembers(tester, width: 400);
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('invite_revoke_PEND22')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('invite_revoke_PEND22')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Revoke invite?'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey<String>('confirm_action')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump();
    final doc = await tester.runAsync(() => h.db.doc('invites/PEND22').get());
    expect(doc!['status'], 'revoked');
  });

  testWidgets('remove a collector after confirmation', (
    WidgetTester tester,
  ) async {
    final (h, _) = await pumpMembers(tester, width: 400);
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('member_menu_uid-meena')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('member_menu_uid-meena')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Meena?'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey<String>('confirm_action')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    final doc = await tester.runAsync(
      () => h.db.doc('companies/a/members/uid-meena').get(),
    );
    expect(doc!.exists, isFalse);
  });
}
