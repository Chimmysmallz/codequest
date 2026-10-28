import 'package:firebase_auth/firebase_auth.dart';

/// A friendly, UI-ready error thrown by [FirebaseAuthService].
///
/// [FirebaseAuthException] codes are translated into a human-readable
/// [message]; `toString()` returns just that message so screens can surface it
/// directly.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Thin wrapper around [FirebaseAuth.instance].
///
/// Handles email/password accounts and exposes the ID token used to
/// authenticate the FastAPI code-runner backend. Every call that can fail
/// translates [FirebaseAuthException] into a friendly [AuthException].
class FirebaseAuthService {
  final FirebaseAuth _auth;

  FirebaseAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  /// The currently signed-in Firebase user, or null when playing as a guest.
  User? get currentUser => _auth.currentUser;

  /// Emits on sign-in and sign-out (fires immediately with the current user).
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Creates an account (which also signs the user in).
  Future<void> register(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    }
  }

  /// Signs in with an existing email/password account.
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    }
  }

  /// Signs the user out and returns to guest mode.
  Future<void> signOut() => _auth.signOut();

  /// Sends a password-reset email.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    }
  }

  /// The current user's Firebase ID token, or null when signed out.
  ///
  /// Sent to the backend as `Authorization: Bearer <idToken>` so it can verify
  /// the caller with the Firebase Admin SDK.
  Future<String?> idToken() async {
    final user = currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  /// Maps Firebase error codes to kid-friendly, readable messages.
  String _friendlyMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'email-already-in-use':
        return 'That email is already registered. Try logging in instead.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this project.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
