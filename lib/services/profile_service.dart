import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Update profile name
  Future<String?> updateProfileName(String name) async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = _auth.currentUser;
      if (user == null) return 'User not found';

      // Update Firebase Auth display name
      await user.updateDisplayName(name);

      // Update Firestore user document
      await _firestore.collection('users').doc(user.uid).update({
        'name': name,
      });

      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Failed to update name: $e';
    }
  }

  // Upload profile picture
  Future<String?> uploadProfilePicture(File imageFile) async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = _auth.currentUser;
      if (user == null) return 'User not found';

      // Upload to Firebase Storage
      final storageRef = _storage.ref().child('profile_pictures/${user.uid}.jpg');
      await storageRef.putFile(imageFile);

      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firebase Auth photo URL
      await user.updatePhotoURL(downloadUrl);

      // Update Firestore user document
      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': downloadUrl,
      });

      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Failed to upload picture: $e';
    }
  }

  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      return {
        'name': doc.data()?['name'] ?? user.displayName ?? 'Teacher',
        'email': user.email ?? '',
        'photoUrl': doc.data()?['photoUrl'] ?? user.photoURL,
        'createdAt': doc.data()?['createdAt'],
      };
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }
}