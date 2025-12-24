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
  final bool isElective;
  final Set<int> relevantDeptIds;
  final String? error;

  final Map<int, TextEditingController> controllers = {};
  final Map<int, bool> isDirectMode = {};

  LectureState({
    required this.lectureId,
    required this.title,
    required this.faculty,
    required this.time,
    required this.isElective,
    required this.relevantDeptIds,
    required List<Department> departments,
    this.error,
  }) {
    for (var deptId in relevantDeptIds) {
      controllers[deptId] = TextEditingController();
      isDirectMode[deptId] = true;
    }
  }
}

class ReportGeneratorScreenV3 extends StatefulWidget {
  final DateTime? initialDate;
  const ReportGeneratorScreenV3({super.key, this.initialDate});

  @override
  State<ReportGeneratorScreenV3> createState() =>
      _ReportGeneratorScreenV3State();
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

  // --- LANGUAGE SETTINGS (Default: English Only) ---
  bool _showEnglish = true;
  bool _showGujarati = false;

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
    _debounce = Timer(
      const Duration(seconds: 1),
      () => _saveDraft(silent: true),
    );
    _generateMessage();
  }

  Future<void> _submitAttendance() async {
    bool hasData = false;
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    for (var lecture in _lectureStates) {
      if (lecture.error != null) continue;

      for (var deptId in lecture.relevantDeptIds) {
        String input = lecture.controllers[deptId]?.text ?? "";
        if (input.trim().isEmpty) continue;

        List<String> absentees = await _calculateAbsentees(
          lecture,
          deptId,
          input,
          lecture.isDirectMode[deptId]!,
        );

        await DatabaseHelper.instance.createAttendanceLog({
          'date': dateStr,
          'lectureId': lecture.lectureId,
          'deptId': deptId,
          'absentees': absentees.join(','),
        });
        hasData = true;
      }
    }

    if (hasData && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Attendance Submitted!'),
            ],
          ),
          backgroundColor: Colors.deepPurple,
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

    List<Map<String, dynamic>> lectures =
        await DatabaseHelper.instance.getLecturesByDay(_dayName);
    _lectureStates = [];

    for (var l in lectures) {
      int id = l['id'];
      bool isElective = l['isElective'] == 1;

      Set<int> relevantDepts = {};
      String? errorMessage;

      if (!isElective) {
        for (var d in _departments) {
          relevantDepts.add(d.id!);
        }
      } else {
        final enrolledIds =
            await DatabaseHelper.instance.getEnrolledStudentIds(id);
        final enrolledSet = enrolledIds.toSet();

        if (enrolledSet.isEmpty) {
          errorMessage = "No students enrolled. Manage Electives to add.";
        } else {
          _studentCache.forEach((deptId, students) {
            if (students.any((s) => enrolledSet.contains(s['id']))) {
              relevantDepts.add(deptId);
            }
          });
        }
      }

      _lectureStates.add(
        LectureState(
          lectureId: id,
          title: l['subject'],
          faculty: l['faculty'],
          time: l['timeSlot'],
          isElective: isElective,
          relevantDeptIds: relevantDepts,
          departments: _departments,
          error: errorMessage,
        ),
      );
    }

    await _loadDraft();
    await _loadExistingDataFromDB();

    setState(() => _isLoading = false);
    _generateMessage();
  }

  Future<void> _loadExistingDataFromDB() async {
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final existingLogs =
        await DatabaseHelper.instance.getAttendanceLogs(date: dateStr);

    for (var log in existingLogs) {
      for (var lecture in _lectureStates) {
        if (lecture.title == log['subject'] &&
            lecture.time == log['timeSlot']) {
          if (lecture.error != null) continue;

          String deptName = log['deptName'];
          var dept = _departments.firstWhere(
            (d) => d.name == deptName,
            orElse: () => Department(name: ''),
          );

          if (dept.id != null && lecture.relevantDeptIds.contains(dept.id)) {
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
      if (lecture.error != null) continue;
      for (var deptId in lecture.relevantDeptIds) {
        String baseKey = "draft_${dateKey}_${lecture.lectureId}_$deptId";
        await prefs.setString(
          "${baseKey}_text",
          lecture.controllers[deptId]!.text,
        );
        await prefs.setBool(
            "${baseKey}_mode", lecture.isDirectMode[deptId]!);
      }
    }
    if (!silent && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Draft saved!')));
    }
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    for (var lecture in _lectureStates) {
      if (lecture.error != null) continue;
      for (var deptId in lecture.relevantDeptIds) {
        String baseKey = "draft_${dateKey}_${lecture.lectureId}_$deptId";
        String? savedText = prefs.getString("${baseKey}_text");
        bool? savedMode = prefs.getBool("${baseKey}_mode");
        if (savedText != null) lecture.controllers[deptId]!.text = savedText;
        if (savedMode != null) lecture.isDirectMode[deptId] = savedMode;
      }
    }
  }

  Future<List<String>> _calculateAbsentees(
    LectureState lecture,
    int deptId,
    String input,
    bool isDirectMode,
  ) async {
    if (input.trim().isEmpty) return [];
    List<String> inputRolls = input
        .split(RegExp(r'[, ]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    List<String> validClassList = [];

    if (lecture.isElective) {
      final enrolledIds =
          await DatabaseHelper.instance.getEnrolledStudentIds(lecture.lectureId);
      final enrolledSet = enrolledIds.toSet();
      final allStudentsInDept = _studentCache[deptId] ?? [];
      validClassList = allStudentsInDept
          .where((s) => enrolledSet.contains(s['id']))
          .map((s) => s['rollNumber'].toString())
          .toList();
    } else {
      final allStudents = _studentCache[deptId] ?? [];
      validClassList =
          allStudents.map((s) => s['rollNumber'].toString()).toList();
    }

    if (isDirectMode) {
      return inputRolls.where((roll) => validClassList.contains(roll)).toList();
    } else {
      List<String> actualAbsentees = [];
      for (var roll in validClassList) {
        if (!inputRolls.contains(roll)) actualAbsentees.add(roll);
      }
      return actualAbsentees;
    }
  }

  String _formatNames(int deptId, List<String> rollList) {
    if (rollList.isEmpty) return "None";
    final studentsInDept = _studentCache[deptId] ?? [];
    Map<String, String> nameMap = {
      for (var s in studentsInDept)
        s['rollNumber'].toString(): s['name'].toString(),
    };

    try {
      rollList.sort((a, b) {
        return int.parse(a.replaceAll(RegExp(r'[^0-9]'), ''))
            .compareTo(int.parse(b.replaceAll(RegExp(r'[^0-9]'), '')));
      });
    } catch (e) { /* ignore */ }

    return rollList
        .map((roll) => "$roll - ${nameMap[roll] ?? "Unknown"}")
        .join('\n');
  }

  // --- LANGUAGE SELECTION DIALOG ---
  void _openLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) {
        bool localEng = _showEnglish;
        bool localGuj = _showGujarati;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Select Output Language"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text("English Header"),
                    value: localEng,
                    activeColor: Colors.deepPurple,
                    onChanged: (val) {
                      setState(() => localEng = val!);
                    },
                  ),
                  CheckboxListTile(
                    title: const Text("Gujarati Header"),
                    value: localGuj,
                    activeColor: Colors.deepPurple,
                    onChanged: (val) {
                      setState(() => localGuj = val!);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: () {
                    this.setState(() {
                      _showEnglish = localEng;
                      _showGujarati = localGuj;
                    });
                    _generateMessage();
                    Navigator.pop(context);
                  },
                  child: const Text("Apply"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- NEW: VIEW FULL REPORT DIALOG ---
  void _showFullReportDialog() {
    if (_outputController.text.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Preview Report"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Text(
                _outputController.text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
              ),
            ),
          ),
          actions: [
             TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text("Copy"),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _outputController.text));
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied!')));
                Navigator.pop(context);
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // --- MODIFIED MESSAGE GENERATION LOGIC ---
  Future<void> _generateMessage() async {
    if (!_showEnglish && !_showGujarati) {
      setState(() => _outputController.text = "");
      return;
    }

    final formattedDate = DateFormat('dd-MM-yyyy').format(_selectedDate);
    final gujaratiDays = {
      "Monday": "સોમવાર", "Tuesday": "મંગળવાર", "Wednesday": "બુધવાર",
      "Thursday": "ગુરુવાર", "Friday": "શુક્રવાર", "Saturday": "શનિવાર", "Sunday": "રવિવાર",
    };

    StringBuffer buffer = StringBuffer();

    // 1. ADD HEADERS (Based on Selection - Stacking them)
    if (_showGujarati) {
      buffer.writeln("આજે $formattedDate (${gujaratiDays[_dayName] ?? _dayName}) ના રોજ ગેરહાજર રહેલા વિદ્યાર્થીઓની યાદી નીચે મુજબ છે");
    }
    if (_showEnglish) {
      buffer.writeln("Following is the list of students who remained absent today $formattedDate ($_dayName)");
    }
    
    // Add a blank line after headers
    buffer.writeln();

    if (_lectureStates.isEmpty) {
      buffer.writeln("No lectures scheduled.");
    }

    // 2. ADD BODY (Common List for all)
    for (var lecture in _lectureStates) {
      if (lecture.error != null) continue;

      bool hasAbsenteesForLecture = false;
      StringBuffer lectureBuffer = StringBuffer();

      lectureBuffer.writeln("*${lecture.title} - ${lecture.faculty} (${lecture.time})*\n");

      for (var deptId in lecture.relevantDeptIds) {
        String deptName = _departments.firstWhere((d) => d.id == deptId).name;
        String input = lecture.controllers[deptId]?.text ?? "";
        if (input.trim().isEmpty) continue;

        List<String> absentees = await _calculateAbsentees(
          lecture,
          deptId,
          input,
          lecture.isDirectMode[deptId]!,
        );

        if (absentees.isNotEmpty) {
          hasAbsenteesForLecture = true;
          lectureBuffer.writeln("$deptName Absentees :");
          lectureBuffer.writeln(_formatNames(deptId, absentees));
          lectureBuffer.writeln();
        }
      }
      lectureBuffer.writeln("------------------------\n");

      if (hasAbsenteesForLecture) {
        buffer.write(lectureBuffer.toString());
      }
    }

    setState(() => _outputController.text = buffer.toString());
  }

  void _copyToClipboard() {
    if (_outputController.text.isEmpty) _generateMessage();
    Clipboard.setData(ClipboardData(text: _outputController.text));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to Clipboard!')));
  }

  Future<void> _shareToWhatsApp() async {
    if (_outputController.text.isEmpty) await _generateMessage();
    String urlString =
        "whatsapp://send?text=${Uri.encodeComponent(_outputController.text)}";
    try {
      await launchUrl(Uri.parse(urlString));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch WhatsApp')));
      }
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
            icon: const Icon(Icons.language),
            tooltip: "Select Language",
            onPressed: _openLanguageDialog,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
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
                // Header Information
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dayName,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM dd, yyyy').format(_selectedDate),
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Language: ${(_showEnglish && _showGujarati) ? "Both" : (_showEnglish ? "English" : "Gujarati")}",
                        style: TextStyle(
                            fontSize: 12, color: Colors.deepPurple.shade300),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_lectureStates.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        "No lectures found.",
                        style: TextStyle(color: colorScheme.outline),
                      ),
                    ),
                  ),

                ..._lectureStates.map(
                  (lecture) => LectureCard(
                    lecture: lecture,
                    departments: _departments,
                    studentCache: _studentCache,
                    onStateChange: _triggerAutoSave,
                  ),
                ),

                const SizedBox(height: 20),
                
                // --- PREVIEW BUTTON ROW ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Generated Output",
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text("View Full Report"),
                      onPressed: _showFullReportDialog,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // --- TEXT BOX ---
                TextField(
                  controller: _outputController,
                  maxLines: 6,
                  readOnly: true, // Only for copying
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor:
                        colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.copy),
                        label: const Text("Copy"),
                        onPressed: _copyToClipboard,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text("Text WhatsApp"),
                        onPressed: _shareToWhatsApp,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3, // Added a little shadow to make it look "saveable"
                    ),
                    // CHANGED ICON to 'save' to indicate storage
                    icon: const Icon(Icons.save), 
                    // CHANGED TEXT to be clearer
                    label: const Text(
                      "Save to History", 
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _submitAttendance,
                  ),
                ),
                
                // Add a small helper text below to explain
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Center(
                    child: Text(
                      "Saves data for reports , backup & share",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),  
    );
  }
}

