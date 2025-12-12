import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_helper.dart';
import '../models/department.dart';

// --- 1. Helper Class to manage UI State for each Lecture ---
class LectureState {
  final int lectureId;
  final String title;
  final String faculty;
  final String time;
  
  // Map<DeptId, Controller>
  final Map<int, TextEditingController> controllers = {};
  // Map<DeptId, bool> (True = Direct/Absent, False = Inverse/Present)
  final Map<int, bool> isDirectMode = {};

  LectureState({
    required this.lectureId,
    required this.title,
    required this.faculty,
    required this.time,
    required List<Department> departments,
  }) {
    for (var dept in departments) {
      controllers[dept.id!] = TextEditingController();
      isDirectMode[dept.id!] = true; // Default to Entering Absentees (Direct)
    }
  }
}

class ReportGeneratorScreenV3 extends StatefulWidget {
  const ReportGeneratorScreenV3({super.key});

  @override
  State<ReportGeneratorScreenV3> createState() => _ReportGeneratorScreenV3State();
}

class _ReportGeneratorScreenV3State extends State<ReportGeneratorScreenV3> {
  DateTime _selectedDate = DateTime.now();
  String _dayName = '';
  
  List<Department> _departments = [];
  List<LectureState> _lectureStates = [];
  
  // Cache for Student Names & Roll Lists: Map<DeptId, List<StudentMap>>
  final Map<int, List<Map<String, dynamic>>> _studentCache = {};

  final TextEditingController _outputController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // --- DATA LOADING ---
  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    
    // 1. Load Departments
    _departments = await DatabaseHelper.instance.readAllDepartments();

    // 2. Cache All Students (Needed for "Present" mode logic)
    final db = await DatabaseHelper.instance.database;
    final rawStudents = await db.query('Student');
    
    _studentCache.clear();
    for (var row in rawStudents) {
      int dId = row['deptId'] as int;
      if (!_studentCache.containsKey(dId)) _studentCache[dId] = [];
      _studentCache[dId]!.add(row);
    }

