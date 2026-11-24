import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/time/clock_provider.dart';
import 'package:nordic_ledger/domain/ledger/ledger.dart';
import 'package:nordic_ledger/domain/models/models.dart';
import 'package:nordic_ledger/features/company/application/company_providers.dart';
import 'package:nordic_ledger/features/contracts/application/ledger_providers.dart';
import 'package:nordic_ledger/features/dashboard/application/portfolio_providers.dart';

import 'dashboard_test_support.dart';

/// m5: once figures exist for a company, a listener reload keeps them on
/// screen; a company switch starts from loading again.
void main() {
  List<Override> overrides({
    String cid = kCid,
    AsyncValue<List<LedgerTransaction>> historyTx =
        const AsyncData<List<LedgerTransaction>>(<LedgerTransaction>[]),
  }) => <Override>[
    clockProvider.overrideWithValue(fixtureClock()),
    activeCompanyIdProvider.overrideWithValue(AsyncData<String?>(cid)),
    activeProjectionsProvider.overrideWithValue(
      const AsyncData<Map<String, ContractProjection>>(
        <String, ContractProjection>{},
      ),
    ),
    activeTransactionsProvider.overrideWithValue(
      const AsyncData<List<LedgerTransaction>>(<LedgerTransaction>[]),
    ),
    historyContractsProvider.overrideWithValue(
      const AsyncData<List<Contract>>(<Contract>[]),
    ),
    historyTransactionsProvider.overrideWithValue(historyTx),
    historyInstallmentsProvider.overrideWithValue(
      const AsyncData<List<Installment>>(<Installment>[]),
    ),
  ];

  test('a reload keeps the previous figures; a company switch does not', () {
    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    final sub = container.listen(portfolioProvider, (_, _) {});
    addTearDown(sub.close);
    final first = container.read(portfolioProvider);
    expect(first, isA<AsyncData<PortfolioMetrics>>());

    container.updateOverrides(
      overrides(historyTx: const AsyncLoading<List<LedgerTransaction>>()),
    );
    final reloading = container.read(portfolioProvider);
    expect(reloading, isA<AsyncData<PortfolioMetrics>>());
    expect(reloading.value, same(first.value));

    container.updateOverrides(
      overrides(
        cid: 'co-2',
        historyTx: const AsyncLoading<List<LedgerTransaction>>(),
      ),
    );
    expect(
      container.read(portfolioProvider),
      isA<AsyncLoading<PortfolioMetrics>>(),
    );
  });

  test('a listener error surfaces as an error', () {
    final container = ProviderContainer(
      overrides: overrides(
        historyTx: AsyncError<List<LedgerTransaction>>(
          StateError('denied'),
          StackTrace.empty,
        ),
      ),
    );
    addTearDown(container.dispose);
    expect(container.read(portfolioProvider).hasError, isTrue);
  });
}
