import 'dart:async'; // Required for Debounce (Auto-save)
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
  
  final Map<int, List<Map<String, dynamic>>> _studentCache = {};
  final TextEditingController _outputController = TextEditingController();
  bool _isLoading = true;

  // --- Auto-Save Timer ---
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _debounce?.cancel(); // Cancel timer when screen closes
    super.dispose();
  }

  // --- AUTO-SAVE LOGIC ---
  void _triggerAutoSave() {
    // Cancel previous timer if user is still typing
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // Wait for 1 second of inactivity, then save
    _debounce = Timer(const Duration(seconds: 1), () {
      _saveDraft(silent: true);
    });
    
    // Also update the message preview instantly
    _generateMessage();
  }

  // --- SAVE HISTORY LOG ---
  Future<void> _saveToHistory() async {
    bool hasData = false;
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    for (var lecture in _lectureStates) {
      for (var dept in _departments) {
        List<String> absentees = _calculateAbsentees(
          dept.id!,
          lecture.controllers[dept.id]!.text,
          lecture.isDirectMode[dept.id]!,
        );

        // Save entry
        await DatabaseHelper.instance.createAttendanceLog({
          'date': dateStr,
          'lectureId': lecture.lectureId,
          'deptId': dept.id,
          'absentees': absentees.join(','),
        });
        hasData = true;
      }
    }

    if (hasData && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Log Saved Successfully!'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }
  }

  // --- DATA LOADING ---
  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    _departments = await DatabaseHelper.instance.readAllDepartments();

    final db = await DatabaseHelper.instance.database;
    final rawStudents = await db.query('Student');
    
    _studentCache.clear();
    for (var row in rawStudents) {
      int dId = row['deptId'] as int;
      if (!_studentCache.containsKey(dId)) _studentCache[dId] = [];
      _studentCache[dId]!.add(row);
    }

    await _loadLecturesForDate();
  }

  Future<void> _loadLecturesForDate() async {
    setState(() => _isLoading = true);
    _dayName = DateFormat('EEEE').format(_selectedDate);
    
    List<Map<String, dynamic>> lectures = await DatabaseHelper.instance.getLecturesByDay(_dayName);
    
    // FORCE SORT BY ID
    lectures = List.of(lectures);
    lectures.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

    _lectureStates = lectures.map((l) => LectureState(
      lectureId: l['id'],
      title: l['subject'],
      faculty: l['faculty'],
      time: l['timeSlot'],
      departments: _departments,
    )).toList();

    await _loadDraft(); // Load saved data
    setState(() => _isLoading = false);
    
    // Generate initial message after loading draft
    _generateMessage();
  }

  // --- DRAFT SYSTEM ---
  Future<void> _saveDraft({bool silent = false}) async {
    final prefs = await SharedPreferences.getInstance();
    String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    for (var lecture in _lectureStates) {
      for (var dept in _departments) {
        String baseKey = "draft_${dateKey}_${lecture.lectureId}_${dept.id}";
        await prefs.setString("${baseKey}_text", lecture.controllers[dept.id]!.text);
        await prefs.setBool("${baseKey}_mode", lecture.isDirectMode[dept.id]!);
      }
    }
    
    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved!')),
      );
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

        if (savedText != null) lecture.controllers[dept.id]!.text = savedText;
        if (savedMode != null) lecture.isDirectMode[dept.id!] = savedMode;
      }
    }
  }

  // --- CALCULATION LOGIC ---
  List<String> _calculateAbsentees(int deptId, String input, bool isDirectMode) {
    if (input.trim().isEmpty) return [];

    List<String> inputRolls = input
        .split(RegExp(r'[, ]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (isDirectMode) {
      return inputRolls;
    } else {
      List<String> actualAbsentees = [];
      final allStudents = _studentCache[deptId] ?? [];
      for (var s in allStudents) {
        String roll = s['rollNumber'].toString();
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

  void _generateMessage() {
    final formattedDate = DateFormat('dd-MM-yyyy').format(_selectedDate);
    final gujaratiDays = {
      "Monday": "સોમવાર", "Tuesday": "મંગળવાર", "Wednesday": "બુધવાર",
      "Thursday": "ગુરુવાર", "Friday": "શુક્રવાર", "Saturday": "શનિવાર", "Sunday": "રવિવાર"
    };

    StringBuffer buffer = StringBuffer();
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch WhatsApp')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
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
                Text(
                  "$_dayName, ${DateFormat('dd-MM-yyyy').format(_selectedDate)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                if (_lectureStates.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(20), child: Text("No lectures found."))),

                ..._lectureStates.map((lecture) => LectureCard(
                  lecture: lecture,
                  departments: _departments,
                  studentCache: _studentCache,
                  onStateChange: _triggerAutoSave, // <--- Triggers Auto-Save
                )),

                const SizedBox(height: 20),
                const Text("Generated Message", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                
                TextField(
                  controller: _outputController,
                  maxLines: 8,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: "Report will appear here...",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                
                const SizedBox(height: 20),

                // --- 3 BUTTONS (Saved Draft Removed) ---
                Row(
                  children: [
                    // 1. COPY
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text("Copy"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _copyToClipboard,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 2. WHATSAPP
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text("WhatsApp"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _shareToWhatsApp,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 3. SAVE LOG (With Database Logic)
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.history),
                        label: const Text("Save Log"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _saveToHistory,
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

// --- UPDATED LECTURE CARD (With Count & Validation) ---
class LectureCard extends StatefulWidget {
  final LectureState lecture;
  final List<Department> departments;
  final VoidCallback onStateChange;
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
  final Map<int, String?> _errors = {};
  // Track counts: Map<DeptId, int>
  final Map<int, int> _counts = {};

  @override
  void initState() {
    super.initState();
    // Initialize counts for existing text
    for (var dept in widget.departments) {
      _updateCount(dept.id!, widget.lecture.controllers[dept.id]!.text);
    }
  }

  void _updateCount(int deptId, String value) {
    if (value.trim().isEmpty) {
      _counts[deptId] = 0;
      return;
    }
    // Count comma-separated items
    final count = value.split(',').where((e) => e.trim().isNotEmpty).length;
    _counts[deptId] = count;
  }

  void _validateInput(int deptId, String value) {
    // 1. Update Count
    setState(() {
      _updateCount(deptId, value);
    });

    // 2. Trigger Auto-Save in Parent
    widget.onStateChange();

    if (value.isEmpty) {
      setState(() => _errors[deptId] = null);
      return;
    }

    final List<String> rawParts = value.split(RegExp(r'[, ]+'));
    final Set<String> uniqueNumbers = {};
    final List<String> duplicates = [];
    final List<String> outOfBounds = [];

    final studentList = widget.studentCache[deptId] ?? [];
    final validRollNumbers = studentList.map((s) => s['rollNumber'].toString()).toSet();

    for (var part in rawParts) {
      part = part.trim();
      if (part.isEmpty) continue;

      if (uniqueNumbers.contains(part)) {
        duplicates.add(part);
      } else {
        uniqueNumbers.add(part);
      }

      if (!validRollNumbers.contains(part)) {
        outOfBounds.add(part);
      }
    }

    String? errorMsg;
    if (duplicates.isNotEmpty) {
      errorMsg = "Duplicate: ${duplicates.join(', ')}";
    } else if (outOfBounds.isNotEmpty) {
      errorMsg = "Invalid: ${outOfBounds.join(', ')}";
    }

    setState(() {
      _errors[deptId] = errorMsg;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

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
            Text(
              "${widget.lecture.title} (${widget.lecture.time})",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              "Faculty: ${widget.lecture.faculty}",
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const Divider(),

            ...widget.departments.map((dept) {
              bool isDirect = widget.lecture.isDirectMode[dept.id]!;
              String? errorText = _errors[dept.id];
              int currentCount = _counts[dept.id] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 40,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Text(dept.name,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        Expanded(
                          child: TextField(
                            controller: widget.lecture.controllers[dept.id],
                            keyboardType: TextInputType.number,
                            onChanged: (val) => _validateInput(dept.id!, val),
                            decoration: InputDecoration(
                              hintText: isDirect ? "Absent (e.g. 1,5)" : "Present",
                              hintStyle: TextStyle(fontSize: 12, color: isDirect ? Colors.grey : Colors.orange.shade700),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              errorText: errorText, 
                              
                              // --- NEW: COUNT INDICATOR ---
                              suffixText: "Total: $currentCount",
                              suffixStyle: TextStyle(
                                fontSize: 12, 
                                fontWeight: FontWeight.bold,
                                color: currentCount > 0 ? primaryColor : Colors.grey,
                              ),
                              
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: errorText != null 
                                        ? Colors.red 
                                        : (isDirect ? primaryColor : Colors.orange)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),

                        Padding(
                          padding: const EdgeInsets.only(top: 0.0),
                          child: Tooltip(
                            message: isDirect ? "Mode: Entering Absentees" : "Mode: Entering Present",
                            child: Transform.scale(
                              scale: 1.1,
                              child: Checkbox(
                                value: isDirect,
                                activeColor: primaryColor,
                                side: isDirect ? null : const BorderSide(color: Colors.orange, width: 2),
                                onChanged: (val) {
                                  widget.lecture.isDirectMode[dept.id!] = val ?? true;
                                  // Update counts because mode changed (logic is handled in parent mostly, but we trigger auto-save)
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