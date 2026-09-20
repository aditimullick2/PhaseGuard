import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signInAnonymously() async {
    try {
      await _auth.signInAnonymously();
    } catch (_) {}
  }

  void setAppLifecycleState(bool isInForeground) {
    if (currentUser != null) {
      try {
        _firestore.collection('users').doc(currentUser!.uid).set({
          'isOnline': isInForeground,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<String> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = userCredential.user;
      if (user == null) throw Exception('Failed to create user account');

      // Update display name
      await user.updateDisplayName(name.trim());
      
      // Force token refresh to ensure it propagates to Firestore and local streams don't fail
      await user.getIdToken(true);

      // Create Firestore user document
      final userModel = UserModel(
        uid: user.uid,
        name: name.trim(),
        email: email.trim(),
        isOnline: true,
        lastSeen: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set({
        ...userModel.toMap(),
        'uid': user.uid, // Store uid as a field too for queries
      });

      return 'Success';
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    } catch (e) {
      throw Exception('Sign up failed. Please try again.');
    }
  }

  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = userCredential.user;
      if (user == null) throw Exception('Failed to sign in');

      // Set user as online (use merge to recover missing accounts)
      await _firestore.collection('users').doc(user.uid).set({
        'isOnline': true,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
        'email': email.trim(),
        'uid': user.uid,
        'name': user.displayName ?? email.split('@')[0],
      }, SetOptions(merge: true));

      return 'Success';
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    } catch (e) {
      throw Exception('Sign in failed. Please try again.');
    }
  }

  Future<String> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        throw Exception('Sign in aborted by user');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final User? user = userCredential.user;
      if (user == null) throw Exception('Failed to sign in with Google');

      // Create or update Firestore user document
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        // New user
        final userModel = UserModel(
          uid: user.uid,
          name: user.displayName ?? 'Google User',
          email: user.email ?? '',
          isOnline: true,
          lastSeen: DateTime.now(),
        );

        await _firestore.collection('users').doc(user.uid).set({
          ...userModel.toMap(),
          'uid': user.uid,
        });
      } else {
        // Existing user
        await _firestore.collection('users').doc(user.uid).set({
          'isOnline': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
          'uid': user.uid,
          'name': user.displayName ?? 'Google User',
        }, SetOptions(merge: true));
      }

      return 'Success';
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    } catch (e) {
      if (e.toString().contains('Sign in aborted by user')) {
        throw e;
      }
      throw Exception('Google Sign in failed. Please try again.');
    }
  }

  Future<String> signOut() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'isOnline': false,
            'lastSeen': DateTime.now().millisecondsSinceEpoch,
          }, SetOptions(merge: true));
        } catch (_) {}
      }
      await _auth.signOut();
      return 'Success';
    } catch (e) {
      throw Exception('Sign out failed. Please try again.');
    }
  }

  Future<void> resetPassword(String email) async {
    if (email.isEmpty) throw Exception('Please enter your email to reset password.');
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    } catch (e) {
      throw Exception('Failed to send reset email. Please try again.');
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) return null;

      return UserModel.fromMap(doc.data()!, user.uid);
    } catch (e) {
      return null;
    }
  }

  /// Stream the current user's model in real time.
  Stream<UserModel?> currentUserModelStream() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(null);
      return _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        return UserModel.fromMap(doc.data()!, user.uid);
      }).handleError((error) => null);
    });
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
