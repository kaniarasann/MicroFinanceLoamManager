import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/core/widgets/kpi_tile.dart';
import 'package:nordic_ledger/core/widgets/pin_pad.dart';
import 'package:nordic_ledger/features/splash/presentation/theme_gallery_screen.dart';

Future<void> _pump(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: const ThemeGalleryScreen(projectId: 'microfinance-loan-mgr'),
    ),
  );
}

void main() {
  for (final width in <double>[400, 700, 1200]) {
    testWidgets('gallery renders at width $width', (WidgetTester tester) async {
      await _pump(tester, width);

      expect(
        find.text('Nordic Ledger: Firebase connected: microfinance-loan-mgr'),
        findsOneWidget,
      );
      expect(find.byType(KpiTile), findsNWidgets(4));
      expect(find.text('₹22,94,000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pin pad is reachable by scrolling', (WidgetTester tester) async {
    await _pump(tester, 400);
    await tester.scrollUntilVisible(
      find.byType(PinPad),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(PinPad), findsOneWidget);
  });

  testWidgets('gallery renders in phone landscape without overflow', (
    WidgetTester tester,
  ) async {
    const dpr = 2.625;
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = const Size(915 * dpr, 412 * dpr);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const ThemeGalleryScreen(projectId: 'microfinance-loan-mgr'),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final (i, d) in ThemeGalleryScreen.destinations.indexed) {
      expect(
        find
            .descendant(
              of: find.byType(NavigationRail),
              // Destination 0 is selected and shows its selectedIcon.
              matching: find.byIcon(i == 0 ? d.selectedIcon! : d.icon),
            )
            .hitTestable(),
        findsOneWidget,
      );
    }
    expect(find.text('Outstanding on active loans'), findsOneWidget);
  });
}
