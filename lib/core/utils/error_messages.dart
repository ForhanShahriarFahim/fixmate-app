import 'package:cloud_functions/cloud_functions.dart';
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
      default:
        return error.message ?? 'Authentication failed.';
    }
  }
  if (error is FirebaseFunctionsException) {
    return error.message ?? 'The requested action could not be completed.';
  }
  if (error is ArgumentError || error is StateError) {
    return error.toString().split(': ').last;
  }
  return 'Something went wrong. Please try again.';
}
