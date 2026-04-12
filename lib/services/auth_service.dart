import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      return await _auth.signInWithPopup(googleProvider);
    }

    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: ['email'],
    );

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'google-sign-in-cancelled',
        message: 'Google sign-in was cancelled by the user.',
      );
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
      actionCodeSettings: ActionCodeSettings(
        url: 'https://fir-pos-system.web.app/reset-password',
        handleCodeInApp: false,
      ),
    );
  }

  Future<void> verifyPasswordResetCode(String code) async {
    await _auth.verifyPasswordResetCode(code);
  }

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    await _auth.confirmPasswordReset(
      code: code,
      newPassword: newPassword,
    );
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
    await _auth.signOut();
  }
}