import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Outcome of an auth attempt: [error] is a message safe to show the user.
typedef AuthResult = ({bool ok, String? error});

const AuthResult _success = (ok: true, error: null);

/// Firebase-backed sign-in. Credentials never touch the CosmicGuide backend —
/// the app sends the resulting ID token and the server verifies it.
class AuthService {
  /// Web client ID from the Firebase console. Android needs it to receive an
  /// ID token from Google Sign-In:
  ///   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  /// iOS OAuth client ID. Optional: when empty the plugin reads `GIDClientID`
  /// from Info.plist, which `flutterfire configure` writes for you.
  static const String _iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  static bool _googleReady = false;

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static bool get isSignedIn => _auth.currentUser != null;

  /// True when the account signs in with a password rather than Google, and so
  /// must be asked for one to re-authenticate.
  static bool get usesPassword =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static Future<void> _ensureGoogleReady() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(
      clientId: _iosClientId.isEmpty ? null : _iosClientId,
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
    _googleReady = true;
  }

  /// Bearer token for the API. Firebase refreshes it automatically when stale.
  static Future<String?> idToken({bool forceRefresh = false}) async {
    try {
      return await _auth.currentUser?.getIdToken(forceRefresh);
    } catch (e) {
      debugPrint('idToken failed: $e');
      return null;
    }
  }

  static Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final trimmed = name.trim();
      if (trimmed.isNotEmpty) {
        await cred.user?.updateDisplayName(trimmed);
      }
      return _success;
    } on FirebaseAuthException catch (e) {
      return (ok: false, error: _message(e));
    } catch (e) {
      return (ok: false, error: _generic(e));
    }
  }

  static Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _success;
    } on FirebaseAuthException catch (e) {
      return (ok: false, error: _message(e));
    } catch (e) {
      return (ok: false, error: _generic(e));
    }
  }

  static Future<AuthResult> signInWithGoogle() async {
    try {
      final google = GoogleSignIn.instance;
      await _ensureGoogleReady();

      if (!google.supportsAuthenticate()) {
        return (
          ok: false,
          error: 'Google sign-in is not available on this device.',
        );
      }

      final account = await google.authenticate();
      final googleIdToken = account.authentication.idToken;
      if (googleIdToken == null) {
        // Almost always a missing/incorrect server client ID.
        return (
          ok: false,
          error:
              'Google did not return a sign-in token. Please try email instead.',
        );
      }

      await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: googleIdToken),
      );
      return _success;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return (ok: false, error: null); // user backed out — not an error
      }
      return (ok: false, error: 'Google sign-in failed. Please try again.');
    } on FirebaseAuthException catch (e) {
      return (ok: false, error: _message(e));
    } catch (e) {
      return (ok: false, error: _generic(e));
    }
  }

  static Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return _success;
    } on FirebaseAuthException catch (e) {
      return (ok: false, error: _message(e));
    } catch (e) {
      return (ok: false, error: _generic(e));
    }
  }

  static Future<void> signOut() async {
    try {
      if (_googleReady) await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Google sign-out skipped: $e');
    }
    await _auth.signOut();
  }

  /// Firebase refuses to delete an account whose sign-in is more than a few
  /// minutes old. Proving identity up front means a delete never fails partway
  /// through, after the server copy is already gone.
  static Future<AuthResult> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) return (ok: false, error: 'You are not signed in.');
    try {
      if (usesPassword) {
        final email = user.email;
        if (email == null) {
          return (ok: false, error: 'This account has no email on file.');
        }
        if (password == null || password.isEmpty) {
          return (ok: false, error: 'Please enter your password.');
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
      } else {
        await _ensureGoogleReady();
        final account = await GoogleSignIn.instance.authenticate();
        final googleIdToken = account.authentication.idToken;
        if (googleIdToken == null) {
          return (ok: false, error: 'Google did not confirm your identity.');
        }
        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(idToken: googleIdToken),
        );
      }
      return _success;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return (ok: false, error: null); // user backed out — not an error
      }
      return (ok: false, error: 'Google sign-in failed. Please try again.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return (ok: false, error: 'That password is incorrect.');
      }
      return (ok: false, error: _message(e));
    } catch (e) {
      return (ok: false, error: _generic(e));
    }
  }

  /// Deletes the Firebase credential. The server deletes its own copy of the
  /// profile separately, so call this only after that succeeds.
  static Future<AuthResult> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
      return _success;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return (
          ok: false,
          error:
              'For your security, please sign in again before deleting your account.',
        );
      }
      // _message() is sign-in copy and would wrongly blame the password here.
      return (
        ok: false,
        error: 'Could not delete your account. Please try again.',
      );
    } catch (e) {
      return (ok: false, error: _generic(e));
    }
  }

  static String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address doesn\'t look right.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for that email. Try signing in.';
      case 'weak-password':
        return 'Please choose a password of at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No connection. Check your network and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled for the app.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }

  static String _generic(Object e) {
    debugPrint('Auth error: $e');
    return 'Something went wrong. Please try again.';
  }
}
