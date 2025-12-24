import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

class AttendanceLogScreen extends StatefulWidget {
  const AttendanceLogScreen({super.key});

  @override
  State<AttendanceLogScreen> createState() => _AttendanceLogScreenState();
}

class _AttendanceLogScreenState extends State<AttendanceLogScreen> {
  bool _isLoading = true;

  // Structure: Map<DateString, Map<Subject_Time_Key, List<LogEntry>>>
  Map<String, Map<String, List<Map<String, dynamic>>>> _groupedLogs = {};

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);

    final data = await DatabaseHelper.instance.getAttendanceLogs();

    // --- NEW GROUPING LOGIC ---
    // 1. Group by Date
    // 2. Group by "Subject + Time" (to make one card per lecture)
    Map<String, Map<String, List<Map<String, dynamic>>>> hierarchy = {};

    for (var log in data) {
      String date = log['date'];
      String subjectKey = "${log['subject']} • ${log['timeSlot']}";

      if (!hierarchy.containsKey(date)) {
        hierarchy[date] = {};
      }
      if (!hierarchy[date]!.containsKey(subjectKey)) {
        hierarchy[date]![subjectKey] = [];
      }
      hierarchy[date]![subjectKey]!.add(log);
    }

    if (mounted) {
      setState(() {
        _groupedLogs = hierarchy;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteLog(int id) async {
    bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete Entry?"),
            content: const Text("Remove this department's record from the log?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Delete"),
              ),
            ],
          ),
        ) ?? false;

    if (confirm) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('AttendanceLog', where: 'id = ?', whereArgs: [id]);
      _fetchLogs(); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Record deleted")));
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.deepPurple;
    final sortedDates = _groupedLogs.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Clean background
      appBar: AppBar(
        title: const Text("View Logs"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : sortedDates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_edu, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text("No logs found.", style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedDates.length,
                  itemBuilder: (context, index) {
                    String dateKey = sortedDates[index];
                    Map<String, List<Map<String, dynamic>>> sessions = _groupedLogs[dateKey]!;
                    DateTime dt = DateTime.parse(dateKey);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- H1: DATE HEADER ---
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, top: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  DateFormat('dd MMM').format(dt).toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                DateFormat('EEEE, yyyy').format(dt),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),

                        // --- SESSION CARDS ---
                        ...sessions.entries.map((entry) {
                          String subjectHeader = entry.key; // "Subject • Time"
                          List<Map<String, dynamic>> deptLogs = entry.value;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // --- H2: SUBJECT HEADER (Card Top) ---
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                    border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                                        child: const Icon(Icons.class_, size: 18, color: primaryColor),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          subjectHeader,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // --- DEPARTMENT LIST (Rows) ---
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: deptLogs.map((log) {
                                      String absentees = log['absentees'] ?? "";
                                      bool hasAbsentees = absentees.isNotEmpty;

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // 1. Dept Name Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.grey.shade300),
                                              ),
                                              child: Text(
                                                log['deptName'],
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                              ),
                                            ),
                                            
                                            const SizedBox(width: 10),

                                            // 2. Numbers in Box
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: hasAbsentees ? Colors.red.shade50 : Colors.green.shade50,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: hasAbsentees ? Colors.red.shade100 : Colors.green.shade100),
                                                ),
                                                child: Text(
                                                  hasAbsentees ? absentees : "All Present",
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    height: 1.4,
                                                    color: hasAbsentees ? Colors.black87 : Colors.green.shade700,
                                                    fontFamily: hasAbsentees ? 'monospace' : null,
                                                    fontWeight: hasAbsentees ? FontWeight.normal : FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            // 3. Side Delete Button
                                            IconButton(
                                              onPressed: () => _deleteLog(log['id']),
                                              icon: const Icon(Icons.delete_outline),
                                              color: Colors.grey.shade400,
                                              hoverColor: Colors.red.shade50,
                                              iconSize: 20,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              tooltip: "Delete Entry",
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
    );
  }
}