// --- LectureCard UI (UNCHANGED) ---
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
    for (var deptId in widget.lecture.relevantDeptIds) {
      _updateCount(deptId, widget.lecture.controllers[deptId]?.text ?? "");
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
    final validRollNumbers =
        studentList.map((s) => s['rollNumber'].toString()).toSet();

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
      errorMsg = "Invalid Roll No: ${outOfBounds.join(', ')}";
    }

    setState(() => _errors[deptId] = errorMsg);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.lecture.error != null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: Colors.red.shade50,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${widget.lecture.title} (${widget.lecture.time})",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.lecture.error!,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    List<Department> visibleDepartments = widget.departments
        .where((d) => widget.lecture.relevantDeptIds.contains(d.id))
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: widget.lecture.isElective
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Colors.orange, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
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
                      Row(
                        children: [
                          Text(
                            widget.lecture.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.lecture.isElective)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "Elective",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
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
            ...visibleDepartments.map((dept) {
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
                    hintText: isDirect
                        ? "Enter Absent Roll No."
                        : "Enter Present Roll No.",
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                    suffixIcon: Tooltip(
                      message: isDirect ? "Mode: Absent" : "Mode: Present",
                      child: IconButton(
                        icon: Icon(
                          isDirect
                              ? Icons.person_off_outlined
                              : Icons.how_to_reg,
                          color: isDirect
                              ? colorScheme.error
                              : colorScheme.primary,
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