import 'package:firebase_auth/firebase_auth.dart';

String friendlyError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already uses this email.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact FixMate support.';
      case 'requires-recent-login':
        return 'For security, sign out and sign in again before continuing.';
      default:
        return error.message ?? 'Authentication failed.';
    }
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'This action is not allowed for your account or booking state.',
      'failed-precondition' =>
        'The action cannot be completed in the current state.',
      'already-exists' => 'That record already exists.',
      'unauthenticated' => 'Your session expired. Sign in again to continue.',
      'aborted' => 'The data changed. Please try the action again.',
      'unavailable' => 'Firebase is temporarily unavailable. Try again.',
      'deadline-exceeded' =>
        'The network request timed out. Check your connection and retry.',
      'resource-exhausted' =>
        'FixMate is temporarily busy. Wait a moment and try again.',
      _ => error.message ?? 'The requested action could not be completed.',
    };
  }
  if (error is ArgumentError || error is StateError) {
    return error.toString().split(': ').last;
  }
  return 'Something went wrong. Please try again.';
}
