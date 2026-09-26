import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Web Client ID (client_type: 3 in google-services.json) — required for idToken
  static const String _webClientId =
      '975392440887-epqj6i1mdgs0ia5ghp6eruqpi90a3t3n.apps.googleusercontent.com';

  // iOS Client ID from GoogleService-Info.plist
  static const String _iosClientId =
      '975392440887-vj055a8u32itcdv4166e4mhpahqer07c.apps.googleusercontent.com';

  bool _isInitialized = false;

  /// Initialize GoogleSignIn instance for v7+
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await GoogleSignIn.instance.initialize(
        clientId: (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
            ? _iosClientId
            : null,
        serverClientId: _webClientId,
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('GoogleSignIn initialize notice: $e');
    }
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isSignedIn => _auth.currentUser != null;

  String? get userDisplayName => _auth.currentUser?.displayName;
  String? get userEmail => _auth.currentUser?.email;
  String? get userPhotoUrl => _auth.currentUser?.photoURL;
  String? get userId => _auth.currentUser?.uid;

  /// Sign in with Google Account using Firebase Auth federated authentication (v7+ API)
  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        final UserCredential userCredential =
            await _auth.signInWithPopup(googleProvider);
        return userCredential.user;
      } else {
        await initialize();

        // Trigger the authentication flow in google_sign_in 7.x
        final GoogleSignInAccount googleUser =
            await GoogleSignIn.instance.authenticate();

        // Obtain the auth details
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        // Create a new credential with the idToken
        final String? idToken = googleAuth.idToken;
        if (idToken == null) {
          debugPrint('Google Sign-In error: idToken is null.');
          throw FirebaseAuthException(
            code: 'missing-id-token',
            message: 'Failed to retrieve Google identity token.',
          );
        }

        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: idToken,
        );

        // Sign in to Firebase with the Google [UserCredential]
        final UserCredential userCredential =
            await _auth.signInWithCredential(credential);
        return userCredential.user;
      }
    } on GoogleSignInException catch (e) {
      debugPrint('GoogleSignInException during Google Sign-In: ${e.code} - ${e.description}');
      // If user tapped cancel / dismissed sheet with no error description, return null gracefully
      if (e.code == GoogleSignInExceptionCode.canceled &&
          (e.description == null || e.description!.isEmpty)) {
        return null;
      }
      rethrow;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during Google Sign-In: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error during Google Sign-In: $e');
      rethrow;
    }
  }

  /// Guest / Anonymous sign in
  Future<User?> signInAnonymously() async {
    try {
      final UserCredential userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      debugPrint('Anonymous sign-in error: $e');
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }
}
