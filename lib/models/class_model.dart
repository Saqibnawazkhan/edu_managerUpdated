import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String name;
  final String teacherId;
  final int studentCount;
  final DateTime createdAt;

  ClassModel({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.studentCount,
    required this.createdAt,
  });

  factory ClassModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ClassModel(
      id: doc.id,
      name: data['name'] ?? '',
      teacherId: data['teacherId'] ?? '',
      studentCount: data['studentCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'teacherId': teacherId,
      'studentCount': studentCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}