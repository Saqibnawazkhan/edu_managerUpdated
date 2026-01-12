import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/marks_model.dart';

class MarksService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add marks for a student
  Future<String?> addMarks({
    required String classId,
    required String studentId,
    required String assessmentName,
    required String assessmentType,
    required String description,
    required double obtainedMarks,
    required double totalMarks,
    required String date,
  }) async {
    try {
      await _firestore.collection('marks').add({
        'classId': classId,
        'studentId': studentId,
        'assessmentName': assessmentName,
        'assessmentType': assessmentType,
        'description': description,
        'obtainedMarks': obtainedMarks,
        'totalMarks': totalMarks,
        'date': date,
        'createdAt': FieldValue.serverTimestamp(),
      });

      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Get all marks for a student
  Stream<List<MarksModel>> getStudentMarks(String studentId) {
    return _firestore
        .collection('marks')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MarksModel.fromFirestore(doc);
      }).toList();
    });
  }

  // Get all marks for a class
  Stream<List<MarksModel>> getClassMarks(String classId) {
    return _firestore
        .collection('marks')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MarksModel.fromFirestore(doc);
      }).toList();
    });
  }

  // Update marks
  Future<String?> updateMarks({
    required String marksId,
    required String assessmentName,
    required String assessmentType,
    required String description,
    required double obtainedMarks,
    required double totalMarks,
    required String date,
  }) async {
    try {
      await _firestore.collection('marks').doc(marksId).update({
        'assessmentName': assessmentName,
        'assessmentType': assessmentType,
        'description': description,
        'obtainedMarks': obtainedMarks,
        'totalMarks': totalMarks,
        'date': date,
      });

      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Delete marks
  Future<String?> deleteMarks(String marksId) async {
    try {
      await _firestore.collection('marks').doc(marksId).delete();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Get marks statistics for a student
  Future<Map<String, dynamic>> getStudentStats(String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('marks')
          .where('studentId', isEqualTo: studentId)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'totalAssessments': 0,
          'averagePercentage': 0.0,
          'mockCount': 0,
          'assignmentCount': 0,
        };
      }

      int mockCount = 0;
      int assignmentCount = 0;
      double totalPercentage = 0.0;

      for (var doc in snapshot.docs) {
        final marks = MarksModel.fromFirestore(doc);
        totalPercentage += marks.percentage;

        if (marks.assessmentType == 'mock') {
          mockCount++;
        } else if (marks.assessmentType == 'assignment') {
          assignmentCount++;
        }
      }

      return {
        'totalAssessments': snapshot.docs.length,
        'averagePercentage': totalPercentage / snapshot.docs.length,
        'mockCount': mockCount,
        'assignmentCount': assignmentCount,
      };
    } catch (e) {
      return {
        'totalAssessments': 0,
        'averagePercentage': 0.0,
        'mockCount': 0,
        'assignmentCount': 0,
      };
    }
  }

  // Get class statistics
  Future<Map<String, dynamic>> getClassStats(String classId) async {
    try {
      final snapshot = await _firestore
          .collection('marks')
          .where('classId', isEqualTo: classId)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'totalAssessments': 0,
          'averagePercentage': 0.0,
          'mockCount': 0,
          'assignmentCount': 0,
        };
      }

      int mockCount = 0;
      int assignmentCount = 0;
      double totalPercentage = 0.0;

      for (var doc in snapshot.docs) {
        final marks = MarksModel.fromFirestore(doc);
        totalPercentage += marks.percentage;

        if (marks.assessmentType == 'mock') {
          mockCount++;
        } else if (marks.assessmentType == 'assignment') {
          assignmentCount++;
        }
      }

      return {
        'totalAssessments': snapshot.docs.length,
        'averagePercentage': totalPercentage / snapshot.docs.length,
        'mockCount': mockCount,
        'assignmentCount': assignmentCount,
      };
    } catch (e) {
      return {
        'totalAssessments': 0,
        'averagePercentage': 0.0,
        'mockCount': 0,
        'assignmentCount': 0,
      };
    }
  }
}