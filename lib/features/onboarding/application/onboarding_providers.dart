import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/time/clock_provider.dart';
import '../../../core/validation/onboarding_validators.dart';
import '../../auth/application/auth_providers.dart';
import '../data/cache_reset_flag.dart';
import '../data/company_repository.dart';
import '../data/install_referrer_source.dart';
import '../data/invite_repository.dart';
import '../data/user_settings_repository.dart';

part 'onboarding_providers.g.dart';

@Riverpod(keepAlive: true)
CompanyRepository companyRepository(Ref ref) => CompanyRepository(
  firestore: ref.watch(firestoreProvider),
  clock: ref.watch(clockProvider),
);

@Riverpod(keepAlive: true)
InviteRepository inviteRepository(Ref ref) => InviteRepository(
  firestore: ref.watch(firestoreProvider),
  clock: ref.watch(clockProvider),
);

@Riverpod(keepAlive: true)
UserSettingsRepository userSettingsRepository(Ref ref) =>
    UserSettingsRepository(firestore: ref.watch(firestoreProvider));

@Riverpod(keepAlive: true)
CacheResetFlag cacheResetFlag(Ref ref) =>
    CacheResetFlag(ref.watch(secureKeyValueStoreProvider));

@Riverpod(keepAlive: true)
InstallReferrerSource installReferrerSource(Ref ref) =>
    InstallReferrerSource(ref.watch(secureKeyValueStoreProvider));

/// An invite code waiting to pre-fill the join screen: from a `/join?code=`
/// deep link that arrived while locked, or from the Play install referrer.
/// The join screen [take]s it.
@Riverpod(keepAlive: true)
class PendingInviteCode extends _$PendingInviteCode {
  @override
  String? build() => null;

  /// Stores [code] when it is a valid invite code; ignores anything else.
  void offer(String? code) {
    final c = code?.trim().toUpperCase();
    if (c != null && InviteCode.isValid(c) && c != state) state = c;
  }

  /// Returns and clears the pending code.
  String? take() {
    final c = state;
    if (c != null) state = null;
    return c;
  }
}

/// Reads the Play install referrer once per install and offers its code.
/// Watched by the root widget; failures are ignored by the source.
@Riverpod(keepAlive: true)
Future<void> installReferrerBootstrap(Ref ref) async {
  final code = await ref
      .read(installReferrerSourceProvider)
      .readInviteCodeOnce();
  if (code != null && ref.mounted) {
    ref.read(pendingInviteCodeProvider.notifier).offer(code);
  }
}
