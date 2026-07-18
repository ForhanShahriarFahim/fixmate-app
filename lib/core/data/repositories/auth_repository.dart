import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixmate/core/constants/app_constants.dart';
import 'package:fixmate/core/domain/models.dart';
import 'package:fixmate/core/utils/validators.dart';

class AuthRepository {
  const AuthRepository(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> register({
    required String displayName,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
    required bool isAdultConfirmed,
    required bool acceptedTerms,
  }) async {
    if (!isAdultConfirmed || !acceptedTerms) {
      throw ArgumentError(
        'Age confirmation and Terms acceptance are required.',
      );
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;

    try {
      await user.updateDisplayName(displayName.trim());
      await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
        'displayName': displayName.trim(),
        'email': email.trim().toLowerCase(),
        'phoneE164': Validators.normalizeBangladeshPhone(phone),
        'role': role.name,
        'status': AccountStatus.active.name,
        'photoPath': null,
        'termsVersion': AppConstants.termsVersion,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
        'isAdultConfirmed': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await user.sendEmailVerification();
      return credential;
    } catch (_) {
      await user.delete();
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> resendVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in user.');
    await user.sendEmailVerification();
  }

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> updateBasicProfile({
    required String displayName,
    required String phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in user.');
    await user.updateDisplayName(displayName.trim());
    await _firestore.collection('users').doc(user.uid).update(<String, dynamic>{
      'displayName': displayName.trim(),
      'phoneE164': Validators.normalizeBangladeshPhone(phone),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('No signed-in email account.');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  Future<void> signOut() => _auth.signOut();
}
