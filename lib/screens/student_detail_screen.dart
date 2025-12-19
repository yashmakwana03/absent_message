import 'package:flutter/material.dart';
import '../models/student_report_models.dart';

class StudentDetailScreen extends StatelessWidget {
  final StudentReport student;
  const StudentDetailScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Student Report'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Roll No: ${student.rollNo}', style: const TextStyle(color: Colors.grey, fontSize: 15)),
                  Text('Dept: ${student.department}', style: const TextStyle(color: Colors.grey, fontSize: 15)),
                ]),
                const Spacer(),
                CircularProgressIndicator(
                  value: student.overallAttendancePercentage / 100,
                  backgroundColor: Colors.grey[200],
                  color: student.overallAttendancePercentage < 75 ? Colors.red : Colors.green,
                )
              ]),
            ]),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _SummaryBox(label: 'Total Absent', value: '${student.totalAbsentLectures}', bgColor: const Color(0xFFFFF1F2), textColor: Colors.red)),
            const SizedBox(width: 16),
            Expanded(child: _SummaryBox(label: 'Attendance %', value: '${student.overallAttendancePercentage}%', bgColor: const Color(0xFFECFDF5), textColor: Colors.green)),
          ]),
          const SizedBox(height: 24),
          Card(
            elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const Text('Report Lecture Wise', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(height: 24),
                if (student.subjectRecords.isEmpty) const Text("No records found", style: TextStyle(color: Colors.grey)),
                ...student.subjectRecords.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Expanded(flex: 4, child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Center(child: Text('${r.present} P', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)))),
                    Expanded(flex: 2, child: Center(child: Text('${r.absent} A', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))),
                    Expanded(flex: 2, child: Center(child: Text('${r.percentage}%', style: TextStyle(color: r.percentage < 75 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)))),
                  ]),
                )),
              ]),
            ),
          )
        ]),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String label; final String value; final Color bgColor; final Color textColor;
  const _SummaryBox({required this.label, required this.value, required this.bgColor, required this.textColor});
  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)), child: Column(children: [Text(label, style: TextStyle(color: textColor.withOpacity(0.8), fontWeight: FontWeight.w600)), const SizedBox(height: 8), Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor))]));
  }
}