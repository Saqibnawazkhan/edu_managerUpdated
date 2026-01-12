import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String classId;
  final String studentId;
  final String studentName;
  final String status;
  final DateTime date;
  final String? time;  // NEW: "09:00 AM"
  final String? sessionName;  // NEW: "Morning Session"
  final DateTime? createdAt;

  AttendanceModel({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.studentName,
    required this.status,
    required this.date,
    this.time,
    this.sessionName,
    this.createdAt,
  });

  // Create from Firestore document
  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
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
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'studentId': studentId,
      'studentName': studentName,
      'status': status,
      'date': Timestamp.fromDate(date),
      if (time != null) 'time': time,
      if (sessionName != null) 'sessionName': sessionName,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  // Get session identifier for grouping
  String get sessionId {
    if (time != null) {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      return '${dateStr}_${time}';
    }
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Display text for session
  String get sessionDisplay {
    if (sessionName != null && sessionName!.isNotEmpty) {
      return sessionName!;
    } else if (time != null) {
      return time!;
    }
    return 'Session';
  }

  // Copy with method
  AttendanceModel copyWith({
    String? id,
    String? classId,
    String? studentId,
    String? studentName,
    String? status,
    DateTime? date,
    String? time,
    String? sessionName,
    DateTime? createdAt,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      status: status ?? this.status,
      date: date ?? this.date,
      time: time ?? this.time,
      sessionName: sessionName ?? this.sessionName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}