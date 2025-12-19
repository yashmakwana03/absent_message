import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/student_report_models.dart'; // Import the model
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
  String _activeFilter = 'All'; // Filter by Department Name

  @override
  void initState() {
    super.initState();
    _fetchAndCalculateData();
    _searchController.addListener(_filterStudents);
  }

  Future<void> _fetchAndCalculateData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Data
      final students = await DatabaseHelper.instance.readAllStudentsWithDeptName();
      // Fetch ALL logs (pass no date to get everything)
      final logs = await DatabaseHelper.instance.getAttendanceLogs(); 

      List<StudentReport> calculatedReports = [];

      // 2. Loop Students
      for (var student in students) {
        String name = student['name'];
        String roll = student['rollNumber'];
        int deptId = student['deptId'];
        String deptName = student['departmentName'];

        int totalLectures = 0;
        int totalAbsent = 0;
        Map<String, Map<String, int>> subjectStats = {};

        // 3. Loop Logs for this student
        for (var log in logs) {
          // Check if this log belongs to the student's department based on log data
          // Assuming we can match via deptName returned in logs, or we need deptId.
          // Let's assume log['deptName'] is available from the query join.
          if (log['deptName'] == deptName) {
            totalLectures++;
            String subject = log['subject'];
            
            // Check absence
            String absentees = log['absentees'] ?? "";
            List<String> absList = absentees.split(',').map((e) => e.trim()).toList();
            bool isAbsent = absList.contains(roll);

            if (isAbsent) totalAbsent++;

            // Update Subject Stats
            if (!subjectStats.containsKey(subject)) {
              subjectStats[subject] = {'present': 0, 'absent': 0};
            }
            if (isAbsent) {
              subjectStats[subject]!['absent'] = subjectStats[subject]!['absent']! + 1;
            } else {
              subjectStats[subject]!['present'] = subjectStats[subject]!['present']! + 1;
            }
          }
        }

        // 4. Calculate Final Stats
        double percentage = totalLectures == 0 ? 100 : ((totalLectures - totalAbsent) / totalLectures) * 100;
        
        List<SubjectAttendance> subRecords = [];
        subjectStats.forEach((key, value) {
          subRecords.add(SubjectAttendance(name: key, present: value['present']!, absent: value['absent']!));
        });

        calculatedReports.add(StudentReport(
          name: name,
          rollNo: roll,
          department: deptName,
          totalAbsentLectures: totalAbsent,
          overallAttendancePercentage: percentage.round(),
          subjectRecords: subRecords,
        ));
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

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      List<StudentReport> results = _allReports;
      
      // Dept Filter
      if (_activeFilter != 'All') {
        results = results.where((s) => s.department == _activeFilter).toList();
      }

      // Search Text
      if (query.isNotEmpty) {
        results = results.where((s) => s.name.toLowerCase().contains(query) || s.rollNo.contains(query)).toList();
      }
      _filteredReports = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Extract unique department names for filter chips
    final departments = ['All', ..._allReports.map((e) => e.department).toSet().toList()];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(title: const Text('Search & Filter')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search students...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                filled: true, fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: departments.map((dept) {
                  final isSelected = _activeFilter == dept;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(dept),
                      selected: isSelected,
                      selectedColor: Theme.of(context).primaryColor,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
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
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty 
                  ? const Center(child: Text("No students found"))
                  : ListView.builder(
                      itemCount: _filteredReports.length,
                      itemBuilder: (context, index) => StudentResultCard(report: _filteredReports[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentResultCard extends StatelessWidget {
  final StudentReport report;
  const StudentResultCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Card(
      elevation: 2, color: Colors.white, margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(report.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(report.department, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Roll: ${report.rollNo}', style: const TextStyle(color: Colors.grey)),
              Text('${report.overallAttendancePercentage}%', style: TextStyle(fontWeight: FontWeight.bold, color: report.overallAttendancePercentage < 75 ? Colors.red : Colors.green)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => StudentDetailScreen(student: report)));
                },
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                child: const Text('View Detailed Report'),
              ),
            )
          ],
        ),
      ),
    );
  }
}