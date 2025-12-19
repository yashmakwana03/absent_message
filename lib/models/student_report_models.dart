class StudentReport {
  final String name;
  final String rollNo;
  final String enrollmentNo; // Optional, defaults to N/A
  final String department;
  final int totalAbsentLectures;
  final int overallAttendancePercentage;
  final List<SubjectAttendance> subjectRecords;

  StudentReport({
    required this.name,
    required this.rollNo,
    this.enrollmentNo = 'N/A',
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
  
  int get total => present + absent;
  int get percentage => total == 0 ? 100 : ((present / total) * 100).round();

  SubjectAttendance({required this.name, required this.present, required this.absent});
}