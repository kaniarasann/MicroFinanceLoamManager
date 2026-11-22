import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';
import 'package:nordic_ledger/core/widgets/adaptive_scaffold.dart';
import 'package:nordic_ledger/core/widgets/list_detail_layout.dart';

const _destinations = <AdaptiveDestination>[
  AdaptiveDestination(icon: Icons.dashboard_outlined, label: 'Dashboard'),
  AdaptiveDestination(icon: Icons.calendar_month_outlined, label: 'Calendar'),
  AdaptiveDestination(icon: Icons.people_outline, label: 'Borrowers'),
  AdaptiveDestination(icon: Icons.settings_outlined, label: 'Settings'),
];

Future<void> _pumpAt(
  WidgetTester tester,
  double width, {
  Widget body = const Text('Body'),
  Widget? fab,
  ValueChanged<int>? onSelected,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AdaptiveScaffold(
        destinations: _destinations,
        selectedIndex: 0,
        onDestinationSelected: onSelected ?? (_) {},
        floatingActionButton: fab,
        body: body,
      ),
    ),
  );
}

void main() {
  testWidgets('compact (400): NavigationBar', (WidgetTester tester) async {
    final taps = <int>[];
    await _pumpAt(
      tester,
      400,
      onSelected: taps.add,
      body: const SizedBox.expand(key: ValueKey<String>('body')),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await tester.tap(find.text('Borrowers'));
    expect(taps, <int>[2]);

    // 16dp margin.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<String>('body'))).dx,
      16,
    );
  });

  testWidgets('medium (700): NavigationRail without labels', (
    WidgetTester tester,
  ) async {
    await _pumpAt(tester, 700);
    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.labelType, NavigationRailLabelType.none);
  });

  testWidgets('expanded (1000): NavigationRail with labels and FAB', (
    WidgetTester tester,
  ) async {
    await _pumpAt(
      tester,
      1000,
      fab: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
    );

    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.labelType, NavigationRailLabelType.all);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('FAB is hidden on compact', (WidgetTester tester) async {
    await _pumpAt(
      tester,
      400,
      fab: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
    );
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('body is capped at 1280 on very wide windows', (
    WidgetTester tester,
  ) async {
    await _pumpAt(
      tester,
      2000,
      body: const SizedBox.expand(key: ValueKey<String>('body')),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('body'))).width,
      1280 - 2 * 32,
    );
  });

  group('short height (phone landscape 915x412)', () {
    Future<void> pumpLandscape(
      WidgetTester tester, {
      double height = 412,
      ValueChanged<int>? onSelected,
    }) async {
      // Pixel-class phone in landscape: 2.625 dpr, ~915x412 logical.
      const dpr = 2.625;
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = Size(915 * dpr, height * dpr);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdaptiveScaffold(
            destinations: _destinations,
            selectedIndex: 0,
            onDestinationSelected: onSelected ?? (_) {},
            appBar: AppBar(title: const Text('Page title')),
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
            body: const Text('Body'),
          ),
        ),
      );
    }

    testWidgets('no overflow, compact rail, all destinations hittable', (
      WidgetTester tester,
    ) async {
      final taps = <int>[];
      await pumpLandscape(tester, onSelected: taps.add);

      expect(tester.takeException(), isNull);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.labelType, NavigationRailLabelType.none);
      expect(rail.leading, isNull);
      // FAB still available, in the content pane.
      expect(find.byType(FloatingActionButton), findsOneWidget);

      for (final (i, d) in _destinations.indexed) {
        final icon = find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byIcon(d.icon),
        );
        expect(icon, findsOneWidget);
        expect(icon.hitTestable(), findsOneWidget);
        await tester.tap(icon);
        expect(taps.last, i);
      }
    });

    testWidgets('rail starts at the top; title sits in the content pane', (
      WidgetTester tester,
    ) async {
      await pumpLandscape(tester);
      final railTop = tester.getTopLeft(find.byType(NavigationRail));
      final railRight = tester.getTopRight(find.byType(NavigationRail)).dx;
      final title = tester.getTopLeft(find.byType(AppBar));
      expect(railTop.dy, 0);
      expect(title.dx, greaterThanOrEqualTo(railRight));
      expect(tester.getSize(find.byType(NavigationRail)).height, 412);
    });

    testWidgets('very short height scrolls instead of overflowing', (
      WidgetTester tester,
    ) async {
      await pumpLandscape(tester, height: 200);
      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });

  group('ListDetailLayout', () {
    Future<void> pump(WidgetTester tester, double width) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: ListDetailLayout(
              list: Text('List'),
              emptyDetail: Text('Pick one'),
            ),
          ),
        ),
      );
    }

    testWidgets('compact shows list only', (WidgetTester tester) async {
      await pump(tester, 400);
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Pick one'), findsNothing);
    });

    testWidgets('expanded splits 40/60', (WidgetTester tester) async {
      await pump(tester, 1001);
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Pick one'), findsOneWidget);
      expect(find.byType(VerticalDivider), findsOneWidget);
    });
  });
}
