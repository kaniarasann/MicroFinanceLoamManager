import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/core/widgets/status_pill.dart';

import '../../helpers/pump_app.dart';

void main() {
  for (final kind in StatusKind.values) {
    testWidgets('${kind.name}: tint background, status text, dot', (
      WidgetTester tester,
    ) async {
      await pumpThemed(tester, StatusPill(label: 'Label', kind: kind));

      final text = tester.widget<Text>(find.text('Label'));
      expect(text.style!.color, kind.foreground);

      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('Label'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, kind.tint);
      expect(decoration.borderRadius, AppRadii.fullAll);

      expect(
        find.byKey(const ValueKey<String>('status_pill_dot')),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(StatusPill)).height,
        greaterThanOrEqualTo(AppSizes.pillHeight),
      );
    });
  }

  testWidgets('icon replaces the dot', (WidgetTester tester) async {
    await pumpThemed(
      tester,
      const StatusPill(
        label: 'Overdue',
        kind: StatusKind.overdue,
        icon: Icons.error_outline,
      ),
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('status_pill_dot')), findsNothing);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.error_outline)).color,
      AppColors.overdue,
    );
  });

  test('kind colours map to tokens', () {
    expect(StatusKind.collected.tint, AppColors.collectedTint);
    expect(StatusKind.upcoming.foreground, AppColors.upcoming);
    expect(StatusKind.overdue.tint, AppColors.overdueTint);
    expect(StatusKind.info.tint, AppColors.primarySubtle);
  });
}
