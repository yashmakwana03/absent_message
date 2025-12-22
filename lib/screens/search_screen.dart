import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/student_report_models.dart';
import 'student_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<StudentReport> _allReports = [];
  List<StudentReport> _filteredReports = [];
  bool _isLoading = true;
  String _activeFilter = 'All';
  bool _sortByDefaulters = false;

  @override
  void initState() {
    super.initState();
    _fetchAndCalculateData();
  }

  Future<void> _fetchAndCalculateData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Fetch Basic Data
      final students = await DatabaseHelper.instance
          .readAllStudentsWithDeptName();
      final logs = await DatabaseHelper.instance.getAttendanceLogs();

      // 2. Fetch Logic Data (Lecture Definitions & Enrollments)
      final lectureRows = await db.query('Lecture');
      final enrollmentRows = await db.query('SubjectEnrollment');

      // 3. Create SMART Maps (The Fix)
      // Map: "Subject_Time" -> Lecture ID
      Map<String, int> lectureUniqueMap = {};
      Map<int, bool> idToElectiveMap = {};

      for (var row in lectureRows) {
        String uniqueKey = "${row['subject']}_${row['timeSlot']}";
        int id = row['id'] as int;
        bool isElective = (row['isElective'] as int) == 1;

        lectureUniqueMap[uniqueKey] = id;
        idToElectiveMap[id] = isElective;
      }

      // Enrollment Set: "LectureID_StudentID"
      Set<String> enrolledKeys = enrollmentRows
          .map((e) => "${e['lectureId']}_${e['studentId']}")
          .toSet();

      List<StudentReport> calculatedReports = [];

      for (var student in students) {
        String name = student['name'];
        String roll = student['rollNumber'];
        String deptName = student['departmentName'];
        int studentId = student['id'];

        int totalLectures = 0;
        int totalAbsent = 0;
        Map<String, Map<String, int>> subjectStats = {};

        // Filter logs by department (Rough filter first)
        var deptLogs = logs.where((l) => l['deptName'] == deptName).toList();

        for (var log in deptLogs) {
          String subject = log['subject'];
          String time = log['timeSlot'];

          // --- FIX: Lookup by Name AND Time ---
          String uniqueKey = "${subject}_${time}";
          int? lectureId = lectureUniqueMap[uniqueKey];
          bool isElective =
              lectureId != null && (idToElectiveMap[lectureId] ?? false);

          if (isElective) {
            // Check if THIS student is enrolled in THIS SPECIFIC time slot
            String enrollmentKey = "${lectureId}_$studentId";
            if (!enrolledKeys.contains(enrollmentKey)) {
              continue; // SKIP: Student is not in this batch
            }
          }
          // -------------------------------------

          totalLectures++;

          String absentees = log['absentees'] ?? "";
          List<String> absList = absentees
              .split(',')
              .map((e) => e.trim())
              .toList();

          bool isAbsent = absList.contains(roll);
          if (isAbsent) totalAbsent++;

          // Consolidate stats by Subject Name
          if (!subjectStats.containsKey(subject)) {
            subjectStats[subject] = {'present': 0, 'absent': 0};
          }
          if (isAbsent) {
            subjectStats[subject]!['absent'] =
                subjectStats[subject]!['absent']! + 1;
          } else {
            subjectStats[subject]!['present'] =
                subjectStats[subject]!['present']! + 1;
          }
        }

        double percentage = totalLectures == 0
            ? 0.0
            : ((totalLectures - totalAbsent) / totalLectures) * 100;

        List<SubjectAttendance> subRecords = [];
        subjectStats.forEach((key, value) {
          subRecords.add(
            SubjectAttendance(
              name: key,
              present: value['present']!,
              absent: value['absent']!,
            ),
          );
        });

        calculatedReports.add(
          StudentReport(
            name: name,
            rollNo: roll,
            department: deptName,
            totalAbsentLectures: totalAbsent,
            overallAttendancePercentage: percentage.round(),
            subjectRecords: subRecords,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _allReports = calculatedReports;
          _filteredReports = calculatedReports;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Calc Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterStudents({String? query}) {
    String searchText = query ?? _searchController.text.toLowerCase();

    setState(() {
      List<StudentReport> results = _allReports;

      if (_activeFilter != 'All') {
        results = results.where((s) => s.department == _activeFilter).toList();
      }

      if (searchText.isNotEmpty) {
        results = results
            .where(
              (s) =>
                  s.name.toLowerCase().contains(searchText) ||
                  s.rollNo.contains(searchText),
            )
            .toList();
      }

      if (_sortByDefaulters) {
        results.sort(
          (a, b) => a.overallAttendancePercentage.compareTo(
            b.overallAttendancePercentage,
          ),
        );
      } else {
        // Numeric Sort
        results.sort((a, b) {
          int? r1 = int.tryParse(a.rollNo.replaceAll(RegExp(r'[^0-9]'), ''));
          int? r2 = int.tryParse(b.rollNo.replaceAll(RegExp(r'[^0-9]'), ''));
          if (r1 != null && r2 != null) return r1.compareTo(r2);
          return a.rollNo.compareTo(b.rollNo);
        });
      }

      _filteredReports = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.deepPurple;
    final departments = [
      'All',
      ..._allReports.map((e) => e.department).toSet(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Student Analytics'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _sortByDefaulters
                  ? Icons.sort_by_alpha
                  : Icons.warning_amber_rounded,
            ),
            tooltip: _sortByDefaulters
                ? "Sort by Roll No"
                : "Show Defaulters First",
            onPressed: () {
              setState(() {
                _sortByDefaulters = !_sortByDefaulters;
                _filterStudents();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _sortByDefaulters
                        ? "Showing Low Attendance First"
                        : "Sorted by Roll Number",
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            color: primaryColor,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => _filterStudents(query: val),
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Search by Name or Roll No...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: departments.map((dept) {
                  final isSelected = _activeFilter == dept;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(dept),
                      selected: isSelected,
                      selectedColor: primaryColor.withOpacity(0.2),
                      checkmarkColor: primaryColor,
                      labelStyle: TextStyle(
                        color: isSelected ? primaryColor : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _activeFilter = dept);
                          _filterStudents();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 10),
                        const Text("No students found"),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredReports.length,
                    itemBuilder: (context, index) =>
                        StudentResultCard(report: _filteredReports[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class StudentResultCard extends StatelessWidget {
  final StudentReport report;
  const StudentResultCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    bool isLowAttendance = report.overallAttendancePercentage < 75;
    final primaryColor = Colors.deepPurple;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentDetailScreen(student: report),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                height: 50,
                width: 50,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: report.overallAttendancePercentage / 100,
                      backgroundColor: Colors.grey.shade100,
                      color: isLowAttendance ? Colors.red : Colors.green,
                      strokeWidth: 5,
                    ),
                    Center(
                      child: Text(
                        "${report.overallAttendancePercentage}%",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isLowAttendance
                              ? Colors.red
                              : Colors.green[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            report.department,
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Roll: ${report.rollNo}",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
