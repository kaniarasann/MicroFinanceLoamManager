import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/firebase/firestore_paths.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/company/data/members_repository.dart';
import 'package:nordic_ledger/features/company/presentation/widgets/company_switcher_sheet.dart';
import 'package:nordic_ledger/features/company/presentation/widgets/invite_form_card.dart';
import 'package:nordic_ledger/features/company/presentation/widgets/role_pill.dart';

import '../../auth/auth_fakes.dart';
import '../company_switcher_test.dart' show pumpLocked, unlock;
import '../members_screen_test.dart' show pumpMembers;

void main() {
  testWidgets(
    'collector: no invite card, no send buttons, no revoke, no kebab',
    (WidgetTester tester) async {
      await pumpMembers(tester, width: 400, role: 'collector');
      expect(find.byType(InviteFormCard), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('invite_send_whatsapp')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey<String>('invite_name')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('invite_revoke_PEND22')),
        findsNothing,
      );
      expect(find.textContaining('PEND22'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    },
  );

  testWidgets(
    'last owner: Remove disabled, but Remove on a collector enabled',
    (WidgetTester tester) async {
      await pumpMembers(tester, width: 1200);
      final mine = find.byKey(ValueKey<String>('member_menu_${kAsha.uid}'));
      await tester.ensureVisible(mine);
      await tester.tap(mine);
      await tester.pumpAndSettle();
      final remove = tester.widget<PopupMenuItem<Object?>>(
        find.byKey(const ValueKey<String>('menu_remove')),
      );
      expect(remove.enabled, isFalse);
      expect(find.text(LastOwnerGuard.message), findsWidgets);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      final meena = find.byKey(const ValueKey<String>('member_menu_uid-meena'));
      await tester.ensureVisible(meena);
      await tester.tap(meena);
      await tester.pumpAndSettle();
      final removeMeena = tester.widget<PopupMenuItem<Object?>>(
        find.byKey(const ValueKey<String>('menu_remove')),
      );
      expect(removeMeena.enabled, isTrue);
    },
  );

  testWidgets('last owner: repository also rejects remove / demote', (
    WidgetTester tester,
  ) async {
    final (h, _) = await pumpMembers(tester, width: 400);
    final repo = MembersRepository(firestore: h.db);
    await tester.runAsync(() async {
      await expectLater(
        repo.removeMember('a', kAsha.uid),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        repo.changeRole('a', kAsha.uid, Role.collector),
        throwsA(isA<ValidationFailure>()),
      );
      final m = await h.db.doc('companies/a/members/${kAsha.uid}').get();
      expect(m.exists, isTrue);
      expect(m.data()!['role'], 'owner');
    });
  });

  testWidgets(
    'switcher lists both companies, each row with its own role pill',
    (WidgetTester tester) async {
      final h = await pumpLocked(tester, 400);
      await unlock(tester);
      await tester.tap(find.byKey(const ValueKey<String>('company_header')));
      await tester.pumpAndSettle();
      final rowA = find.byKey(const ValueKey<String>('switcher_company_a'));
      final rowB = find.byKey(const ValueKey<String>('switcher_company_b'));
      expect(rowA, findsOneWidget);
      expect(rowB, findsOneWidget);
      expect(
        find.descendant(of: rowA, matching: find.text('A Co')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rowB, matching: find.text('B Co')),
        findsOneWidget,
      );
      final pillA = tester.widget<RolePill>(
        find.descendant(of: rowA, matching: find.byType(RolePill)),
      );
      final pillB = tester.widget<RolePill>(
        find.descendant(of: rowB, matching: find.byType(RolePill)),
      );
      expect(pillA.role, Role.owner);
      expect(pillB.role, Role.collector);
      expect(find.byType(CompanySwitcherSheet), findsOneWidget);

      await tester.tap(rowB);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final s = await h.db.doc(FirestorePaths.userSettings(kAsha.uid)).get();
        expect(s.data()!['activeCompanyId'], 'b');
      });
    },
  );
}
