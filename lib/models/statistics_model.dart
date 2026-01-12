class StudentStatistics {
  final String studentId;
  final String studentName;
  final int totalDays;
  final int presentDays;
  final int lateDays;
  final int sickDays;
  final int absentDays;
  final int shortLeaveDays;
  final double presentPercentage;
  final double absentPercentage;
  final Map<String, String> dailyAttendance; // date -> status

  StudentStatistics({
    required this.studentId,
    required this.studentName,
    required this.totalDays,
    required this.presentDays,
    required this.lateDays,
    required this.sickDays,
    required this.absentDays,
    required this.shortLeaveDays,
    required this.presentPercentage,
    required this.absentPercentage,
    required this.dailyAttendance,
  });

  factory StudentStatistics.fromAttendance(
      String studentId,
      String studentName,
      List<Map<String, dynamic>> attendanceRecords,
      ) {
    int present = 0, late = 0, sick = 0, absent = 0, shortLeave = 0;
    Map<String, String> dailyAttendance = {};

    for (var record in attendanceRecords) {
      String status = record['status'];
      String date = record['date'];

      dailyAttendance[date] = status;

      switch (status) {
        case 'present':
          present++;
          break;
        case 'late':
          late++;
          break;
        case 'sick':
          sick++;
          break;
        case 'absent':
          absent++;
          break;
        case 'short_leave':
          shortLeave++;
          break;
      }
    }

    int total = present + late + sick + absent + shortLeave;
    double presentPct = total > 0 ? (present / total) * 100 : 0;
    double absentPct = total > 0 ? (absent / total) * 100 : 0;

    return StudentStatistics(
      studentId: studentId,
      studentName: studentName,
      totalDays: total,
      presentDays: present,
      lateDays: late,
      sickDays: sick,
      absentDays: absent,
      shortLeaveDays: shortLeave,
      presentPercentage: presentPct,
      absentPercentage: absentPct,
      dailyAttendance: dailyAttendance,
    );
  }
}