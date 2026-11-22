import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/theme/app_theme.dart';

/// Pumps [child] inside a themed MaterialApp, optionally at a logical
/// window [width] (dp).
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  double? width,
  double height = 900,
  bool wrapInScaffold = true,
}) async {
  if (width != null) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: wrapInScaffold ? Scaffold(body: Center(child: child)) : child,
    ),
  );
}
