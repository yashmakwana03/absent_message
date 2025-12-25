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
  
  // Stats
  int _totalAbsent = 0;
  int _totalPresent = 0;   
  int _totalStrength = 0;  
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

  Future<void> _shareSummary() async {
    if (_lectureData.isEmpty) return;
    
    String dateStr = DateFormat('dd-MM-yyyy').format(_selectedDate);
    StringBuffer sb = StringBuffer();
    
    // Header
    sb.writeln("*Daily Attendance Report*");
    sb.writeln("Date: $dateStr\n"); 
    
    // Summary Stats
    sb.writeln("*Overview*");
    sb.writeln("- Unique Students Present: $_totalPresent / $_totalStrength");
    sb.writeln("- Fully Absent: $_totalAbsent");
    sb.writeln("- Daily Turnout: ${(_dayAttendancePercent * 100).toStringAsFixed(1)}%\n");

    sb.writeln("--------------------------------\n");

    // Lecture Details
    for (var lecture in _lectureData) {
      sb.writeln("*${lecture.title}*");
      sb.writeln("Present: ${lecture.presentCount}/${lecture.totalStrength} | Absent: ${lecture.absentCount}");
      
      if (lecture.absentStudents.isEmpty) {
        sb.writeln("_All Present_");
      } else {
        Map<String, List<String>> deptMap = {};
        for(var s in lecture.absentStudents) {
          if(!deptMap.containsKey(s.department)) deptMap[s.department] = [];
          deptMap[s.department]!.add(s.rollNo);
        }
        
        deptMap.forEach((dept, rolls) {
          sb.writeln("- $dept : ${rolls.join(', ')}");
        });
      }
      sb.writeln(""); 
    }
    
    await Share.share(sb.toString());
  }

  // --- CORE DATA FETCHING ---
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      
      // 1. Get All Students & Metadata
      final allStudents = await DatabaseHelper.instance.readAllStudentsWithDeptName();
      final lectureRows = await db.query('Lecture');
      final enrollmentRows = await db.query('SubjectEnrollment');

      Map<String, Map<String, dynamic>> lectureInfoMap = {}; 
      for(var row in lectureRows) {
        String key = "${row['subject']}_${row['timeSlot']}";
        lectureInfoMap[key] = {
            'id': row['id'], 
            'isElective': (row['isElective'] as int) == 1
        };
      }
      
      Set<String> enrollments = enrollmentRows.map((e) => "${e['lectureId']}_${e['studentId']}").toSet();

      // Helper Maps
      Map<String, String> studentNames = {}; 
      Map<String, int> rollToIdMap = {};

      for (var s in allStudents) {
        int dId = s['deptId'];
        String uniqueRollKey = "${dId}_${s['rollNumber']}";
        studentNames[uniqueRollKey] = s['name'];
        rollToIdMap[uniqueRollKey] = s['id'];
      }

      // 2. Get Logs
      String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final logs = await DatabaseHelper.instance.getAttendanceLogs(date: dateStr);

      List<LectureSlot> lectures = [];

      // --- UNIQUE TRACKING SETS ---
      Set<int> uniqueScheduledStudents = {}; // Total unique students having classes
      Set<int> uniquePresentStudents = {};   // Attended AT LEAST ONE class
      Set<int> uniqueAbsentStudents = {};    // Missed AT LEAST ONE class

      // Variables for Percentage Calculation (Slot-based)
      int totalSlotsScheduled = 0;
      int totalSlotsPresent = 0;

      for (var log in logs) {
        String deptName = log['deptName'];
        int deptId = 0;
        var matchingStudent = allStudents.firstWhere((s) => s['departmentName'] == deptName, orElse: () => {});
        if (matchingStudent.isNotEmpty) deptId = matchingStudent['deptId'];

        String key = "${log['subject']}_${log['timeSlot']}";
        var info = lectureInfoMap[key];
        bool isElective = info?['isElective'] ?? false;
        int lectureId = info?['id'] ?? 0;

        List<String> lectureStudentRolls = []; 

        if (!isElective) {
           lectureStudentRolls = allStudents
               .where((s) => s['deptId'] == deptId)
               .map((s) => s['rollNumber'] as String)
               .toList();
        } else {
           var studentsInDept = allStudents.where((s) => s['deptId'] == deptId);
           for(var s in studentsInDept) {
              if (enrollments.contains("${lectureId}_${s['id']}")) {
                lectureStudentRolls.add(s['rollNumber']);
              }
           }
        }

        // Parse Absentees
        String absenteesStr = log['absentees'] ?? "";
        List<String> absList = absenteesStr.split(',').where((s) => s.trim().isNotEmpty).toList();

        // --- UPDATE UNIQUE SETS ---
        for (var roll in lectureStudentRolls) {
          int? sId = rollToIdMap["${deptId}_$roll"];
          if (sId != null) {
            uniqueScheduledStudents.add(sId); // Add to Total Scheduled

            if (absList.contains(roll)) {
              uniqueAbsentStudents.add(sId); // Missed this class -> Add to Unique Absent
            } else {
              uniquePresentStudents.add(sId); // Attended this class -> Add to Unique Present
            }
          }
        }

        // Slot Stats for Percentage
        int totalLecStrength = lectureStudentRolls.length;
        int lecAbsent = absList.length;
        int lecPresent = (totalLecStrength - lecAbsent).clamp(0, totalLecStrength);
        
        totalSlotsScheduled += totalLecStrength;
        totalSlotsPresent += lecPresent;

        // Build UI Model
        List<AbsentStudentUi> absentUiList = [];
        for (String roll in absList) {
          String cleanRoll = roll.trim();
          String name = studentNames["${deptId}_$cleanRoll"] ?? "Unknown";
          absentUiList.add(AbsentStudentUi(rollNo: cleanRoll, name: name, department: deptName));
        }
        
        try { absentUiList.sort((a, b) => int.parse(a.rollNo.replaceAll(RegExp(r'[^0-9]'), '')).compareTo(int.parse(b.rollNo.replaceAll(RegExp(r'[^0-9]'), '')))); } catch (_) {}

        lectures.add(LectureSlot(
          title: "${log['subject']} (${log['timeSlot']})",
          faculty: log['faculty'] ?? "",
          totalStrength: totalLecStrength,
          presentCount: lecPresent,
          absentCount: lecAbsent,
          absentStudents: absentUiList,
        ));
      }

      // Percentage uses SLOT count (more accurate for "Daily Turnout")
      double dayPercent = totalSlotsScheduled == 0 ? 0 : (totalSlotsPresent / totalSlotsScheduled);

      if (mounted) {
        setState(() {
          // ✅ SYMMETRIC LOGIC:
          _totalAbsent = uniqueAbsentStudents.length;  // Count of anyone who missed >= 1 class
          _totalPresent = uniquePresentStudents.length; // Count of anyone who attended >= 1 class
          _totalStrength = uniqueScheduledStudents.length;
          
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
                      title: "Absent (Whole Day Or any Lec)", // Updated Title
                      value: _totalAbsent.toString(),
                      icon: Icons.person_off,
                      color: Colors.redAccent,
                      bgColor: Colors.red.shade50,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: "Present (Any Lec)", // Updated Title
                      value: "$_totalPresent / $_totalStrength",
                      icon: Icons.check_circle,
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
        // ✅ Fixed Deprecation
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
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
          // Scale text if numbers get large
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w600)),
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
          
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 14, color: Colors.green[700]),
                const SizedBox(width: 4),
                Text("Present: ${slot.presentCount} / ${slot.totalStrength}", style: TextStyle(color: Colors.green[700], fontSize: 13, fontWeight: FontWeight.w500)),
                
                const SizedBox(width: 12),
                
                Icon(Icons.cancel_outlined, size: 14, color: Colors.red[700]),
                const SizedBox(width: 4),
                Text("Absent: ${slot.absentCount}", style: TextStyle(color: Colors.red[700], fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
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