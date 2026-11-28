import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/firebase/converters.dart';
import '../../../core/time/ist_clock.dart';
import '../../../domain/models/app_user.dart';

/// The signed-in Firebase user, reduced to what the app needs.
final class AuthUser {
  const AuthUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  /// First word of the display name, or null.
  String? get firstName {
    final name = displayName?.trim();
    if (name == null || name.isEmpty) return null;
    return name.split(RegExp(r'\s+')).first;
  }

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.uid == uid &&
      other.displayName == displayName &&
      other.email == email &&
      other.photoUrl == photoUrl;

  @override
  int get hashCode => Object.hash(uid, displayName, email, photoUrl);
}

/// Google sign-in, Firebase session and the `users/{uid}` profile.
abstract interface class AuthRepository {
  Stream<AuthUser?> authStateChanges();

  AuthUser? get currentUser;

  /// Google → Firebase sign-in. Returns null when the user cancels
  /// (a quiet no-op). Throws [AppFailure] otherwise.
  Future<AuthUser?> signInWithGoogle();

  /// Re-verifies the current user with Google (Forgot MPIN). Returns false
  /// when cancelled. Throws [AppFailure] on failure, including picking a
  /// different Google account.
  Future<bool> reauthenticateWithGoogle();

  /// Signs out of Firebase and Google.
  Future<void> signOut();

  /// Deletes the Firebase Auth user (call right after
  /// [reauthenticateWithGoogle]), then signs out of Google.
  Future<void> deleteAccount();
}

/// Result of a Google authentication: the ID token for Firebase.
final class GoogleIdToken {
  const GoogleIdToken({required this.idToken});

  final String idToken;
}

/// Seam over the google_sign_in v7 singleton.
abstract interface class GoogleSignInGateway {
  /// Shows the Google account picker. Returns null on cancel.
  Future<GoogleIdToken?> authenticate();

  Future<void> signOut();
}

/// google_sign_in v7: `initialize(serverClientId)` once, then
/// `authenticate()`.
final class GoogleSignInV7Gateway implements GoogleSignInGateway {
  GoogleSignInV7Gateway({
    GoogleSignIn? googleSignIn,
    this.serverClientId = AppConfig.googleServerClientId,
  }) : _google = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _google;
  final String serverClientId;
  Future<void>? _initialized;

  Future<void> _ensureInitialized() {
    return _initialized ??= _google
        .initialize(serverClientId: serverClientId)
        .catchError((Object e) {
          _initialized = null; // allow a retry
          throw e;
        });
  }

  @override
  Future<GoogleIdToken?> authenticate() async {
    await _ensureInitialized();
    try {
      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.unknownError,
          description: 'Google returned no ID token',
        );
      }
      return GoogleIdToken(idToken: idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await _google.signOut();
  }
}

/// [AuthRepository] over FirebaseAuth + [GoogleSignInGateway].
final class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required FirebaseAuth auth,
    required GoogleSignInGateway google,
    required FirebaseFirestore firestore,
    required Clock clock,
  }) : _auth = auth,
       _google = google,
       _refs = TypedRefs(firestore),
       _clock = clock;

  final FirebaseAuth _auth;
  final GoogleSignInGateway _google;
  final TypedRefs _refs;
  final Clock _clock;

  static AuthUser? _toAuthUser(User? user) => user == null
      ? null
      : AuthUser(
          uid: user.uid,
          displayName: user.displayName,
          email: user.email,
          photoUrl: user.photoURL,
        );

  @override
  Stream<AuthUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toAuthUser);

  @override
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  @override
  Future<AuthUser?> signInWithGoogle() async {
    try {
      final identity = await _google.authenticate();
      if (identity == null) return null;
      final credential = GoogleAuthProvider.credential(
        idToken: identity.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) throw const UnknownFailure('No Firebase user');
      upsertProfile(user);
      return _toAuthUser(user);
    } on Object catch (e, st) {
      throw _mapAuthError(e, st);
    }
  }

  @override
  Future<bool> reauthenticateWithGoogle() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw const PermissionDeniedFailure();
      final identity = await _google.authenticate();
      if (identity == null) return false;
      final credential = GoogleAuthProvider.credential(
        idToken: identity.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } on Object catch (e, st) {
      throw _mapAuthError(e, st);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _google.signOut();
    } on Object catch (e) {
      // Google may already be signed out; Firebase sign-out still matters.
      developer.log('Google sign-out failed', name: 'auth', error: e);
    }
    try {
      await _auth.signOut();
    } on Object catch (e, st) {
      throw mapFirebaseException(e, st);
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw const PermissionDeniedFailure();
      await user.delete();
    } on Object catch (e, st) {
      throw _mapAuthError(e, st);
    }
    try {
      await _google.signOut();
    } on Object catch (e) {
      developer.log('Google sign-out failed', name: 'auth', error: e);
    }
  }

  /// Fire-and-forget upsert of `users/{uid}`. Never blocks sign-in and
  /// never throws: a pending (offline) or denied write is only logged.
  void upsertProfile(User user) {
    try {
      final profile = AppUser(
        id: user.uid,
        displayName: user.displayName ?? '',
        email: user.email ?? '',
        photoUrl: user.photoURL,
        // The Auth account creation time is stable, so re-upserts are
        // idempotent and never move createdAt.
        createdAt: (user.metadata.creationTime ?? _clock.nowIst()).toUtc(),
      );
      unawaited(
        _refs
            .user(user.uid)
            .set(profile, SetOptions(merge: true))
            .then<void>(
              (_) {},
              onError: (Object e, StackTrace st) => developer.log(
                'users/{uid} upsert failed (continuing)',
                name: 'auth',
                error: e,
                stackTrace: st,
              ),
            ),
      );
    } on Object catch (e, st) {
      developer.log(
        'users/{uid} upsert threw (continuing)',
        name: 'auth',
        error: e,
        stackTrace: st,
      );
    }
  }

  static AppFailure _mapAuthError(Object error, StackTrace stackTrace) {
    if (error is AppFailure) return error;
    if (error is GoogleSignInException) {
      developer.log(
        'Google sign-in failed: ${error.code.name} ${error.description ?? ''}',
        name: 'auth',
      );
      return UnknownFailure(error, stackTrace);
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-mismatch':
          return const ValidationFailure(
            'account',
            'Use the same Google account you signed in with.',
          );
        case 'user-disabled':
          return const PermissionDeniedFailure();
      }
    }
    return mapFirebaseException(error, stackTrace);
  }
}
