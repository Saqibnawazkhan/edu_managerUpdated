import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';

class StudentService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all students for a class
  Stream<List<StudentModel>> getStudents(String classId) {
    return _firestore
        .collection('students')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return StudentModel.fromFirestore(doc);
      }).toList();
    });
  }

  // Check if student with same name exists in class
  Future<bool> studentExistsInClass(String classId, String name) async {
    try {
      final snapshot = await _firestore
          .collection('students')
          .where('classId', isEqualTo: classId)
          .get();

      // Check if any student has the same name (case-insensitive)
      final normalizedName = name.trim().toLowerCase();
      return snapshot.docs.any((doc) {
        final studentName = (doc.data()['name'] as String? ?? '').trim().toLowerCase();
        return studentName == normalizedName;
      });
    } catch (e) {
      return false;
    }
  }

  // Add a new student
  Future<String?> addStudent({
    required String classId,
    required String name,
    required String phoneNo,
    required String fatherPhNo,
    required String motherPhNo,
  }) async {
    try {
      // Check if student with same name already exists
      final exists = await studentExistsInClass(classId, name);
      if (exists) {
        return 'DUPLICATE_STUDENT';
      }

      await _firestore.collection('students').add({
        'classId': classId,
        'name': name,
        'phoneNo': phoneNo,
        'fatherPhNo': fatherPhNo,
        'motherPhNo': motherPhNo,
        'createdAt': FieldValue.serverTimestamp(),
      });
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Update student
  Future<String?> updateStudent({
    required String studentId,
    required String name,
    required String phoneNo,
    required String fatherPhNo,
    required String motherPhNo,
  }) async {
    try {
      await _firestore.collection('students').doc(studentId).update({
        'name': name,
        'phoneNo': phoneNo,
        'fatherPhNo': fatherPhNo,
        'motherPhNo': motherPhNo,
      });
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Delete student
  Future<String?> deleteStudent(String studentId) async {
    try {
      await _firestore.collection('students').doc(studentId).delete();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Get student count for a class
  Future<int> getStudentCount(String classId) async {
    try {
      final snapshot = await _firestore
          .collection('students')
          .where('classId', isEqualTo: classId)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // Get a single student
  Future<StudentModel?> getStudent(String studentId) async {
    try {
      final doc = await _firestore.collection('students').doc(studentId).get();

      if (doc.exists) {
        return StudentModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}