import 'package:cloud_firestore/cloud_firestore.dart';

class MarksModel {
  final String id;
  final String classId;
  final String studentId;
  final String assessmentName;
  final String assessmentType;
  final String description;
  final double obtainedMarks;
  final double totalMarks;
  final String date;
  final DateTime createdAt;

  MarksModel({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.assessmentName,
    required this.assessmentType,
    required this.description,
    required this.obtainedMarks,
    required this.totalMarks,
    required this.date,
    required this.createdAt,
  });

  double get percentage => (obtainedMarks / totalMarks) * 100;

  factory MarksModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MarksModel(
      id: doc.id,
      classId: data['classId'] ?? '',
      studentId: data['studentId'] ?? '',
      assessmentName: data['assessmentName'] ?? '',
      assessmentType: data['assessmentType'] ?? 'mock',
      description: data['description'] ?? '',
      obtainedMarks: (data['obtainedMarks'] ?? 0).toDouble(),
      totalMarks: (data['totalMarks'] ?? 0).toDouble(),
      date: data['date'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'studentId': studentId,
      'assessmentName': assessmentName,
      'assessmentType': assessmentType,
      'description': description,
      'obtainedMarks': obtainedMarks,
      'totalMarks': totalMarks,
      'date': date,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}