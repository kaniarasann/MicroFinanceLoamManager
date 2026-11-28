import 'dart:async';
import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_failure.dart';
import '../data/auth_repository.dart';
import '../data/mpin_store.dart';
import 'auth_providers.dart';

part 'session_controller.g.dart';

/// Where the user is in the sign-in / lock flow. Drives router redirects.
enum AuthStage { loading, signedOut, needsMpinSetup, locked, unlocked }

/// Session + lock state.
final class SessionState {
  const SessionState({
    required this.stage,
    this.user,
    this.message,
    this.biometricEnabled = false,
  });

  final AuthStage stage;
  final AuthUser? user;

  /// One user-facing message (sign-in error, lockout notice). Shown inline
  /// by the screen for the current stage.
  final String? message;

  /// The user opted in to biometric unlock on this device.
  final bool biometricEnabled;

  SessionState copyWith({
    AuthStage? stage,
    AuthUser? user,
    String? message,
    bool clearMessage = false,
    bool? biometricEnabled,
  }) => SessionState(
    stage: stage ?? this.stage,
    user: user ?? this.user,
    message: clearMessage ? null : (message ?? this.message),
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
  );

  @override
  String toString() =>
      'SessionState($stage, uid: ${user?.uid}, message: $message, '
      'biometric: $biometricEnabled)';
}

/// Copy for the forced Google re-auth after too many wrong MPINs.
const String kLockoutMessage =
    'Too many wrong MPIN attempts. Sign in with Google again to set a new '
    'MPIN.';

/// Shown on the sign-in screen after a successful account deletion.
const String kAccountDeletedMessage =
    'Your account was deleted. Loan records you entered stay with your '
    'companies.';

/// Shown when the data was removed but Firebase Auth refused to delete the
/// sign-in itself.
const String kAccountDeletionIncompleteMessage =
    "Your data was removed, but we couldn't delete your Google sign-in. "
    'Contact support to finish.';

/// Owns [AuthStage]:
/// - auth stream null → signedOut;
/// - signed in, no MPIN on this device → needsMpinSetup;
/// - signed in with an MPIN (cold start or fresh sign-in) → locked;
/// - correct MPIN / biometric → unlocked;
/// - lock() (auto-lock) → locked.
@Riverpod(keepAlive: true)
class SessionController extends _$SessionController {
  int _epoch = 0;

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  MpinStore get _mpin => ref.read(mpinStoreProvider);

  @override
  SessionState build() {
    final repo = ref.watch(authRepositoryProvider);
    final sub = repo.authStateChanges().listen(
      (AuthUser? user) => unawaited(_onAuthUser(user)),
      onError: (Object e, StackTrace st) {
        developer.log('Auth stream error', name: 'auth', error: e);
        if (ref.mounted) {
          state = SessionState(
            stage: AuthStage.signedOut,
            message: mapFirebaseException(e, st).userMessage,
          );
        }
      },
    );
    ref.onDispose(sub.cancel);
    return const SessionState(stage: AuthStage.loading);
  }

  Future<void> _onAuthUser(AuthUser? user) async {
    final epoch = ++_epoch;
    if (user == null) {
      // Keep a pending message (e.g. the lockout notice) for the sign-in
      // screen.
      state = SessionState(stage: AuthStage.signedOut, message: state.message);
      return;
    }
    final current = state;
    final sameUserActive =
        current.user?.uid == user.uid &&
        current.stage != AuthStage.loading &&
        current.stage != AuthStage.signedOut;
    if (sameUserActive) {
      state = current.copyWith(user: user);
      return;
    }
    var hasMpin = false;
    var biometric = false;
    try {
      hasMpin = await _mpin.hasMpin(user.uid);
      if (hasMpin) biometric = await _mpin.biometricEnabled(user.uid);
    } on Object catch (e) {
      developer.log('Secure storage read failed', name: 'auth', error: e);
    }
    if (!ref.mounted || epoch != _epoch) return;
    state = SessionState(
      stage: hasMpin ? AuthStage.locked : AuthStage.needsMpinSetup,
      user: user,
      biometricEnabled: biometric,
    );
  }

  /// Google sign-in. Cancel is a quiet no-op; failures set [SessionState.message].
  /// The stage then follows the auth stream.
  Future<void> signInWithGoogle() async {
    state = state.copyWith(clearMessage: true);
    try {
      await _repo.signInWithGoogle();
    } on AppFailure catch (f) {
      if (ref.mounted) state = state.copyWith(message: f.userMessage);
    }
  }

  /// Saves the new MPIN (and biometric choice) and unlocks.
  Future<void> completeMpinSetup(
    String pin, {
    required bool biometricEnabled,
  }) async {
    final user = state.user;
    if (user == null || state.stage != AuthStage.needsMpinSetup) return;
    await _mpin.setMpin(user.uid, pin);
    await _mpin.setBiometricEnabled(user.uid, enabled: biometricEnabled);
    if (!ref.mounted) return;
    state = SessionState(
      stage: AuthStage.unlocked,
      user: user,
      biometricEnabled: biometricEnabled,
    );
  }

  /// Verifies [pin]. On the 5th consecutive failure the MPIN is wiped, the
  /// user is signed out and the stage becomes signedOut with
  /// [kLockoutMessage].
  Future<MpinVerifyResult> unlockWithPin(String pin) async {
    final user = state.user;
    if (user == null || state.stage != AuthStage.locked) {
      return const MpinVerifyResult(ok: false, remaining: 0, lockedOut: false);
    }
    final result = await _mpin.verify(user.uid, pin);
    if (!ref.mounted) return result;
    if (result.ok) {
      state = state.copyWith(stage: AuthStage.unlocked, clearMessage: true);
    } else if (result.lockedOut) {
      await _lockout(user.uid);
    }
    return result;
  }

