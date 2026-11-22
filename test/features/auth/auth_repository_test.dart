import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nordic_ledger/core/config/app_config.dart';
import 'package:nordic_ledger/core/errors/app_failure.dart';
import 'package:nordic_ledger/core/time/ist_clock.dart';
import 'package:nordic_ledger/features/auth/data/auth_repository.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserMetadata extends Mock implements UserMetadata {}

class MockUserCredential extends Mock implements UserCredential {}

class MockGateway extends Mock implements GoogleSignInGateway {}

class MockFirestore extends Mock implements FirebaseFirestore {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleAccount extends Mock implements GoogleSignInAccount {}

void main() {
  setUpAll(() {
    registerFallbackValue(GoogleAuthProvider.credential(idToken: 'fallback'));
  });

  late MockFirebaseAuth auth;
  late MockGateway google;
  late FakeFirebaseFirestore db;
  late MockUser user;

  final created = DateTime.utc(2026, 11, 1, 4, 30);

  FirebaseAuthRepository repo({FirebaseFirestore? firestore}) =>
      FirebaseAuthRepository(
        auth: auth,
        google: google,
        firestore: firestore ?? db,
        clock: FixedClock.ist(2026, 11, 21),
      );

  setUp(() {
    auth = MockFirebaseAuth();
    google = MockGateway();
    db = FakeFirebaseFirestore();
    user = MockUser();
    final meta = MockUserMetadata();
    when(() => meta.creationTime).thenReturn(created);
    when(() => user.uid).thenReturn('u1');
    when(() => user.displayName).thenReturn('Asha Rao');
    when(() => user.email).thenReturn('asha@example.com');
    when(() => user.photoURL).thenReturn(null);
    when(() => user.metadata).thenReturn(meta);
    final cred = MockUserCredential();
    when(() => cred.user).thenReturn(user);
    when(() => auth.signInWithCredential(any())).thenAnswer((_) async => cred);
    when(() => google.signOut()).thenAnswer((_) async {});
    when(() => auth.signOut()).thenAnswer((_) async {});
  });

  group('signInWithGoogle', () {
    test('cancel returns null and never touches Firebase', () async {
      when(() => google.authenticate()).thenAnswer((_) async => null);
      expect(await repo().signInWithGoogle(), isNull);
      verifyNever(() => auth.signInWithCredential(any()));
    });

    test('exchanges the ID token and upserts users/{uid}', () async {
      when(
        () => google.authenticate(),
      ).thenAnswer((_) async => const GoogleIdToken(idToken: 'id-token'));

      final result = await repo().signInWithGoogle();
      expect(result?.uid, 'u1');
      expect(result?.firstName, 'Asha');

      final captured =
          verify(() => auth.signInWithCredential(captureAny())).captured.single
              as AuthCredential;
      expect(captured.providerId, 'google.com');

      await pumpEventQueue();
      final doc = await db.doc('users/u1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['displayName'], 'Asha Rao');
      expect(doc.data()!['email'], 'asha@example.com');
      expect((doc.data()!['createdAt'] as Timestamp).toDate().toUtc(), created);
    });

    test('a failing profile write never blocks or crashes sign-in', () async {
      when(
        () => google.authenticate(),
      ).thenAnswer((_) async => const GoogleIdToken(idToken: 'id-token'));
      final broken = MockFirestore();
      when(() => broken.doc(any())).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      final result = await repo(firestore: broken).signInWithGoogle();
      expect(result?.uid, 'u1');
    });

    test('Google configuration errors map to UnknownFailure', () async {
      when(() => google.authenticate()).thenThrow(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
        ),
      );
      expect(repo().signInWithGoogle(), throwsA(isA<UnknownFailure>()));
    });

    test('network errors map to OfflineRequiredFailure', () async {
      when(
        () => google.authenticate(),
      ).thenAnswer((_) async => const GoogleIdToken(idToken: 'id-token'));
      when(
        () => auth.signInWithCredential(any()),
      ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));
      expect(repo().signInWithGoogle(), throwsA(isA<OfflineRequiredFailure>()));
    });
  });

