import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/time/clock_provider.dart';
import '../data/auth_repository.dart';
import '../data/biometric_service.dart';
import '../data/mpin_store.dart';
import '../data/secure_key_value_store.dart';

part 'auth_providers.g.dart';

/// Auth / lock dependencies. Tests override these with fakes.
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => FirebaseAuthRepository(
  auth: FirebaseAuth.instance,
  google: GoogleSignInV7Gateway(),
  firestore: ref.watch(firestoreProvider),
  clock: ref.watch(clockProvider),
);

@Riverpod(keepAlive: true)
SecureKeyValueStore secureKeyValueStore(Ref ref) =>
    FlutterSecureKeyValueStore();

@Riverpod(keepAlive: true)
MpinStore mpinStore(Ref ref) =>
    MpinStore(ref.watch(secureKeyValueStoreProvider));

@Riverpod(keepAlive: true)
BiometricService biometricService(Ref ref) => LocalAuthBiometricService();
