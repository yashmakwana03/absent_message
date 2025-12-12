import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For clipboard
import 'package:intl/intl.dart'; // Add intl to pubspec.yaml for date formatting
import '../database/database_helper.dart';
import '../models/department.dart';

class ReportGeneratorScreen extends StatefulWidget {
  const ReportGeneratorScreen({super.key});

  @override
  State<ReportGeneratorScreen> createState() => _ReportGeneratorScreenState();
}

class _ReportGeneratorScreenState extends State<ReportGeneratorScreen> {
  DateTime _selectedDate = DateTime.now();
  String _dayName = '';
  List<Map<String, dynamic>> _lectures = [];
  List<Department> _departments = [];
  bool _isLoading = true;

  // Stores inputs: Map<LectureIndex, Map<DeptId, Controller>>
  final Map<int, Map<int, TextEditingController>> _controllers = {};

  // Cache for student names: Map<DeptId, Map<RollNo, Name>>
  final Map<int, Map<String, String>> _studentCache = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // 1. Load Departments
    _departments = await DatabaseHelper.instance.readAllDepartments();
    
    // 2. Load All Students into Cache for fast lookup
    final students = await DatabaseHelper.instance.readAllStudentsWithDeptName();
    for (var s in students) {
      // We need to fetch the raw deptId. 
      // Note: readAllStudentsWithDeptName in previous steps might need modification to return deptId
      // Or we can just read raw 'Student' table. Let's assume we fetch raw students here for simplicity:
      final db = await DatabaseHelper.instance.database;
      final rawStudents = await db.query('Student');
      
      for(var row in rawStudents) {
        int dId = row['deptId'] as int;
        String rNo = row['rollNumber'] as String;
        String name = row['name'] as String;

        if (!_studentCache.containsKey(dId)) _studentCache[dId] = {};
        _studentCache[dId]![rNo] = name;
      }
    }

    _updateDayAndLectures();
  }

  void _updateDayAndLectures() async {
    setState(() => _isLoading = true);
    
    // Get Day Name (Monday, Tuesday...)
    _dayName = DateFormat('EEEE').format(_selectedDate);
    
    // Fetch lectures for this day
    _lectures = await DatabaseHelper.instance.getLecturesByDay(_dayName);

    // Initialize Controllers for inputs
    _controllers.clear();
    for (int i = 0; i < _lectures.length; i++) {
      _controllers[i] = {};
      for (var dept in _departments) {
        _controllers[i]![dept.id!] = TextEditingController();
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _updateDayAndLectures();
    }
  }

  // --- LOGIC: Generate the Message ---
  String _generateMessage() {
    final formattedDate = DateFormat('dd-MM-yyyy').format(_selectedDate);
    final gujaratiDays = {
      "Monday": "સોમવાર", "Tuesday": "મંગળવાર", "Wednesday": "બુધવાર",
      "Thursday": "ગુરુવાર", "Friday": "શુક્રવાર", "Saturday": "શનિવાર", "Sunday": "રવિવાર"
    };

    String report = "- *SEM-5 Attendance Report*\n";
    report += "આજે $formattedDate (${gujaratiDays[_dayName]}) ના રોજ ગેરહાજર રહેલા વિદ્યાર્થીઓની યાદી નીચે મુજબ છે\n";
    report += "Following is the list of students who remained absent today $formattedDate ($_dayName)\n\n";

    for (int i = 0; i < _lectures.length; i++) {
      final lecture = _lectures[i];
      bool hasAbsentees = false;
      String lectureBlock = "Subject: ${lecture['subject']}\nFaculty: ${lecture['faculty']} (${lecture['timeSlot']})\n";
      
      String absenteesBlock = "";

      for (var dept in _departments) {
        final text = _controllers[i]![dept.id]!.text.trim();
        if (text.isNotEmpty) {
          hasAbsentees = true;
          // Split by comma or space
          final rolls = text.split(RegExp(r'[, ]+'));
          List<String> formattedNames = [];

          for (var r in rolls) {
            r = r.trim();
            if (r.isEmpty) continue;
            // Lookup Name from Cache
            String name = _studentCache[dept.id]?[r] ?? "Unknown";
            formattedNames.add("$r - $name");
          }
          
          if (formattedNames.isNotEmpty) {
            absenteesBlock += "${dept.name} Absentees:\n${formattedNames.join('\n')}\n\n";
          }
        }
      }

      if (hasAbsentees) {
        report += lectureBlock + "\n" + absenteesBlock + "------------------------\n\n";
      }
    }
    return report;
  }

  void _copyToClipboard() {
    final text = _generateMessage();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report copied to clipboard!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Report'),
        actions: [
          IconButton(icon: const Icon(Icons.copy), onPressed: _copyToClipboard),
        ],
      ),
      body: Column(
        children: [
          // Date Picker Header
          ListTile(
            title: Text("Date: ${DateFormat('dd-MM-yyyy').format(_selectedDate)}"),
            subtitle: Text("Day: $_dayName"),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
            tileColor: Theme.of(context).colorScheme.primaryContainer,
          ),
          
          if (_isLoading) const Expanded(child: Center(child: CircularProgressIndicator())),
          
          if (!_isLoading && _lectures.isEmpty) 
            const Expanded(child: Center(child: Text("No lectures found for this day."))),

          if (!_isLoading && _lectures.isNotEmpty)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _lectures.length,
                separatorBuilder: (c, i) => const Divider(thickness: 2),
                itemBuilder: (context, index) {
                  final lecture = _lectures[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lecture Header
                      Text(
                        "${lecture['subject']} (${lecture['timeSlot']})",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text("Faculty: ${lecture['faculty']}", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: 8),
                      
                      // Dynamic Inputs for Each Department
                      ..._departments.map((dept) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: TextField(
                            controller: _controllers[index]![dept.id],
                            decoration: InputDecoration(
                              labelText: '${dept.name} Absentees (Roll Nos)',
                              hintText: 'e.g. 1, 5, 12',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}