import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Check if current user is an admin
  Future<bool> isAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data()?['isAdmin'] == true;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  // Register with email and password
  Future<String?> registerWithEmail({
    required String name,
    required String email,
    required String password,
    Map<String, dynamic>? subscriptionData,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        await result.user!.updateDisplayName(name);

        Map<String, dynamic> userData = {
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        };

        // Add subscription data if provided
        if (subscriptionData != null) {
          userData['subscription'] = subscriptionData;
        }

        await _firestore.collection('users').doc(result.user!.uid).set(userData);
      }

      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.code == 'email-already-in-use') return 'Email already exists';
      if (e.code == 'weak-password') return 'Password too weak';
      return e.message ?? 'Registration failed';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Registration error: $e');
      return 'Registration failed';
    }
  }

  // Sign in with email and password
  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _auth.signInWithEmailAndPassword(email: email, password: password);

      // Check if account is disabled
      if (result.user != null) {
        final doc = await _firestore.collection('users').doc(result.user!.uid).get();
        if (doc.exists && doc.data()?['isDisabled'] == true) {
          // Sign out the user immediately
          await _auth.signOut();
          _isLoading = false;
          notifyListeners();
          return 'Account has been disabled. Contact administrator.';
        }

        // Ensure email is saved in Firestore (for users created before email was saved)
        await _firestore.collection('users').doc(result.user!.uid).set({
          'email': email,
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      if (e.code == 'user-not-found') return 'No user found';
      if (e.code == 'wrong-password') return 'Wrong password';
      if (e.code == 'invalid-credential') return 'No user found';
      return e.message ?? 'Login failed';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Login error: $e');
      return 'Login failed';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  // Reset password
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return 'No user found with this email';
      if (e.code == 'invalid-email') return 'Invalid email address';
      return e.message ?? 'Failed to send reset email';
    } catch (e) {
      return 'Failed to send reset email';
    }
  }

  // Change password (requires current password verification)
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return 'No user logged in';
      }

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') return 'Current password is incorrect';
      if (e.code == 'invalid-credential') return 'Current password is incorrect';
      if (e.code == 'weak-password') return 'New password is too weak';
      if (e.code == 'requires-recent-login') return 'Please logout and login again to change password';
      return e.message ?? 'Failed to change password';
    } catch (e) {
      debugPrint('Change password error: $e');
      if (e.toString().contains('invalid-credential') || e.toString().contains('INVALID_LOGIN_CREDENTIALS')) {
        return 'Current password is incorrect';
      }
      return 'Failed to change password';
    }
  }
}