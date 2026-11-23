import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/time/clock_provider.dart';
import '../../company/application/company_providers.dart';
import '../../contracts/application/contract_draft.dart';
import '../../contracts/application/contract_providers.dart';
import '../../payments/application/payment_providers.dart';
import '../data/rollover_repository.dart';

part 'rollover_providers.g.dart';

@Riverpod(keepAlive: true)
RolloverRepository rolloverRepository(Ref ref) => RolloverRepository(
  firestore: ref.watch(firestoreProvider),
  clock: ref.watch(clockProvider),
);

/// Rollover use-case (owner only; the rules enforce it).
@Riverpod(keepAlive: true)
RolloverActions rolloverActions(Ref ref) => RolloverActions(ref);

class RolloverActions {
  RolloverActions(this._ref);

  final Ref _ref;

  /// Closes [view]'s contract into a new one with [draft]'s terms
  /// (disbursed on the draft's date, normally today). Returns the new id.
  Future<LedgerWriteResult> rollover({
    required ContractView view,
    required ContractDraft draft,
  }) async {
    final actor = await readLedgerActor(_ref);
    final company = _ref.read(activeCompanyProvider).value;
    final c = view.contract;
    return _ref
        .read(rolloverRepositoryProvider)
        .rollover(
          RolloverCommand(
            cid: requireActiveCid(_ref),
            old: view.snapshot,
            sanctioned: draft.sanctioned ?? Money.zero,
            upfrontMode: draft.upfrontMode,
            upfrontInput: draft.upfrontInput ?? 0,
            installmentAmount: draft.installmentAmount ?? Money.zero,
            frequency: draft.frequency,
            preferredWeekday: draft.weekday,
            preferredMonthDay: draft.monthDay,
            firstDueDate: draft.firstDueDate,
            disbursedOn: draft.disbursedOn,
            cachedNextLoanNo: company?.nextLoanNo ?? 0,
            actor: actor,
            guarantor: c.guarantor,
            purpose: c.purpose,
          ),
        );
  }
}
