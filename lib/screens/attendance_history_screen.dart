import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  // Filters
  int? _selectedSubjectId;
  DateTime? _selectedDate;
  
  // Data
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _subjects = []; // For Dropdown
  bool _isLoading = true;
  String? _errorMessage; // NEW: Track error state

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // Wrapped in try-catch to prevent crash if tables don't exist
      final subjects = await DatabaseHelper.instance.getDistinctSubjects();
      await _fetchLogs();
      
      if (mounted) {
        setState(() {
          _subjects = subjects;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint("Database Error: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Database Error: Please reinstall the app to fix database structure.";
        });
      }
    }
  }

  Future<void> _fetchLogs() async {
    try {
      String? dateStr;
      if (_selectedDate != null) {
        dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      }

      final data = await DatabaseHelper.instance.getAttendanceLogs(
        lectureId: _selectedSubjectId,
        date: dateStr,
      );
      
      if (mounted) {
        setState(() {
          _logs = data;
        });
      }
    } catch (e) {
      debugPrint("Fetch Logs Error: $e");
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedSubjectId = null;
      _selectedDate = null;
    });
    _fetchLogs();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchLogs(); // Auto-refresh on selection
    }
  }

  // Helper to format date string (yyyy-MM-dd -> dd-MM-yyyy)
  String _formatDisplayDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance History"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_off),
            tooltip: "Reset Filters",
            onPressed: _resetFilters,
          )
        ],
      ),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _loadInitialData,
                      child: const Text("Retry"),
                    )
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // --- FILTER SECTION ---
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      // 1. Subject Dropdown
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          value: _selectedSubjectId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: "Filter by Subject",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _subjects.map((s) {
                            return DropdownMenuItem<int>(
                              value: s['id'] as int,
                              child: Text(s['subject'] as String, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedSubjectId = val);
                            _fetchLogs();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      
                      // 2. Date Picker Button
                      Expanded(
                        flex: 1,
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(_selectedDate == null 
                            ? "All Dates" 
                            : DateFormat('dd/MM').format(_selectedDate!)
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.white,
                            foregroundColor: _selectedDate != null ? primaryColor : Colors.black,
                            side: BorderSide(color: _selectedDate != null ? primaryColor : Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- LOGS LIST ---
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : _logs.isEmpty 
                      ? const Center(child: Text("No records found.", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final absentees = log['absentees'].toString();
                            final count = absentees.isEmpty ? 0 : absentees.split(',').length;

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Date & Subject
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDisplayDate(log['date']), // Formatted Date
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            log['subject'],
                                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    // Body: Dept & Details
                                    Text("Faculty: ${log['faculty']} (${log['timeSlot']})", style: const TextStyle(fontSize: 12)),
                                    const Divider(),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            log['deptName'], 
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Total Absent: $count",
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                absentees.isEmpty ? "All Present" : absentees,
                                                style: TextStyle(color: Colors.grey[800]),
                                              ),
                                            ],
                                          ),
                                        )
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}