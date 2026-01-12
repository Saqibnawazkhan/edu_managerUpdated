import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';

class StatisticsService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Get class statistics
  Future<Map<String, dynamic>> getClassStatistics(String classId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get all students in the class
      final studentsSnapshot = await _firestore
          .collection('students')
          .where('classId', isEqualTo: classId)
          .get();

      List<StudentModel> students = studentsSnapshot.docs
          .map((doc) => StudentModel.fromFirestore(doc))
          .toList();

      // Get attendance for each student
      Map<String, Map<String, int>> studentStats = {};

      for (var student in students) {
        final attendanceSnapshot = await _firestore
            .collection('attendance')
            .where('studentId', isEqualTo: student.id)
            .get();

        Map<String, int> stats = {
          'present': 0,
          'absent': 0,
          'late': 0,
          'sick': 0,
        };

        for (var doc in attendanceSnapshot.docs) {
          final attendance = AttendanceModel.fromFirestore(doc);
          stats[attendance.status] = (stats[attendance.status] ?? 0) + 1;
        }

        studentStats[student.id] = stats;
      }

      _isLoading = false;
      notifyListeners();

      return {
        'students': students,
        'studentStats': studentStats,
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'students': [],
        'studentStats': {},
      };
    }
  }

  // Get attendance statistics for a single student
  Future<Map<String, int>> getStudentAttendanceStats(String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .get();

      Map<String, int> stats = {
        'present': 0,
        'absent': 0,
        'late': 0,
        'sick': 0,
        'short_leave': 0,
      };

      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] as String;
        stats[status] = (stats[status] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('Error getting student attendance stats: $e');
      return {
        'present': 0,
        'absent': 0,
        'late': 0,
        'sick': 0,
        'short_leave': 0,
      };
    }
  }

  // Get attendance percentage for a student
  Future<double> getAttendancePercentage(String studentId) async {
    try {
      final stats = await getStudentAttendanceStats(studentId);
      final total = stats.values.reduce((a, b) => a + b);
      final present = stats['present'] ?? 0;

      if (total == 0) return 0.0;
      return (present / total) * 100;
    } catch (e) {
      return 0.0;
    }
  }
}