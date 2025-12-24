import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/student_report_models.dart';

class StudentDetailScreen extends StatefulWidget {
  final StudentReport student;
  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _absentHistory = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAbsentHistory();
  }

  Future<void> _fetchAbsentHistory() async {
    final allLogs = await DatabaseHelper.instance.getAttendanceLogs();
    
    List<Map<String, dynamic>> history = [];

    for (var log in allLogs) {
      String absentees = log['absentees'] ?? "";
      List<String> absList = absentees.split(',').map((e) => e.trim()).toList();
      
      if (absList.contains(widget.student.rollNo)) {
        history.add({
          'date': log['date'],
          'subject': log['subject'],
          'timeSlot': log['timeSlot']
        });
      }
    }

    history.sort((a, b) => b['date'].compareTo(a['date']));

    if (mounted) {
      setState(() {
        _absentHistory = history;
        _isLoadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.deepPurple;
    bool isLowAttendance = widget.student.overallAttendancePercentage < 75;
    Color statusColor = isLowAttendance ? Colors.redAccent : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Profile"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: primaryColor,
            padding: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
            child: Row(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor, width: 4),
                  ),
                  child: Center(
                    child: Text(
                      "${widget.student.overallAttendancePercentage}%",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.student.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text("Roll No: ${widget.student.rollNo}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(widget.student.department, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: primaryColor,
              tabs: const [Tab(text: "Subject Wise"), Tab(text: "Absent History")],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.student.subjectRecords.length,
                  itemBuilder: (context, index) {
                    final sub = widget.student.subjectRecords[index];
                    int total = sub.present + sub.absent;
                    double percent = total == 0 ? 0 : (sub.present / total);
                    return ListTile(
                      title: Text(sub.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: LinearProgressIndicator(value: percent, color: percent < 0.75 ? Colors.red : Colors.green),
                      trailing: Text("${(percent * 100).toInt()}%"),
                    );
                  },
                ),
                _isLoadingHistory 
                  ? const Center(child: CircularProgressIndicator()) 
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _absentHistory.length,
                      itemBuilder: (context, index) {
                        final item = _absentHistory[index];
                        return ListTile(
                          title: Text(item['subject']),
                          subtitle: Text(DateFormat('dd MMM yyyy').format(DateTime.parse(item['date']))),
                          trailing: const Text("Absent", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}