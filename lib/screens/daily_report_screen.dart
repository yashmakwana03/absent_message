import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

// --- MODELS FOR UI ---
class LectureSlot {
  final String title;
  final String presentCount;
  final String absentCount;
  final String attendancePercent;
  final Color percentColor;
  final List<AbsentStudentUi> absentStudents;

  LectureSlot({
    required this.title,
    required this.presentCount,
    required this.absentCount,
    required this.attendancePercent,
    required this.percentColor,
    required this.absentStudents,
  });
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
  bool _isLoading = true;
  String _totalAbsent = "0";
  String _attendancePercent = "0%";
  List<LectureSlot> _lectureData = [];
  final Map<int, bool> _expandedState = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch All Students (to map Roll No -> Name and calculate Total Strength)
      final allStudents = await DatabaseHelper.instance.readAllStudentsWithDeptName();
      
      // Map to store student info: "DeptId_RollNo" -> Name
      Map<String, String> studentNames = {};
      // Map to store total students per department: DeptId -> Count
      Map<int, int> deptStrength = {};

      for (var s in allStudents) {
        int dId = s['deptId'];
        String roll = s['rollNumber'];
        String name = s['name'];
        String deptName = s['departmentName'];

        studentNames["${dId}_$roll"] = name;
        studentNames["DEPT_NAME_$dId"] = deptName; // Cache dept name too

        deptStrength[dId] = (deptStrength[dId] ?? 0) + 1;
      }

      // 2. Fetch Today's Logs
      String dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final logs = await DatabaseHelper.instance.getAttendanceLogs(date: dateStr);

      int dayTotalStudents = 0;
      int dayTotalAbsent = 0;
      List<LectureSlot> lectures = [];

      for (var log in logs) {
        int deptId = 0; // We need deptId from the log query. 
        // Note: The getAttendanceLogs query in DatabaseHelper might not return 'deptId' column directly 
        // depending on your JOIN. Let's assume you update getAttendanceLogs to select L.deptId.
        // If your getAttendanceLogs query looks like "SELECT ..., D.name as deptName ...", 
        // we might need to fetch deptId differently or infer it. 
        // *Best Fix*: Ensure getAttendanceLogs SELECTs 'L.deptId'.
        // Assuming log object has it or we infer from deptName (risky if duplicates).
        // Let's rely on 'deptName' which is returned.
        
        String deptName = log['deptName'];
        // Reverse lookup deptId from name (inefficient but works for small app)
        // Or better: Update DatabaseHelper.getAttendanceLogs to return L.deptId. 
        // Assuming log contains 'deptId' (if not, add "L.deptId" to the SELECT query in DatabaseHelper).
        // For now, let's try to parse it or use logic. 
        // Actually, let's just find the deptId from our allStudents list based on deptName.
        var matchingStudent = allStudents.firstWhere((s) => s['departmentName'] == deptName, orElse: () => {});
        if (matchingStudent.isNotEmpty) deptId = matchingStudent['deptId'];

        // Calculations
        int totalStrength = deptStrength[deptId] ?? 0;
        String absenteesStr = log['absentees'] ?? "";
        List<String> absList = absenteesStr.split(',').where((s) => s.trim().isNotEmpty).toList();
        
        int absentCount = absList.length;
        int presentCount = totalStrength - absentCount;
        if (presentCount < 0) presentCount = 0; // Safety

        // Build Absent List
        List<AbsentStudentUi> absentUiList = [];
        for (String roll in absList) {
          String cleanRoll = roll.trim();
          String name = studentNames["${deptId}_$cleanRoll"] ?? "Unknown";
          absentUiList.add(AbsentStudentUi(rollNo: cleanRoll, name: name, department: deptName));
        }

        // Sort by Roll
        try {
          absentUiList.sort((a, b) => int.parse(a.rollNo).compareTo(int.parse(b.rollNo)));
        } catch (_) {}

        // Percent
        int percent = totalStrength == 0 ? 0 : ((presentCount / totalStrength) * 100).round();

        // Global Day Stats
        dayTotalStudents += totalStrength;
        dayTotalAbsent += absentCount;

        lectures.add(LectureSlot(
          title: "${log['subject']} (${log['timeSlot']})",
          presentCount: presentCount.toString(),
          absentCount: absentCount.toString(),
          attendancePercent: "$percent%",
          percentColor: percent < 75 ? Colors.red : Colors.green,
          absentStudents: absentUiList,
        ));
      }

