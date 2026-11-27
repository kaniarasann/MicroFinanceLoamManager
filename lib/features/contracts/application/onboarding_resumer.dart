import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/models/models.dart';
import '../../company/application/company_providers.dart';
import '../data/contract_repository.dart';
import 'contract_providers.dart';
import 'ledger_providers.dart';

part 'onboarding_resumer.g.dart';

/// One contract's onboarding sync list (live), or null when it has none.
@riverpod
Stream<OnboardingQueue?> onboardingQueue(Ref ref, String contractId) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  if (cid == null) return Stream<OnboardingQueue?>.value(null);
  return ref
      .watch(ledgerSnapshotRepositoryProvider)
      .watchOnboardingQueue(cid, contractId);
}

/// Contract ids with a pending sync list in the active company. Owners
/// only: collectors never resume (the rules are owner only).
@Riverpod(keepAlive: true)
Stream<List<String>> pendingOnboardingQueues(Ref ref) {
  final cid = ref.watch(activeCompanyIdProvider).value;
  final isOwner = ref.watch(currentRoleProvider) == Role.owner;
  if (cid == null || !isOwner) return Stream<List<String>>.value(<String>[]);
  // F5: fire only when the id set changes or local writes reach the server.
  return resumeTriggers(
    ref
        .watch(ledgerSnapshotRepositoryProvider)
        .watchPendingOnboardingQueues(cid),
  );
}

/// Finishes onboardings whose later payments are still in their sync
/// list. Runs at most once per contract at a time on this device.
@Riverpod(keepAlive: true)
OnboardingResumer onboardingResumer(Ref ref) => OnboardingResumer(ref);

class OnboardingResumer {
  OnboardingResumer(this._ref);

  final Ref _ref;
  final Set<String> _running = <String>{};

  /// Resumes [contractId] (owner only). Null when skipped (not an owner,
  /// no company, or already running here).
  Future<ResumeOutcome?> resume(String contractId) async {
    if (_ref.read(currentRoleProvider) != Role.owner) return null;
    final cid = _ref.read(activeCompanyIdProvider).value;
    if (cid == null || !_running.add(contractId)) return null;
    try {
      final actor = await readLedgerActor(_ref);
      final outcome = await _ref
          .read(contractRepositoryProvider)
          .resumeOnboarding(
            ResumeOnboardingCommand(
              cid: cid,
              contractId: contractId,
              actor: actor,
              role: _ref.read(currentRoleProvider),
            ),
          );
      developer.log(
        'resume $contractId: ${outcome.name}',
        name: 'ledger.writes',
      );
      return outcome;
    } on Object catch (e) {
      developer.log('resume $contractId failed: $e', name: 'ledger.writes');
      return ResumeOutcome.offline;
    } finally {
      _running.remove(contractId);
    }
  }

  /// Resumes every contract in [contractIds], one after another.
  Future<void> resumeAll(Iterable<String> contractIds) async {
    for (final id in contractIds.toList()) {
      await resume(id);
    }
  }
}

/// Starts the resumer for owners: on every change of the pending sync
/// lists (including batch 1 reaching the server) and whenever the app
/// comes back to the foreground. Watched by the root widget.
@Riverpod(keepAlive: true)
OnboardingAutoResume onboardingAutoResume(Ref ref) {
  final auto = OnboardingAutoResume(ref);
  ref
    ..listen<AsyncValue<List<String>>>(pendingOnboardingQueuesProvider, (
      _,
      AsyncValue<List<String>> next,
    ) {
      final ids = next.value;
      if (ids != null && ids.isNotEmpty) unawaited(auto.run(ids));
    }, fireImmediately: true)
    ..onDispose(auto.dispose);
  return auto;
}

class OnboardingAutoResume {
  OnboardingAutoResume(this._ref) {
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  final Ref _ref;
  late final AppLifecycleListener _lifecycle;

  Future<void> run(List<String> ids) =>
      _ref.read(onboardingResumerProvider).resumeAll(ids);

  void _onResume() {
    final ids = _ref.read(pendingOnboardingQueuesProvider).value;
    if (ids != null && ids.isNotEmpty) unawaited(run(ids));
  }

  void dispose() => _lifecycle.dispose();
}
