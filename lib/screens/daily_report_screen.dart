import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import 'report_generator_v3.dart';

// --- MODELS ---
class LectureSlot {
  final String title;
  final String faculty;
  final int totalStrength;
  final int presentCount;
  final int absentCount;
  final List<AbsentStudentUi> absentStudents;

  LectureSlot({
    required this.title,
    required this.faculty,
    required this.totalStrength,
    required this.presentCount,
    required this.absentCount,
    required this.absentStudents,
  });

  double get percent => totalStrength == 0 ? 0 : presentCount / totalStrength;
}

class AbsentStudentUi {
  final String rollNo;
  final String name;
  final String department;

  const AbsentStudentUi({required this.rollNo, required this.name, required this.department});
}

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  int _totalAbsent = 0;
  double _dayAttendancePercent = 0.0;
  List<LectureSlot> _lectureData = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // --- ACTIONS ---
  
  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _fetchData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchData();
    }
  }

  void _editLecture() async {
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => ReportGeneratorScreenV3(initialDate: _selectedDate))
    );
    _fetchData();
  }

  // --- UPDATED: PROFESSIONAL TEXT GENERATOR (Fixed Variable Error) ---
  Future<void> _shareSummary() async {
    if (_lectureData.isEmpty) return;
    
    String dateStr = DateFormat('dd-MM-yyyy').format(_selectedDate);
    StringBuffer sb = StringBuffer();
    
    // Header
    sb.writeln("*Daily Attendance Report*");
    sb.writeln("Date: _${dateStr}_\n"); // Fixed: Added brackets {}
    
    // Summary Stats
    sb.writeln("*Overview*");
    sb.writeln("- Total Absent: $_totalAbsent");
    sb.writeln("- Attendance: ${(_dayAttendancePercent * 100).toStringAsFixed(1)}%\n");

    sb.writeln("--------------------------------\n");

    // Lecture Details
    for (var lecture in _lectureData) {
      sb.writeln("*${lecture.title}*");
      
      if (lecture.absentStudents.isEmpty) {
        sb.writeln("_All Present_");
      } else {
        sb.writeln("Absent: ${lecture.absentCount}");
        
        // Group by Dept for cleaner list
        Map<String, List<String>> deptMap = {};
        for(var s in lecture.absentStudents) {
          if(!deptMap.containsKey(s.department)) deptMap[s.department] = [];
          deptMap[s.department]!.add(s.rollNo);
        }
        
        deptMap.forEach((dept, rolls) {
          // e.g. - CE : 1, 5, 12
          sb.writeln("- $dept : ${rolls.join(', ')}");
        });
      }
      sb.writeln(""); // Empty line between lectures
    }
    
    await Share.share(sb.toString());
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final allStudents = await DatabaseHelper.instance.readAllStudentsWithDeptName();
      
      Map<String, String> studentNames = {};
      Map<int, int> deptStrength = {};

      for (var s in allStudents) {
        int dId = s['deptId'];
        studentNames["${dId}_${s['rollNumber']}"] = s['name'];
        deptStrength[dId] = (deptStrength[dId] ?? 0) + 1;
      }

      String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final logs = await DatabaseHelper.instance.getAttendanceLogs(date: dateStr);

      int dayTotalStudents = 0;
      int dayTotalPresent = 0;
      List<LectureSlot> lectures = [];

      for (var log in logs) {
        String deptName = log['deptName'];
        int deptId = 0;
        var matchingStudent = allStudents.firstWhere((s) => s['departmentName'] == deptName, orElse: () => {});
        if (matchingStudent.isNotEmpty) deptId = matchingStudent['deptId'];

        int totalStrength = deptStrength[deptId] ?? 0;
        String absenteesStr = log['absentees'] ?? "";
        List<String> absList = absenteesStr.split(',').where((s) => s.trim().isNotEmpty).toList();
        
        int absentCount = absList.length;
        int presentCount = (totalStrength - absentCount).clamp(0, totalStrength);

        List<AbsentStudentUi> absentUiList = [];
        for (String roll in absList) {
          String cleanRoll = roll.trim();
          String name = studentNames["${deptId}_$cleanRoll"] ?? "Unknown";
          absentUiList.add(AbsentStudentUi(rollNo: cleanRoll, name: name, department: deptName));
        }
        
        try { absentUiList.sort((a, b) => int.parse(a.rollNo).compareTo(int.parse(b.rollNo))); } catch (_) {}

        dayTotalStudents += totalStrength;
        dayTotalPresent += presentCount;

        lectures.add(LectureSlot(
          title: "${log['subject']} (${log['timeSlot']})",
          faculty: log['faculty'] ?? "",
          totalStrength: totalStrength,
          presentCount: presentCount,
          absentCount: absentCount,
          absentStudents: absentUiList,
        ));
      }

      double dayPercent = dayTotalStudents == 0 ? 0 : (dayTotalPresent / dayTotalStudents);

      if (mounted) {
        setState(() {
          _totalAbsent = (dayTotalStudents - dayTotalPresent);
          _dayAttendancePercent = dayPercent;
          _lectureData = lectures;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.deepPurple;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Daily Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.deepPurple),
            onPressed: _shareSummary,
            tooltip: "Share Report",
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.deepPurple),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // --- DATE CONTROLS ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(onPressed: () => _changeDate(-1), icon: const Icon(Icons.arrow_back_ios, size: 18)),
                  Column(
                    children: [
                      Text(
                        DateFormat('EEEE').format(_selectedDate),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      Text(
                        DateFormat('d MMMM yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(onPressed: () => _changeDate(1), icon: const Icon(Icons.arrow_forward_ios, size: 18)),
                ],
              ),
              const SizedBox(height: 20),

              // --- SUMMARY CARDS ---
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: "Total Absent",
                      value: _totalAbsent.toString(),
                      icon: Icons.person_off,
                      color: Colors.redAccent,
                      bgColor: Colors.red.shade50,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: "Attendance",
                      value: "${(_dayAttendancePercent * 100).toStringAsFixed(1)}%",
                      icon: Icons.pie_chart,
                      color: Colors.green,
                      bgColor: Colors.green.shade50,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              
              // --- LECTURE LIST ---
              Row(
                children: [
                  Icon(Icons.class_outlined, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  const Text("Lecture Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),

              if (_lectureData.isEmpty)
                _buildEmptyState()
              else
                ..._lectureData.map((slot) => _buildLectureCard(slot)),
              
              const SizedBox(height: 40),
            ],
          ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color, required Color bgColor}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildLectureCard(LectureSlot slot) {
    bool isLowAttendance = slot.percent < 0.75;
    Color statusColor = isLowAttendance ? Colors.red : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _editLecture, 
        child: ExpansionTile(
          shape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
          leading: SizedBox(
            width: 50, height: 50,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: slot.percent,
                  backgroundColor: Colors.grey.shade100,
                  color: statusColor,
                  strokeWidth: 5,
                ),
                Center(
                  child: Text(
                    "${(slot.percent * 100).toInt()}%",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
          ),
          title: Text(slot.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text(
            "Absent: ${slot.absentCount} / ${slot.totalStrength}",
            style: TextStyle(color: Colors.grey[600]),
          ),
          children: [
            const Divider(),
            if (slot.absentStudents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[300], size: 20),
                    const SizedBox(width: 8),
                    const Text("100% Attendance", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Absent Students:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 10),
                  ...slot.absentStudents.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(s.department, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 30,
                          child: Text(s.rollNo, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(s.name, style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                  )),
                ],
              ),
              
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Center(
                  child: Text("Tap card to Edit Attendance", style: TextStyle(fontSize: 12, color: Colors.deepPurple, fontWeight: FontWeight.bold))
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.calendar_today_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No attendance recorded.",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _editLecture,
            icon: const Icon(Icons.add),
            label: const Text("Add Attendance"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
          )
        ],
      ),
    );
  }
}