import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/class_model.dart';
import '../models/attendance_model.dart';
import '../models/marks_model.dart';

/// Service for fetching teacher activity data (classes, attendance, marks)
class TeacherActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all classes for a specific teacher
  Future<List<ClassModel>> getTeacherClasses(String teacherId) async {
    try {
      final snapshot = await _firestore
          .collection('classes')
          .where('userId', isEqualTo: teacherId)
          .get();

      return snapshot.docs.map((doc) => ClassModel.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get student count for a class
  Future<int> getClassStudentCount(String classId) async {
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

  /// Get attendance records for multiple classes within a date range
  Future<List<AttendanceModel>> getAttendanceRecords({
    required List<String> classIds,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (classIds.isEmpty) return [];

    try {
      List<AttendanceModel> allRecords = [];

      // Firestore has a limit of 10 items in 'whereIn', so batch if needed
      for (var i = 0; i < classIds.length; i += 10) {
        final batchIds = classIds.sublist(
          i,
          i + 10 > classIds.length ? classIds.length : i + 10,
        );

        Query query = _firestore
            .collection('attendance')
            .where('classId', whereIn: batchIds);

        if (startDate != null) {
          query = query.where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
        }
        if (endDate != null) {
          final endOfDay = DateTime(
              endDate.year, endDate.month, endDate.day, 23, 59, 59);
          query = query.where('date',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
        }

        final snapshot = await query.get();

        allRecords.addAll(snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
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
        }));
      }

      return allRecords;
    } catch (e) {
      return [];
    }
  }

  /// Get marks records for multiple classes within a date range
  Future<List<MarksModel>> getMarksRecords({
    required List<String> classIds,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (classIds.isEmpty) return [];

    try {
      List<MarksModel> allRecords = [];

      // Firestore has a limit of 10 items in 'whereIn', so batch if needed
      for (var i = 0; i < classIds.length; i += 10) {
        final batchIds = classIds.sublist(
          i,
          i + 10 > classIds.length ? classIds.length : i + 10,
        );

        final snapshot = await _firestore
            .collection('marks')
            .where('classId', whereIn: batchIds)
            .get();

        // Filter by date in code since marks use string date format
        for (var doc in snapshot.docs) {
          final marks = MarksModel.fromFirestore(doc);

          // Parse date from dd/MM/yyyy format
          if (startDate != null || endDate != null) {
            final dateParts = marks.date.split('/');
            if (dateParts.length == 3) {
              final marksDate = DateTime(
                int.parse(dateParts[2]),
                int.parse(dateParts[1]),
                int.parse(dateParts[0]),
              );

              if (startDate != null && marksDate.isBefore(startDate)) continue;
              if (endDate != null && marksDate.isAfter(endDate)) continue;
            }
          }

          allRecords.add(marks);
        }
      }

      return allRecords;
    } catch (e) {
      return [];
    }
  }

  /// Calculate attendance statistics from records
  AttendanceStats calculateAttendanceStats(List<AttendanceModel> records) {
    int present = 0;
    int absent = 0;
    int late = 0;
    int leave = 0;
    int sick = 0;

    for (var record in records) {
      switch (record.status.toLowerCase()) {
        case 'present':
          present++;
          break;
        case 'absent':
          absent++;
          break;
        case 'late':
          late++;
          break;
        case 'leave':
          leave++;
          break;
        case 'sick':
          sick++;
          break;
      }
    }

    return AttendanceStats(
      totalRecords: records.length,
      presentCount: present,
      absentCount: absent,
      lateCount: late,
      leaveCount: leave,
      sickCount: sick,
    );
  }

  /// Calculate marks statistics from records
  MarksStats calculateMarksStats(List<MarksModel> records) {
    if (records.isEmpty) {
      return MarksStats(
        totalRecords: 0,
        mockCount: 0,
        assignmentCount: 0,
        averagePercentage: 0.0,
        assessments: [],
      );
    }

    int mockCount = 0;
    int assignmentCount = 0;
    double totalPercentage = 0.0;

    // Group by assessment name and date for unique assessments
    Map<String, AssessmentSummary> assessmentMap = {};

    for (var record in records) {
      totalPercentage += record.percentage;

      if (record.assessmentType == 'mock') {
        mockCount++;
      } else if (record.assessmentType == 'assignment') {
        assignmentCount++;
      }

      // Group assessments
      final key = '${record.classId}_${record.assessmentName}_${record.date}';
      if (!assessmentMap.containsKey(key)) {
        assessmentMap[key] = AssessmentSummary(
          classId: record.classId,
          assessmentName: record.assessmentName,
          assessmentType: record.assessmentType,
          date: record.date,
          totalPercentage: record.percentage,
          studentCount: 1,
        );
      } else {
        final existing = assessmentMap[key]!;
        assessmentMap[key] = AssessmentSummary(
          classId: existing.classId,
          assessmentName: existing.assessmentName,
          assessmentType: existing.assessmentType,
          date: existing.date,
          totalPercentage: existing.totalPercentage + record.percentage,
          studentCount: existing.studentCount + 1,
        );
      }
    }

    return MarksStats(
      totalRecords: records.length,
      mockCount: mockCount,
      assignmentCount: assignmentCount,
      averagePercentage: totalPercentage / records.length,
      assessments: assessmentMap.values.toList(),
    );
  }

  /// Get complete teacher activity data
  Future<TeacherActivityData> getTeacherActivityData({
    required String teacherId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Get teacher's classes
    final classes = await getTeacherClasses(teacherId);
    final classIds = classes.map((c) => c.id).toList();

    // Get student counts for each class
    Map<String, int> studentCounts = {};
    for (var classItem in classes) {
      studentCounts[classItem.id] = await getClassStudentCount(classItem.id);
    }

    // Get attendance records
    final attendanceRecords = await getAttendanceRecords(
      classIds: classIds,
      startDate: startDate,
      endDate: endDate,
    );

    // Get marks records
    final marksRecords = await getMarksRecords(
      classIds: classIds,
      startDate: startDate,
      endDate: endDate,
    );

    // Calculate overall stats
    final overallAttendanceStats = calculateAttendanceStats(attendanceRecords);
    final overallMarksStats = calculateMarksStats(marksRecords);

    // Calculate per-class stats
    Map<String, ClassActivityData> classActivities = {};
    for (var classItem in classes) {
      final classAttendance =
          attendanceRecords.where((r) => r.classId == classItem.id).toList();
      final classMarks =
          marksRecords.where((r) => r.classId == classItem.id).toList();

      classActivities[classItem.id] = ClassActivityData(
        classModel: classItem,
        studentCount: studentCounts[classItem.id] ?? 0,
        attendanceStats: calculateAttendanceStats(classAttendance),
        marksStats: calculateMarksStats(classMarks),
        attendanceRecords: classAttendance,
        marksRecords: classMarks,
      );
    }

    return TeacherActivityData(
      classes: classes,
      classActivities: classActivities,
      overallAttendanceStats: overallAttendanceStats,
      overallMarksStats: overallMarksStats,
      allAttendanceRecords: attendanceRecords,
      allMarksRecords: marksRecords,
    );
  }
}

/// Attendance statistics model
class AttendanceStats {
  final int totalRecords;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int leaveCount;
  final int sickCount;

  AttendanceStats({
    required this.totalRecords,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.leaveCount,
    required this.sickCount,
  });

  double get presentPercentage =>
      totalRecords > 0 ? (presentCount / totalRecords) * 100 : 0;
  double get absentPercentage =>
      totalRecords > 0 ? (absentCount / totalRecords) * 100 : 0;
  double get latePercentage =>
      totalRecords > 0 ? (lateCount / totalRecords) * 100 : 0;
  double get leavePercentage =>
      totalRecords > 0 ? (leaveCount / totalRecords) * 100 : 0;
  double get sickPercentage =>
      totalRecords > 0 ? (sickCount / totalRecords) * 100 : 0;
}

/// Marks statistics model
class MarksStats {
  final int totalRecords;
  final int mockCount;
  final int assignmentCount;
  final double averagePercentage;
  final List<AssessmentSummary> assessments;

  MarksStats({
    required this.totalRecords,
    required this.mockCount,
    required this.assignmentCount,
    required this.averagePercentage,
    required this.assessments,
  });
}

/// Assessment summary for grouping
class AssessmentSummary {
  final String classId;
  final String assessmentName;
  final String assessmentType;
  final String date;
  final double totalPercentage;
  final int studentCount;

  AssessmentSummary({
    required this.classId,
    required this.assessmentName,
    required this.assessmentType,
    required this.date,
    required this.totalPercentage,
    required this.studentCount,
  });

  double get averagePercentage =>
      studentCount > 0 ? totalPercentage / studentCount : 0;
}

/// Class activity data
class ClassActivityData {
  final ClassModel classModel;
  final int studentCount;
  final AttendanceStats attendanceStats;
  final MarksStats marksStats;
  final List<AttendanceModel> attendanceRecords;
  final List<MarksModel> marksRecords;

  ClassActivityData({
    required this.classModel,
    required this.studentCount,
    required this.attendanceStats,
    required this.marksStats,
    required this.attendanceRecords,
    required this.marksRecords,
  });
}

/// Complete teacher activity data
class TeacherActivityData {
  final List<ClassModel> classes;
  final Map<String, ClassActivityData> classActivities;
  final AttendanceStats overallAttendanceStats;
  final MarksStats overallMarksStats;
  final List<AttendanceModel> allAttendanceRecords;
  final List<MarksModel> allMarksRecords;

  TeacherActivityData({
    required this.classes,
    required this.classActivities,
    required this.overallAttendanceStats,
    required this.overallMarksStats,
    required this.allAttendanceRecords,
    required this.allMarksRecords,
  });

  int get totalStudents {
    int count = 0;
    for (var activity in classActivities.values) {
      count += activity.studentCount;
    }
    return count;
  }
}