  /// Biometric unlock. Returns true when it unlocked.
  Future<bool> unlockWithBiometric() async {
    final user = state.user;
    if (user == null ||
        state.stage != AuthStage.locked ||
        !state.biometricEnabled) {
      return false;
    }
    final ok = await ref.read(biometricServiceProvider).authenticate();
    if (!ok || !ref.mounted || state.stage != AuthStage.locked) return false;
    await _mpin.resetFailures(user.uid);
    if (!ref.mounted) return false;
    state = state.copyWith(stage: AuthStage.unlocked, clearMessage: true);
    return true;
  }

  /// "Forgot MPIN?": re-verify with Google, wipe the MPIN, set a new one.
  Future<void> forgotMpin() async {
    final user = state.user;
    if (user == null) return;
    state = state.copyWith(clearMessage: true);
    try {
      final ok = await _repo.reauthenticateWithGoogle();
      if (!ok || !ref.mounted) return;
      await _mpin.clear(user.uid);
      if (!ref.mounted) return;
      state = SessionState(stage: AuthStage.needsMpinSetup, user: user);
    } on AppFailure catch (f) {
      if (ref.mounted) state = state.copyWith(message: f.userMessage);
    }
  }

  /// Change MPIN, step 1: checks the current MPIN while unlocked. Wrong
  /// entries count towards the same 5-try lockout as the unlock screen; the
  /// 5th signs the user out with [kLockoutMessage].
  Future<MpinVerifyResult> verifyCurrentMpin(String pin) async {
    final user = state.user;
    if (user == null || state.stage != AuthStage.unlocked) {
      return const MpinVerifyResult(ok: false, remaining: 0, lockedOut: false);
    }
    final result = await _mpin.verify(user.uid, pin);
    if (!ref.mounted) return result;
    if (result.lockedOut) await _lockout(user.uid);
    return result;
  }

  /// Change MPIN, last step: replaces the MPIN (fresh salt, counter reset).
  /// The biometric opt-in is kept.
  Future<void> changeMpin(String newPin) async {
    final user = state.user;
    if (user == null || state.stage != AuthStage.unlocked) {
      throw StateError('Not unlocked');
    }
    await _mpin.setMpin(user.uid, newPin);
  }

  /// Settings → Biometric unlock. Turning it on runs one real prompt first
  /// and only enables it when that succeeds. Returns the new value.
  Future<bool> setBiometricEnabled({required bool enabled}) async {
    final user = state.user;
    if (user == null || state.stage != AuthStage.unlocked) {
      return state.biometricEnabled;
    }
    if (enabled) {
      final bio = ref.read(biometricServiceProvider);
      if (!await bio.canCheck() || !await bio.authenticate()) {
        return state.biometricEnabled;
      }
    }
    await _mpin.setBiometricEnabled(user.uid, enabled: enabled);
    if (!ref.mounted) return enabled;
    state = state.copyWith(biometricEnabled: enabled);
    return enabled;
  }

  /// Auto-lock: unlocked → locked. No-op in any other stage.
  void lock() {
    if (state.stage == AuthStage.unlocked) {
      state = state.copyWith(stage: AuthStage.locked, clearMessage: true);
    }
  }

  Future<void> signOut() async {
    state = const SessionState(stage: AuthStage.signedOut);
    try {
      await _repo.signOut();
    } on AppFailure catch (f) {
      developer.log('Sign-out failed: ${f.userMessage}', name: 'auth');
    }
  }

  /// Last step of account deletion (the Firestore data is already gone):
  /// wipes this device's MPIN and deletes the Firebase Auth user. Ends
  /// signed out with [kAccountDeletedMessage] (or
  /// [kAccountDeletionIncompleteMessage] when Auth refused).
  Future<void> completeAccountDeletion() async {
    final user = state.user;
    state = const SessionState(
      stage: AuthStage.signedOut,
      message: kAccountDeletedMessage,
    );
    if (user != null) {
      try {
        await _mpin.clear(user.uid);
      } on Object catch (e) {
        developer.log('MPIN clear failed', name: 'auth', error: e);
      }
    }
    try {
      await _repo.deleteAccount();
    } on Object catch (e) {
      developer.log('Auth user delete failed', name: 'auth', error: e);
      if (ref.mounted) {
        state = const SessionState(
          stage: AuthStage.signedOut,
          message: kAccountDeletionIncompleteMessage,
        );
      }
      try {
        await _repo.signOut();
      } on Object catch (e) {
        developer.log('Sign-out failed', name: 'auth', error: e);
      }
    }
  }

  void clearMessage() {
    if (state.message != null) state = state.copyWith(clearMessage: true);
  }

  Future<void> _lockout(String uid) async {
    state = const SessionState(
      stage: AuthStage.signedOut,
      message: kLockoutMessage,
    );
    try {
      await _mpin.clear(uid);
    } on Object catch (e) {
      developer.log('MPIN clear failed', name: 'auth', error: e);
    }
    try {
      await _repo.signOut();
    } on Object catch (e) {
      developer.log('Sign-out after lockout failed', name: 'auth', error: e);
    }
  }
}
