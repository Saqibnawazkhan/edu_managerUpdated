import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String classId;
  final String name;
  final String phoneNo;
  final String fatherPhNo;
  final String motherPhNo;
  final DateTime createdAt;

  StudentModel({
    required this.id,
    required this.classId,
    required this.name,
    required this.phoneNo,
    required this.fatherPhNo,
    required this.motherPhNo,
    required this.createdAt,
  });

  factory StudentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return StudentModel(
      id: doc.id,
      classId: data['classId'] ?? '',
      name: data['name'] ?? '',
      phoneNo: data['phoneNo'] ?? '',
      fatherPhNo: data['fatherPhNo'] ?? '',
      motherPhNo: data['motherPhNo'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'name': name,
      'phoneNo': phoneNo,
      'fatherPhNo': fatherPhNo,
      'motherPhNo': motherPhNo,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}