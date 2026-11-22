import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/widgets/pin_pad.dart';

import '../../helpers/pump_app.dart';

Finder _key(String d) => find.byKey(ValueKey<String>('pin_key_$d'));
Finder _dotOn(int i) => find.byKey(ValueKey<String>('pin_dot_${i}_on'));

void main() {
  testWidgets('entering 4 digits calls onCompleted once and clears', (
    WidgetTester tester,
  ) async {
    final completed = <String>[];
    await pumpThemed(tester, PinPad(onCompleted: completed.add));

    for (final d in <String>['1', '9', '0', '4']) {
      await tester.tap(_key(d));
      await tester.pump();
    }

    expect(completed, <String>['1904']);
    expect(_dotOn(0), findsNothing, reason: 'pad resets after completion');
  });

  testWidgets('backspace removes the last digit', (WidgetTester tester) async {
    final completed = <String>[];
    await pumpThemed(tester, PinPad(onCompleted: completed.add));

    await tester.tap(_key('1'));
    await tester.tap(_key('2'));
    await tester.pump();
    expect(_dotOn(1), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('pin_backspace')));
    await tester.pump();
    expect(_dotOn(0), findsOneWidget);
    expect(_dotOn(1), findsNothing);

    await tester.tap(_key('3'));
    await tester.tap(_key('4'));
    await tester.tap(_key('5'));
    await tester.pump();
    expect(completed, <String>['1345']);
  });

  testWidgets('biometric key shown only with onBiometric', (
    WidgetTester tester,
  ) async {
    var bio = 0;
    await pumpThemed(tester, PinPad(onCompleted: (_) {}));
    expect(find.byKey(const ValueKey<String>('pin_biometric')), findsNothing);

    await pumpThemed(
      tester,
      PinPad(onCompleted: (_) {}, onBiometric: () => bio++),
    );
    await tester.tap(find.byKey(const ValueKey<String>('pin_biometric')));
    expect(bio, 1);
  });

  testWidgets('keys are 64dp circles', (WidgetTester tester) async {
    await pumpThemed(tester, PinPad(onCompleted: (_) {}));
    expect(tester.getSize(_key('5')), const Size(64, 64));
  });
}
