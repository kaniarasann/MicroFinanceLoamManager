import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show ValueKey;
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/payments/application/payment_providers.dart';

import '../../contracts/contract_test_support.dart';
import '../payment_widget_harness.dart';

/// Tester S6: role gating on Reverse / Rollover, the excess banner after
/// two "offline" payments from different devices, the receipt text.
void main() {
  testWidgets('collector: no Reverse anywhere on the ledger, no Rollover', (
    WidgetTester t,
  ) async {
    await pumpPayments(
      t,
      initial: '/contracts/c1',
      height: 6000,
      role: Role.collector,
    );
    expect(find.byKey(k('payment_ledger')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('reverse_'),
      ),
      findsNothing,
    );
    expect(find.text('Rollover'), findsNothing);
  });

  testWidgets('collector: the pay sheet has no Rollover segment', (
    WidgetTester t,
  ) async {
    await pumpPayments(t, role: Role.collector);
    expect(find.text('Rollover'), findsNothing);
    expect(find.byKey(k('rollover_card')), findsNothing);
  });

  testWidgets('two devices collect offline past the balance → excess banner', (
    WidgetTester t,
  ) async {
    final seed = stitchSeed();
    final c = seed.contracts.single;
    seed.transactions
      ..add(txFor(c, 'tx-a', 40000, d(2023, 12, 1)).copyWith(deviceId: 'A'))
      ..add(txFor(c, 'tx-b', 30000, d(2023, 12, 1)).copyWith(deviceId: 'B'));
    await pumpPayments(t, initial: '/contracts/c1', seed: seed);
    expect(
      find.text(
        'Excess collected ₹6,000. Review and reverse the duplicate payment.',
      ),
      findsOneWidget,
    );
  });

  test('receipt text has amount, Loan #, balance and company', () {
    final msg = receiptMessage(
      amount: rs(4000),
      borrowerName: 'Anita Sharma',
      loanNo: 4,
      paidOn: d(2023, 12, 3),
      mode: PaymentMode.upi,
      balance: rs(60000),
      companyName: 'Sharma Finance',
    );
    expect(msg, contains('₹4,000'));
    expect(msg, contains('Loan #'));
    expect(msg, contains('4'));
    expect(msg, contains('Balance: ₹60,000'));
    expect(msg, contains('Sharma Finance'));
    expect(msg, contains('Anita Sharma'));
    expect(msg, contains('3 Dec 2023'));
  });

  test('receipt text without a company has no dangling dash', () {
    final msg = receiptMessage(
      amount: rs(1),
      borrowerName: 'A',
      loanNo: 1,
      paidOn: d(2023, 12, 3),
      mode: PaymentMode.cash,
      balance: rs(0),
      companyName: null,
    );
    expect(msg.trim().endsWith('—'), isFalse);
    expect(msg, contains('Balance: ₹0'));
  });
}