  group('reauthenticateWithGoogle', () {
    test('re-verifies the current user', () async {
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => google.authenticate(),
      ).thenAnswer((_) async => const GoogleIdToken(idToken: 'id-token'));
      when(
        () => user.reauthenticateWithCredential(any()),
      ).thenAnswer((_) async => MockUserCredential());
      expect(await repo().reauthenticateWithGoogle(), isTrue);
      verify(() => user.reauthenticateWithCredential(any())).called(1);
    });

    test('cancel returns false', () async {
      when(() => auth.currentUser).thenReturn(user);
      when(() => google.authenticate()).thenAnswer((_) async => null);
      expect(await repo().reauthenticateWithGoogle(), isFalse);
    });

    test('a different Google account is a validation failure', () async {
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => google.authenticate(),
      ).thenAnswer((_) async => const GoogleIdToken(idToken: 'id-token'));
      when(
        () => user.reauthenticateWithCredential(any()),
      ).thenThrow(FirebaseAuthException(code: 'user-mismatch'));
      expect(
        repo().reauthenticateWithGoogle(),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('no signed-in user is permission denied', () async {
      when(() => auth.currentUser).thenReturn(null);
      expect(
        repo().reauthenticateWithGoogle(),
        throwsA(isA<PermissionDeniedFailure>()),
      );
    });
  });

  group('signOut and auth state', () {
    test('signs out of Google and Firebase', () async {
      await repo().signOut();
      verify(() => google.signOut()).called(1);
      verify(() => auth.signOut()).called(1);
    });

    test('a Google sign-out error still signs out of Firebase', () async {
      when(() => google.signOut()).thenThrow(Exception('already out'));
      await repo().signOut();
      verify(() => auth.signOut()).called(1);
    });

    test('authStateChanges maps Firebase users', () async {
      when(
        () => auth.authStateChanges(),
      ).thenAnswer((_) => Stream<User?>.fromIterable(<User?>[null, user]));
      final events = await repo().authStateChanges().toList();
      expect(events.first, isNull);
      expect(events.last?.uid, 'u1');
    });
  });

  group('GoogleSignInV7Gateway', () {
    late MockGoogleSignIn gsi;

    setUp(() {
      gsi = MockGoogleSignIn();
      when(
        () => gsi.initialize(serverClientId: any(named: 'serverClientId')),
      ).thenAnswer((_) async {});
    });

    test(
      'initializes once with the web client id, returns the ID token',
      () async {
        final account = MockGoogleAccount();
        when(
          () => account.authentication,
        ).thenReturn(const GoogleSignInAuthentication(idToken: 'tok'));
        when(() => gsi.authenticate()).thenAnswer((_) async => account);

        final gateway = GoogleSignInV7Gateway(googleSignIn: gsi);
        expect((await gateway.authenticate())?.idToken, 'tok');
        expect((await gateway.authenticate())?.idToken, 'tok');
        verify(
          () => gsi.initialize(serverClientId: AppConfig.googleServerClientId),
        ).called(1);
      },
    );

    test('a cancelled picker returns null', () async {
      when(() => gsi.authenticate()).thenThrow(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      );
      final gateway = GoogleSignInV7Gateway(googleSignIn: gsi);
      expect(await gateway.authenticate(), isNull);
    });

    test('a missing ID token is an error', () async {
      final account = MockGoogleAccount();
      when(
        () => account.authentication,
      ).thenReturn(const GoogleSignInAuthentication(idToken: null));
      when(() => gsi.authenticate()).thenAnswer((_) async => account);
      final gateway = GoogleSignInV7Gateway(googleSignIn: gsi);
      expect(gateway.authenticate(), throwsA(isA<GoogleSignInException>()));
    });
  });

  test('web client id matches google-services.json client_type 3', () {
    final json =
        jsonDecode(File('android/app/google-services.json').readAsStringSync())
            as Map<String, dynamic>;
    final ids = <String>{
      for (final client in json['client'] as List<dynamic>)
        for (final oauth
            in (client as Map<String, dynamic>)['oauth_client']
                as List<dynamic>)
          if ((oauth as Map<String, dynamic>)['client_type'] == 3)
            oauth['client_id'] as String,
    };
    expect(ids, contains(AppConfig.googleServerClientId));
  });
}