      int dayPercent = dayTotalStudents == 0 ? 0 : (((dayTotalStudents - dayTotalAbsent) / dayTotalStudents) * 100).round();

      if (mounted) {
        setState(() {
          _totalAbsent = dayTotalAbsent.toString();
          _attendancePercent = "$dayPercent%";
          _lectureData = lectures;
          if (lectures.isNotEmpty) _expandedState[0] = true;
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
    // Uses your theme color
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Today\'s Detailed Report', style: TextStyle(color: Colors.black)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bar_chart, color: primaryColor),
                          const SizedBox(width: 8),
                          const Text('Today Attendance Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: SummaryBox(label: 'Absent Today', value: _totalAbsent, backgroundColor: const Color(0xFFFEF2F2), valueColor: const Color(0xFFB91C1C))),
                          const SizedBox(width: 16),
                          Expanded(child: SummaryBox(label: 'Attendance %', value: _attendancePercent, backgroundColor: const Color(0xFFF0FDF4), valueColor: const Color(0xFF15803D))),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('Lecture-wise Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      
                      if (_lectureData.isEmpty)
                        const Padding(padding: EdgeInsets.all(16.0), child: Center(child: Text("No lectures recorded today.", style: TextStyle(color: Colors.grey))))
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _lectureData.length,
                          separatorBuilder: (ctx, index) => const Divider(),
                          itemBuilder: (ctx, index) {
                            return LectureSlotWidget(
                              slot: _lectureData[index],
                              isExpanded: _expandedState[index] ?? false,
                              onTap: () => setState(() => _expandedState[index] = !(_expandedState[index] ?? false)),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }
}

// Reusing your SummaryBox and Widgets (Past these below or import if separated)
// ... Include SummaryBox, InfoChip, LectureSlotWidget, StudentList classes here ...
class LectureSlotWidget extends StatelessWidget {
  final LectureSlot slot;
  final bool isExpanded;
  final VoidCallback onTap;
  const LectureSlotWidget({super.key, required this.slot, required this.isExpanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(children: [
            Expanded(child: Text(slot.title, style: const TextStyle(fontWeight: FontWeight.w500))),
            InfoChip(text: slot.presentCount, color: const Color(0xFF3B82F6), textColor: Colors.white),
            const SizedBox(width: 8),
            InfoChip(text: slot.absentCount, color: const Color(0xFFFEF2F2), textColor: const Color(0xFFB91C1C)),
            const SizedBox(width: 16),
            SizedBox(width: 45, child: Text(slot.attendancePercent, textAlign: TextAlign.end, style: TextStyle(color: slot.percentColor, fontWeight: FontWeight.bold))),
            Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
          ]),
        ),
      ),
      if (isExpanded) StudentList(students: slot.absentStudents),
    ]);
  }
}

class StudentList extends StatelessWidget {
  final List<AbsentStudentUi> students;
  const StudentList({super.key, required this.students});
  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) return const Padding(padding: EdgeInsets.all(8.0), child: Text("All students present!", style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic)));
    return Container(
      padding: const EdgeInsets.only(top: 8.0), color: Colors.grey.shade50,
      child: Column(children: [
        const Row(children: [
          Expanded(flex: 1, child: Text('Roll No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 1, child: Text('Dept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ]),
        const Divider(),
        Column(children: students.map((s) => Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Row(children: [
          Expanded(flex: 1, child: Text(s.rollNo, style: const TextStyle(fontSize: 13))),
          Expanded(flex: 3, child: Text(s.name, style: const TextStyle(fontSize: 13))),
          Expanded(flex: 1, child: Text(s.department, style: const TextStyle(fontSize: 13))),
        ]))).toList()),
      ]),
    );
  }
}

class InfoChip extends StatelessWidget {
  final String text; final Color color; final Color textColor;
  const InfoChip({super.key, required this.text, required this.color, required this.textColor});
  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)), child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)));
  }
}

class SummaryBox extends StatelessWidget {
  final String label; final String value; final Color backgroundColor; final Color valueColor;
  const SummaryBox({super.key, required this.label, required this.value, required this.backgroundColor, required this.valueColor});
  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(12.0), decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(8.0)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: valueColor, fontWeight: FontWeight.w500)), const SizedBox(height: 4), Text(value, style: TextStyle(color: valueColor, fontSize: 24, fontWeight: FontWeight.bold))]));
  }
}