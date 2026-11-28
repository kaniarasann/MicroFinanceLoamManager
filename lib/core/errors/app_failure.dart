import 'package:firebase_core/firebase_core.dart';

/// Typed, user-presentable failure. Repositories map raw exceptions to this;
/// UI shows [userMessage], never the raw error.
sealed class AppFailure implements Exception {
  const AppFailure();

  const factory AppFailure.offlineRequired() = OfflineRequiredFailure;
  const factory AppFailure.permissionDenied() = PermissionDeniedFailure;
  const factory AppFailure.validation(String field, String message) =
      ValidationFailure;
  const factory AppFailure.notFound() = NotFoundFailure;
  const factory AppFailure.expired() = ExpiredFailure;
  const factory AppFailure.inviteUnavailable() = InviteUnavailableFailure;
  const factory AppFailure.unknown(Object? cause, [StackTrace? stackTrace]) =
      UnknownFailure;

  String get userMessage;

  @override
  String toString() => '$runtimeType: $userMessage';
}

/// The action needs a network connection (e.g. invite accept).
final class OfflineRequiredFailure extends AppFailure {
  const OfflineRequiredFailure();

  @override
  String get userMessage =>
      'You need to be online to do this. Connect and try again.';
}

/// A write that is saved on this device but not yet acknowledged by the
/// server (it was sent while offline). [ack] completes when the server
/// confirms it, or fails if the server rejects it.
final class AckPendingFailure extends OfflineRequiredFailure {
  AckPendingFailure(this.ack);

  final Future<void> ack;

  @override
  String get userMessage =>
      "Saved on this phone. It will finish when you're back online.";
}

final class PermissionDeniedFailure extends AppFailure {
  const PermissionDeniedFailure();

  @override
  String get userMessage => "You don't have permission to do this.";
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(this.field, this.message);

  final String field;
  final String message;

  @override
  String get userMessage => message;
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure();

  @override
  String get userMessage => "We couldn't find that. It may have been removed.";
}

final class ExpiredFailure extends AppFailure {
  const ExpiredFailure();

  @override
  String get userMessage => 'This has expired. Ask for a new one.';
}

/// An invite that was already used or was revoked by the owner.
final class InviteUnavailableFailure extends AppFailure {
  const InviteUnavailableFailure();

  @override
  String get userMessage =>
      'This invite has already been used or was revoked. Ask the owner '
      'for a new code.';
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure(this.cause, [this.stackTrace]);

  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String get userMessage => 'Something went wrong. Please try again.';
}

/// Maps a Firebase (Firestore/Auth) exception, or anything else, to an
/// [AppFailure]. Existing [AppFailure]s pass through unchanged.
AppFailure mapFirebaseException(Object error, [StackTrace? stackTrace]) {
  if (error is AppFailure) return error;
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return const OfflineRequiredFailure();
      case 'permission-denied':
      case 'unauthenticated':
        return const PermissionDeniedFailure();
      case 'not-found':
      case 'user-not-found':
        return const NotFoundFailure();
      case 'expired-action-code':
      case 'user-token-expired':
      case 'requires-recent-login':
        return const ExpiredFailure();
      case 'invalid-argument':
      case 'failed-precondition':
        // Raw Firebase messages are never shown to users.
        return const ValidationFailure('', 'Some details are not valid.');
    }
  }
  return UnknownFailure(error, stackTrace);
}
