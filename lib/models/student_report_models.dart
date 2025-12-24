class StudentReport {
  final int id; // ✅ Added ID
  final String name;
  final String rollNo;
  final String department;
  final int totalAbsentLectures;
  final int overallAttendancePercentage;
  final List<SubjectAttendance> subjectRecords;

  StudentReport({
    required this.id, // ✅ Required in constructor
    required this.name,
    required this.rollNo,
    required this.department,
    required this.totalAbsentLectures,
    required this.overallAttendancePercentage,
    required this.subjectRecords,
  });
}

class SubjectAttendance {
  final String name;
  final int present;
  final int absent;

  SubjectAttendance({
    required this.name,
    required this.present,
    required this.absent,
  });
}