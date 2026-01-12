import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';

class AttendanceService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mark attendance for a student with optional time
  Future<void> markAttendance({
    required String classId,
    required String studentId,
    required String studentName,
    required String status,
    required DateTime date,
    TimeOfDay? time,  // Optional time for multiple sessions
    String? sessionName,  // Optional session name
  }) async {
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // Create document ID with time if provided
    String docId;
    Map<String, dynamic> data;

    if (time != null) {
      final timeString = '${time.hour.toString().padLeft(2, '0')}${time.minute.toString().padLeft(2, '0')}00';
      docId = '${classId}_${studentId}_${dateString}_$timeString';

      final timeFormatted = '${time.hourOfPeriod}:${time.minute.toString().padLeft(2, '0')} ${time.period == DayPeriod.am ? 'AM' : 'PM'}';

      data = {
        'classId': classId,
        'studentId': studentId,
        'studentName': studentName,
        'status': status,
        'date': Timestamp.fromDate(date),
        'time': timeFormatted,
        'sessionName': sessionName ?? timeFormatted,
        'createdAt': FieldValue.serverTimestamp(),
      };
    } else {
      // Backward compatibility
      docId = '${classId}_${studentId}_$dateString';

      data = {
        'classId': classId,
        'studentId': studentId,
        'studentName': studentName,
        'status': status,
        'date': Timestamp.fromDate(date),
        'createdAt': FieldValue.serverTimestamp(),
      };
    }

    await _firestore.collection('attendance').doc(docId).set(data, SetOptions(merge: true));
    notifyListeners();
  }

  // Get all attendance sessions for a specific date and class
  Stream<List<AttendanceModel>> getDailyAttendanceSessions({
    required String classId,
    required DateTime date,
  }) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
        .collection('attendance')
        .where('classId', isEqualTo: classId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return AttendanceModel(
          id: doc.id,
          classId: data['classId'] ?? '',
          studentId: data['studentId'] ?? '',
          studentName: data['studentName'] ?? '',
          status: data['status'] ?? '',
          date: (data['date'] as Timestamp).toDate(),
          time: data['time'],
          sessionName: data['sessionName'],
          createdAt: data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
        );
      }).toList();
    });
  }

  // Get attendance for a specific date (backward compatible)
  Future<AttendanceModel?> getAttendance({
    required String classId,
    required String studentId,
    required DateTime date,
  }) async {
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final docId = '${classId}_${studentId}_$dateString';

    final doc = await _firestore.collection('attendance').doc(docId).get();

    if (doc.exists) {
      final data = doc.data()!;
      return AttendanceModel(
        id: doc.id,
        classId: data['classId'] ?? '',
        studentId: data['studentId'] ?? '',
        studentName: data['studentName'] ?? '',
        status: data['status'] ?? '',
        date: (data['date'] as Timestamp).toDate(),
        time: data['time'],
        sessionName: data['sessionName'],
        createdAt: data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : null,
      );
    }
    return null;
  }

  // Get all attendance for a class on a specific date
  Stream<List<AttendanceModel>> getClassAttendance(String classId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
        .collection('attendance')
        .where('classId', isEqualTo: classId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return AttendanceModel(
          id: doc.id,
          classId: data['classId'] ?? '',
          studentId: data['studentId'] ?? '',
          studentName: data['studentName'] ?? '',
          status: data['status'] ?? '',
          date: (data['date'] as Timestamp).toDate(),
          time: data['time'],
          sessionName: data['sessionName'],
          createdAt: data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
        );
      }).toList();
    });
  }

  // Get attendance by date (Future version for backward compatibility)
  Future<List<AttendanceModel>> getAttendanceByDate(
      String classId,
      DateTime date,
      ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection('attendance')
        .where('classId', isEqualTo: classId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return AttendanceModel(
        id: doc.id,
        classId: data['classId'] ?? '',
        studentId: data['studentId'] ?? '',
        studentName: data['studentName'] ?? '',
        status: data['status'] ?? '',
        date: (data['date'] as Timestamp).toDate(),
        time: data['time'],
        sessionName: data['sessionName'],
        createdAt: data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : null,
      );
    }).toList();
  }

  // Get monthly attendance count
  Future<Map<DateTime, int>> getMonthlyAttendanceCount(
      String classId,
      DateTime month,
      ) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final snapshot = await _firestore
        .collection('attendance')
        .where('classId', isEqualTo: classId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    Map<DateTime, int> attendanceCount = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp).toDate();
      final dateOnly = DateTime(date.year, date.month, date.day);

      attendanceCount[dateOnly] = (attendanceCount[dateOnly] ?? 0) + 1;
    }

    return attendanceCount;
  }

  // Get student attendance history
  Stream<List<AttendanceModel>> getStudentAttendance(
      String studentId,
      [String? classId]  // Made optional for backward compatibility
      ) {
    var query = _firestore
        .collection('attendance')
        .where('studentId', isEqualTo: studentId);

    // Add classId filter if provided
    if (classId != null) {
      query = query.where('classId', isEqualTo: classId);
    }

    return query
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return AttendanceModel(
          id: doc.id,
          classId: data['classId'] ?? '',
          studentId: data['studentId'] ?? '',
          studentName: data['studentName'] ?? '',
          status: data['status'] ?? '',
          date: (data['date'] as Timestamp).toDate(),
          time: data['time'],
          sessionName: data['sessionName'],
          createdAt: data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
        );
      }).toList();
    });
  }

  // Get all attendance for a class (all students, all dates)
  Stream<List<AttendanceModel>> getAllClassAttendance(String classId) {
    return _firestore
        .collection('attendance')
        .where('classId', isEqualTo: classId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return AttendanceModel(
          id: doc.id,
          classId: data['classId'] ?? '',
          studentId: data['studentId'] ?? '',
          studentName: data['studentName'] ?? '',
          status: data['status'] ?? '',
          date: (data['date'] as Timestamp).toDate(),
          time: data['time'],
          sessionName: data['sessionName'],
          createdAt: data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
        );
      }).toList();
    });
  }

  // Delete attendance record
  Future<void> deleteAttendance(String attendanceId) async {
    await _firestore.collection('attendance').doc(attendanceId).delete();
    notifyListeners();
  }
}