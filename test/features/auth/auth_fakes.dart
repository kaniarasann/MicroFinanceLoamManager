import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nordic_ledger/core/firebase/firebase_providers.dart';
import 'package:nordic_ledger/features/onboarding/application/onboarding_providers.dart';
import 'package:nordic_ledger/features/onboarding/data/install_referrer_source.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/time/clock_provider.dart';
import 'package:nordic_ledger/core/time/ist_clock.dart';
import 'package:nordic_ledger/features/auth/application/auth_providers.dart';
import 'package:nordic_ledger/features/auth/data/auth_repository.dart';
import 'package:nordic_ledger/features/auth/data/biometric_service.dart';
import 'package:nordic_ledger/features/auth/data/mpin_store.dart';
import 'package:nordic_ledger/features/auth/data/secure_key_value_store.dart';

const AuthUser kAsha = AuthUser(
  uid: 'uid-asha',
  displayName: 'Asha Rao',
  email: 'asha@example.com',
);

/// Scriptable [AuthRepository]: behaves like FirebaseAuth's stream (emits the
/// current user on subscribe, then every change).
final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? signedIn}) : _current = signedIn;

  AuthUser? _current;
  final StreamController<AuthUser?> _changes =
      StreamController<AuthUser?>.broadcast();

  /// Who `signInWithGoogle` signs in. Null = the user cancels.
  AuthUser? nextSignIn = kAsha;

  /// Thrown by `signInWithGoogle` when set.
  AppFailure? signInFailure;

  /// `reauthenticateWithGoogle` result / failure.
  bool reauthResult = true;
  AppFailure? reauthFailure;

  int signInCalls = 0;
  int reauthCalls = 0;
  int signOutCalls = 0;

  void emit(AuthUser? user) {
    _current = user;
    _changes.add(user);
  }

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    signInCalls++;
    final failure = signInFailure;
    if (failure != null) throw failure;
    final user = nextSignIn;
    if (user != null) emit(user);
    return user;
  }

  @override
  Future<bool> reauthenticateWithGoogle() async {
    reauthCalls++;
    final failure = reauthFailure;
    if (failure != null) throw failure;
    return reauthResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    emit(null);
  }
}

final class FakeBiometricService implements BiometricService {
  FakeBiometricService({this.available = false, this.result = true});

  bool available;
  bool result;
  int authCalls = 0;

  @override
  Future<bool> canCheck() async => available;

  @override
  Future<bool> authenticate({String reason = ''}) async {
    authCalls++;
    return result;
  }
}

/// Everything an auth test needs, wired into one [ProviderContainer].
final class AuthHarness {
  AuthHarness({
    AuthUser? signedIn,
    bool biometricAvailable = false,
    FixedClock? clock,
  }) : repo = FakeAuthRepository(signedIn: signedIn),
       biometric = FakeBiometricService(available: biometricAvailable),
       clock = clock ?? FixedClock.ist(2026, 11, 21, 10);

  final FakeAuthRepository repo;
  final FakeBiometricService biometric;
  final FixedClock clock;
  final InMemorySecureKeyValueStore storage = InMemorySecureKeyValueStore();

  late final MpinStore mpin = MpinStore(storage);

  /// What the Play install referrer returns (null = none).
  String? installReferrer;

  /// Firestore for the company layer (memberships, settings, member doc).
  final FakeFirebaseFirestore db = FakeFirebaseFirestore();

  List<Override> get overrides => <Override>[
    firestoreProvider.overrideWithValue(db),
    installReferrerSourceProvider.overrideWithValue(
      InstallReferrerSource(storage, read: () async => installReferrer),
    ),
    authRepositoryProvider.overrideWithValue(repo),
    secureKeyValueStoreProvider.overrideWithValue(storage),
    biometricServiceProvider.overrideWithValue(biometric),
    clockProvider.overrideWithValue(clock),
  ];

  ProviderContainer container() {
    final c = ProviderContainer(overrides: overrides);
    addTearDown(c.dispose);
    return c;
  }
}
