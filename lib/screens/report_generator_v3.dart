import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_helper.dart';
import '../models/department.dart';

// --- HELPER CLASS ---
class LectureState {
  final int lectureId;
  final String title;
  final String faculty;
  final String time;
  final Map<int, TextEditingController> controllers = {};
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
      isDirectMode[dept.id!] = true; 
    }
  }
}

class ReportGeneratorScreenV3 extends StatefulWidget {
  final DateTime? initialDate;
  const ReportGeneratorScreenV3({super.key, this.initialDate});

  @override
  State<ReportGeneratorScreenV3> createState() => _ReportGeneratorScreenV3State();
}

class _ReportGeneratorScreenV3State extends State<ReportGeneratorScreenV3> {
  late DateTime _selectedDate;
  String _dayName = '';
  List<Department> _departments = [];
  List<LectureState> _lectureStates = [];
  final Map<int, List<Map<String, dynamic>>> _studentCache = {};
  final TextEditingController _outputController = TextEditingController();
  bool _isLoading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _initializeData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _triggerAutoSave() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(seconds: 1), () => _saveDraft(silent: true));
    _generateMessage();
  }

  // --- 💾 DATABASE SAVE (The "Submit" Action) ---
  Future<void> _submitAttendance() async {
    bool hasData = false;
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    for (var lecture in _lectureStates) {
      for (var dept in _departments) {
        // Calculate the actual list of absent roll numbers
        List<String> absentees = _calculateAbsentees(
          dept.id!,
          lecture.controllers[dept.id]!.text,
          lecture.isDirectMode[dept.id]!,
        );
        
        // Save to Database (Overwrite existing entry for this day/lecture/dept)
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
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Attendance Submitted Successfully!'),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

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
    lectures = List.of(lectures);
    lectures.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

    _lectureStates = lectures.map((l) => LectureState(
      lectureId: l['id'],
      title: l['subject'],
      faculty: l['faculty'],
      time: l['timeSlot'],
      departments: _departments,
    )).toList();

    await _loadDraft(); 
    await _loadExistingDataFromDB(); // Pre-fill if editing

    setState(() => _isLoading = false);
    _generateMessage();
  }

  Future<void> _loadExistingDataFromDB() async {
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final existingLogs = await DatabaseHelper.instance.getAttendanceLogs(date: dateStr);

    for (var log in existingLogs) {
      for (var lecture in _lectureStates) {
        if (lecture.title == log['subject'] && lecture.time == log['timeSlot']) {
           String deptName = log['deptName'];
           var dept = _departments.firstWhere((d) => d.name == deptName, orElse: () => Department(name: ''));
           // Only load from DB if the controller is empty (Drafts take priority)
           if (dept.id != null && lecture.controllers[dept.id]!.text.isEmpty) {
             lecture.controllers[dept.id]!.text = log['absentees'];
           }
        }
      }
    }
  }

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved!')));
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
        if (savedText != null && savedText.isNotEmpty) {
           lecture.controllers[dept.id]!.text = savedText;
        }
        if (savedMode != null) lecture.isDirectMode[dept.id!] = savedMode;
      }
    }
  }

  List<String> _calculateAbsentees(int deptId, String input, bool isDirectMode) {
    if (input.trim().isEmpty) return [];
    List<String> inputRolls = input.split(RegExp(r'[, ]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (isDirectMode) return inputRolls;
    List<String> actualAbsentees = [];
    final allStudents = _studentCache[deptId] ?? [];
    for (var s in allStudents) {
      String roll = s['rollNumber'].toString();
      if (!inputRolls.contains(roll)) actualAbsentees.add(roll);
    }
    return actualAbsentees;
  }

  String _formatNames(int deptId, List<String> rollList) {
    if (rollList.isEmpty) return "None";
    final studentsInDept = _studentCache[deptId] ?? [];
    Map<String, String> nameMap = { for (var s in studentsInDept) s['rollNumber'].toString(): s['name'].toString() };
    try { rollList.sort((a, b) => int.parse(a).compareTo(int.parse(b))); } catch (e) { /* ignore */ }
    return rollList.map((roll) => "$roll - ${nameMap[roll] ?? "Unknown"}").join('\n');
  }

  // --- No Emojis in Text ---
  void _generateMessage() {
    final formattedDate = DateFormat('dd-MM-yyyy').format(_selectedDate);
    final gujaratiDays = { "Monday": "સોમવાર", "Tuesday": "મંગળવાર", "Wednesday": "બુધવાર", "Thursday": "ગુરુવાર", "Friday": "શુક્રવાર", "Saturday": "શનિવાર", "Sunday": "રવિવાર" };

    StringBuffer buffer = StringBuffer();
    // Gujarati Header
    buffer.writeln("આજે $formattedDate (${gujaratiDays[_dayName] ?? _dayName}) ના રોજ ગેરહાજર રહેલા વિદ્યાર્થીઓની યાદી નીચે મુજબ છે");
    // English Header
    buffer.writeln("Following is the list of students who remained absent today $formattedDate ($_dayName)\n");

    if (_lectureStates.isEmpty) buffer.writeln("No lectures scheduled.");

    for (var lecture in _lectureStates) {
      buffer.writeln("*${lecture.title} - ${lecture.faculty} (${lecture.time})*\n");
      for (var dept in _departments) {
        List<String> absentees = _calculateAbsentees(dept.id!, lecture.controllers[dept.id]!.text, lecture.isDirectMode[dept.id]!);
        if (absentees.isNotEmpty) {
          buffer.writeln("${dept.name} Absentees :");
          buffer.writeln(_formatNames(dept.id!, absentees));
          buffer.writeln();
        }
      }
      buffer.writeln("------------------------\n");
    }
    setState(() => _outputController.text = buffer.toString());
  }

  void _copyToClipboard() {
    if (_outputController.text.isEmpty) _generateMessage();
    Clipboard.setData(ClipboardData(text: _outputController.text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to Clipboard!')));
  }

  Future<void> _shareToWhatsApp() async {
    if (_outputController.text.isEmpty) _generateMessage();
    String urlString = "whatsapp://send?text=${Uri.encodeComponent(_outputController.text)}";
    try { await launchUrl(Uri.parse(urlString)); } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch WhatsApp')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: "Change Date",
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadLecturesForDate();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dayName,
                      style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      DateFormat('MMMM dd, yyyy').format(_selectedDate),
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_lectureStates.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(Icons.event_busy, size: 48, color: colorScheme.outline),
                          const SizedBox(height: 16),
                          Text("No lectures found.", style: TextStyle(color: colorScheme.outline)),
                        ],
                      ),
                    ),
                  ),

                ..._lectureStates.map((lecture) => LectureCard(
                      lecture: lecture,
                      departments: _departments,
                      studentCache: _studentCache,
                      onStateChange: _triggerAutoSave,
                    )),

                const SizedBox(height: 24),
                Text("Message Preview", style: textTheme.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _outputController,
                  maxLines: 6,
                  readOnly: true,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text("Copy"),
                        onPressed: _copyToClipboard,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text("WhatsApp"),
                        onPressed: _shareToWhatsApp,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // --- SUBMIT BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      // CHANGE THIS LINE:
                      backgroundColor: Colors.deepPurple, // Was Colors.green[700]
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4, // Added shadow for better look
                    ),
                    icon: const Icon(Icons.check_circle, size: 22),
                    label: const Text("Submit Attendance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: _submitAttendance,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}

// --- LectureCard UI ---
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
  final Map<int, int> _counts = {};

  @override
  void initState() {
    super.initState();
    for (var dept in widget.departments) {
      _updateCount(dept.id!, widget.lecture.controllers[dept.id]!.text);
    }
  }

  void _updateCount(int deptId, String value) {
    if (value.trim().isEmpty) {
      _counts[deptId] = 0;
      return;
    }
    final count = value.split(',').where((e) => e.trim().isNotEmpty).length;
    _counts[deptId] = count;
  }

  void _validateInput(int deptId, String value) {
    setState(() => _updateCount(deptId, value));
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

    setState(() => _errors[deptId] = errorMsg);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2, 
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.lecture.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${widget.lecture.faculty} • ${widget.lecture.time}",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.class_outlined, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            ...widget.departments.map((dept) {
              bool isDirect = widget.lecture.isDirectMode[dept.id]!;
              String? errorText = _errors[dept.id];
              int currentCount = _counts[dept.id] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: TextField(
                  controller: widget.lecture.controllers[dept.id],
                  keyboardType: TextInputType.number,
                  maxLines: null,
                  minLines: 1,
                  onChanged: (val) => _validateInput(dept.id!, val),
                  decoration: InputDecoration(
                    labelText: dept.name,
                    alignLabelWithHint: true,
                    
                    counter: Text(
                      currentCount > 0 ? "$currentCount Students" : "",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),

                    hintText: isDirect ? "Enter Absent Roll No." : "Enter Present Roll No.",
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                    
                    suffixIcon: Tooltip(
                      message: isDirect ? "Mode: Absent" : "Mode: Present",
                      child: IconButton(
                        icon: Icon(
                          isDirect ? Icons.person_off_outlined : Icons.how_to_reg,
                          color: isDirect ? colorScheme.error : colorScheme.primary,
                        ),
                        onPressed: () {
                           setState(() {
                             widget.lecture.isDirectMode[dept.id!] = !isDirect;
                             widget.onStateChange();
                           });
                        },
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}