    // 3. Load Lectures for Today
    await _loadLecturesForDate();
  }

  Future<void> _loadLecturesForDate() async {
    setState(() => _isLoading = true);
    _dayName = DateFormat('EEEE').format(_selectedDate);
    
    // Fetch from SQLite
    final lectures = await DatabaseHelper.instance.getLecturesByDay(_dayName);
    
    // Convert to UI State Objects
    _lectureStates = lectures.map((l) => LectureState(
      lectureId: l['id'],
      title: l['subject'],
      faculty: l['faculty'],
      time: l['timeSlot'],
      departments: _departments,
    )).toList();

    // 4. Try Loading Saved Draft for this Date
    await _loadDraft();

    setState(() => _isLoading = false);
  }

  // --- DRAFT SYSTEM (Shared Preferences) ---
  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    for (var lecture in _lectureStates) {
      for (var dept in _departments) {
        // Key format: draft_DATE_LECTUREID_DEPTID_text
        String baseKey = "draft_${dateKey}_${lecture.lectureId}_${dept.id}";
        
        // Save Text
        await prefs.setString("${baseKey}_text", lecture.controllers[dept.id]!.text);
        // Save Mode (Direct/Inverse)
        await prefs.setBool("${baseKey}_mode", lecture.isDirectMode[dept.id]!);
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved locally!')),
      );
      // Also generate the message when saving
      _generateMessage(); 
    }
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);

    for (var lecture in _lectureStates) {
      for (var dept in _departments) {
        String baseKey = "draft_${dateKey}_${lecture.lectureId}_${dept.id}";
        
        String? savedText = prefs.getString("${baseKey}_text");
        bool? savedMode = prefs.getBool("${baseKey}_mode");

        if (savedText != null) {
          lecture.controllers[dept.id]!.text = savedText;
        }
        if (savedMode != null) {
          lecture.isDirectMode[dept.id!] = savedMode;
        }
      }
    }
  }

  // --- CORE LOGIC: ABSENT VS PRESENT ---
  List<String> _calculateAbsentees(int deptId, String input, bool isDirectMode) {
    if (input.trim().isEmpty) return [];

    List<String> inputRolls = input
        .split(RegExp(r'[, ]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (isDirectMode) {
      // Input = Absent Students
      return inputRolls;
    } else {
      // Input = Present Students (Calculate Inverse)
      List<String> actualAbsentees = [];
      final allStudents = _studentCache[deptId] ?? [];

      for (var s in allStudents) {
        String roll = s['rollNumber'].toString();
        // If student exists in DB but NOT in input list -> They are absent
        if (!inputRolls.contains(roll)) {
          actualAbsentees.add(roll);
        }
      }
      return actualAbsentees;
    }
  }

  String _formatNames(int deptId, List<String> rollList) {
    if (rollList.isEmpty) return "None";

    final studentsInDept = _studentCache[deptId] ?? [];
    Map<String, String> nameMap = {
      for (var s in studentsInDept) s['rollNumber'].toString(): s['name'].toString()
    };

    // Numerical Sort
    try {
      rollList.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    } catch (e) { /* ignore */ }

    List<String> result = [];
    for (var roll in rollList) {
      String name = nameMap[roll] ?? "Unknown";
      result.add("$roll - $name");
    }
    return result.join('\n');
  }

  // --- GENERATE & SHARE ---
  void _generateMessage() {
    final formattedDate = DateFormat('dd-MM-yyyy').format(_selectedDate);
    final gujaratiDays = {
      "Monday": "સોમવાર", "Tuesday": "મંગળવાર", "Wednesday": "બુધવાર",
      "Thursday": "ગુરુવાર", "Friday": "શુક્રવાર", "Saturday": "શનિવાર", "Sunday": "રવિવાર"
    };

    StringBuffer buffer = StringBuffer();
    // buffer.writeln("- *Attendance Report*");
    buffer.writeln("આજે $formattedDate (${gujaratiDays[_dayName] ?? _dayName}) ના રોજ ગેરહાજર રહેલા વિદ્યાર્થીઓની યાદી નીચે મુજબ છે");
    buffer.writeln("Following is the list of students who remained absent today $formattedDate ($_dayName)\n");

    if (_lectureStates.isEmpty) {
      buffer.writeln("No lectures scheduled.");
    }

    for (var lecture in _lectureStates) {
      buffer.writeln("*${lecture.title} - ${lecture.faculty} (${lecture.time})*\n");

      for (var dept in _departments) {
        List<String> absentees = _calculateAbsentees(
          dept.id!, 
          lecture.controllers[dept.id]!.text, 
          lecture.isDirectMode[dept.id]!
        );

        if (absentees.isNotEmpty) {
          buffer.writeln("${dept.name} Absentees :");
          buffer.writeln(_formatNames(dept.id!, absentees));
          buffer.writeln();
        }
      }
      buffer.writeln("------------------------\n");
    }

    setState(() {
      _outputController.text = buffer.toString();
    });
  }

  void _copyToClipboard() {
    if (_outputController.text.isEmpty) _generateMessage();
    Clipboard.setData(ClipboardData(text: _outputController.text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to Clipboard!')));
  }

  Future<void> _shareToWhatsApp() async {
    if (_outputController.text.isEmpty) _generateMessage();
    
    String message = _outputController.text;
    String urlString = "whatsapp://send?text=${Uri.encodeComponent(message)}";
    
    try {
      await launchUrl(Uri.parse(urlString));
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Light grey background
      appBar: AppBar(
        title: const Text('Daily Report Generator'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context, 
                initialDate: _selectedDate, 
                firstDate: DateTime(2024), 
                lastDate: DateTime(2030)
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadLecturesForDate();
              }
            },
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Header
                Text(
                  "$_dayName, ${DateFormat('dd-MM-yyyy').format(_selectedDate)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                if (_lectureStates.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(20), child: Text("No lectures found for this day."))),

                // Lecture Cards
                ..._lectureStates.map((lecture) => LectureCard(
                  lecture: lecture,
                  departments: _departments,
                  studentCache: _studentCache, // <--- ADD THIS LINE (Pass the cache)
                  onStateChange: () => setState((){}), // Refresh UI when checkbox changes
                )),

                const SizedBox(height: 20),
                const Text("Generated Message", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                
                // Read-Only View of Message
                TextField(
                  controller: _outputController,
                  maxLines: 8,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: "Click Save or Copy to generate report...",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                
                const SizedBox(height: 20),

                // --- THE 3 BUTTONS ---
                Row(
                  children: [
                    // 1. SAVE DRAFT
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save_as),
                        label: const Text("Save Draft"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _saveDraft,
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // 2. COPY
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text("Copy"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _copyToClipboard,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 3. WHATSAPP
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text("WhatsApp"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _shareToWhatsApp,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
    );
  }
}

// --- UI WIDGET FOR CARD (With Validation) ---
class LectureCard extends StatefulWidget {
  final LectureState lecture;
  final List<Department> departments;
  final VoidCallback onStateChange;
  // We need to pass the student cache to know the max roll number for each dept
  final Map<int, List<Map<String, dynamic>>> studentCache;

  const LectureCard({
    super.key,
    required this.lecture,
    required this.departments,
    required this.onStateChange,
    required this.studentCache,
  });

  @override
  State<LectureCard> createState() => _LectureCardState();
}

class _LectureCardState extends State<LectureCard> {
  // Store error messages for each department field: Map<DeptId, String?>
  final Map<int, String?> _errors = {};

  void _validateInput(int deptId, String value) {
    if (value.isEmpty) {
      setState(() => _errors[deptId] = null);
      return;
    }

    final List<String> rawParts = value.split(RegExp(r'[, ]+'));
    final Set<String> uniqueNumbers = {};
    final List<String> duplicates = [];
    final List<String> outOfBounds = [];

    // Get max students for this department
    final studentList = widget.studentCache[deptId] ?? [];
    // Assuming roll numbers are numeric for max check. 
    // If your roll numbers are strings like "C001", this logic implies simple count check or needs regex.
    // Here we strictly check if the entered number Exists in the database list.
    final validRollNumbers = studentList.map((s) => s['rollNumber'].toString()).toSet();

    for (var part in rawParts) {
      part = part.trim();
      if (part.isEmpty) continue;

      // 1. Check for Duplicates
      if (uniqueNumbers.contains(part)) {
        duplicates.add(part);
      } else {
        uniqueNumbers.add(part);
      }

      // 2. Check if Valid (Exists in DB)
      if (!validRollNumbers.contains(part)) {
        outOfBounds.add(part);
      }
    }

    String? errorMsg;
    if (duplicates.isNotEmpty) {
      errorMsg = "Duplicate: ${duplicates.join(', ')}";
    } else if (outOfBounds.isNotEmpty) {
      errorMsg = "Invalid Roll No: ${outOfBounds.join(', ')}";
    }

    setState(() {
      _errors[deptId] = errorMsg;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              "${widget.lecture.title} (${widget.lecture.time})",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              "Faculty: ${widget.lecture.faculty}",
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const Divider(),

            // Department Rows
            ...widget.departments.map((dept) {
              bool isDirect = widget.lecture.isDirectMode[dept.id]!;
              String? errorText = _errors[dept.id];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start, // Align to top
                      children: [
                        // Dept Name Label
                        SizedBox(
                          width: 40,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Text(dept.name,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // Text Field
                        Expanded(
                          child: TextField(
                            controller: widget.lecture.controllers[dept.id],
                            keyboardType: TextInputType.number,
                            // Call validation on every keystroke
                            onChanged: (val) => _validateInput(dept.id!, val),
                            decoration: InputDecoration(
                              hintText: isDirect
                                  ? "Enter Absent (e.g. 1, 5)"
                                  : "Enter Present (Calc Inverse)",
                              hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: isDirect
                                      ? Colors.grey
                                      : Colors.orange.shade700),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              // Show Red Border if error
                              errorText: errorText, 
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: errorText != null 
                                        ? Colors.red 
                                        : (isDirect ? Colors.indigo : Colors.orange)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),

                        // Checkbox Logic
                        Padding(
                          padding: const EdgeInsets.only(top: 0.0),
                          child: Tooltip(
                            message: isDirect
                                ? "Mode: Entering Absentees"
                                : "Mode: Entering Present",
                            child: Transform.scale(
                              scale: 1.1,
                              child: Checkbox(
                                value: isDirect,
                                activeColor: Colors.indigo,
                                side: isDirect
                                    ? null
                                    : const BorderSide(color: Colors.orange, width: 2),
                                onChanged: (val) {
                                  widget.lecture.isDirectMode[dept.id!] = val ?? true;
                                  widget.onStateChange();
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}