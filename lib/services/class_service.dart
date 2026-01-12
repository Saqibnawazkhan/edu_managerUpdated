import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/class_model.dart';

class ClassService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all classes for current user
  Stream<List<ClassModel>> getClasses() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('classes')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ClassModel.fromFirestore(doc);
      }).toList();
    });
  }

  // Add a new class
  // Returns class ID on success, or error string prefixed with 'error:' on failure
  Future<String> addClass(String name) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return 'error:User not authenticated';
      }

      final docRef = await _firestore.collection('classes').add({
        'name': name,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      notifyListeners();
      return docRef.id;
    } catch (e) {
      return 'error:${e.toString()}';
    }
  }

  // Update class name
  Future<String?> updateClass(String classId, String name) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'name': name,
      });

      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Delete a class
  Future<String?> deleteClass(String classId) async {
    try {
      // Delete the class
      await _firestore.collection('classes').doc(classId).delete();

      // Also delete all students in this class
      final studentsSnapshot = await _firestore
          .collection('students')
          .where('classId', isEqualTo: classId)
          .get();

      for (var doc in studentsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete all attendance records for this class
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .get();

      for (var doc in attendanceSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete all marks records for this class
      final marksSnapshot = await _firestore
          .collection('marks')
          .where('classId', isEqualTo: classId)
          .get();

      for (var doc in marksSnapshot.docs) {
        await doc.reference.delete();
      }

      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Get a single class
  Future<ClassModel?> getClass(String classId) async {
    try {
      final doc = await _firestore.collection('classes').doc(classId).get();

      if (doc.exists) {
        return ClassModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get class count for current user
  Future<int> getClassCount() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return 0;
      }

      final snapshot = await _firestore
          .collection('classes')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}