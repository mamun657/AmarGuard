import 'package:firebase_auth/firebase_auth.dart';

enum AuthErrorCode {
  invalidEmail,
  invalidCredentials,
  accountDisabled,
  tooManyAttempts,
  network,
  accountExists,
  weakPassword,
  signupUnavailable,
  generic,
}

class AuthFailure {
  AuthFailure(this.code);

  final AuthErrorCode code;
}

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  FirebaseAuth get raw => _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapSignInError(e));
    } catch (_) {
      throw AuthFailure(AuthErrorCode.generic);
    }
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapRegisterError(e));
    } catch (_) {
      throw AuthFailure(AuthErrorCode.generic);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  AuthErrorCode _mapSignInError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return AuthErrorCode.invalidEmail;
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return AuthErrorCode.invalidCredentials;
      case 'user-disabled':
        return AuthErrorCode.accountDisabled;
      case 'too-many-requests':
        return AuthErrorCode.tooManyAttempts;
      case 'network-request-failed':
        return AuthErrorCode.network;
      default:
        return AuthErrorCode.generic;
    }
  }

  AuthErrorCode _mapRegisterError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return AuthErrorCode.invalidEmail;
      case 'email-already-in-use':
        return AuthErrorCode.accountExists;
      case 'weak-password':
        return AuthErrorCode.weakPassword;
      case 'operation-not-allowed':
        return AuthErrorCode.signupUnavailable;
      case 'network-request-failed':
        return AuthErrorCode.network;
      default:
        return AuthErrorCode.generic;
    }
  }
}