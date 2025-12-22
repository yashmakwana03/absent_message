import 'package:flutter/material.dart';
import '../database/database_helper.dart'; // Check your path
import '../models/department.dart';
import '../models/student.dart';

class ManageEnrollmentScreen extends StatefulWidget {
  const ManageEnrollmentScreen({super.key});

  @override
  State<ManageEnrollmentScreen> createState() => _ManageEnrollmentScreenState();
}

class _ManageEnrollmentScreenState extends State<ManageEnrollmentScreen> {
  // Selection States
  String? _selectedSubjectName; // CHANGED: We now select by NAME, not ID
  int? _selectedDeptId;

  // Data Lists
  List<Map<String, dynamic>> _allElectiveRows = []; // Keep all rows for reference
  List<String> _uniqueSubjects = []; // For the dropdown
  List<Department> _departments = [];
  List<Student> _students = [];
  
  // Tracking Enrollment
  Set<int> _enrolledStudentIds = {}; // IDs currently in DB
  Set<int> _tempSelectedIds = {}; // IDs checked on UI
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    // 1. Get All Elective Lectures
    final electives = await DatabaseHelper.instance.getElectiveLectures();
    
    // 2. Extract UNIQUE Subject Names
    // (e.g. if we have 3 "Java" lectures, we only want "Java" once in the list)
    final uniqueNames = electives.map((e) => e['subject'] as String).toSet().toList();
    uniqueNames.sort(); // Alphabetical order

    final depts = await DatabaseHelper.instance.readAllDepartments();
    
    setState(() {
      _allElectiveRows = electives;
      _uniqueSubjects = uniqueNames;
      _departments = depts;
      _isLoading = false;
      
      // Auto-select first options
      if (_uniqueSubjects.isNotEmpty) _selectedSubjectName = _uniqueSubjects.first;
      if (_departments.isNotEmpty) _selectedDeptId = _departments.first.id;
    });

    if (_selectedSubjectName != null && _selectedDeptId != null) {
      _fetchStudentsAndEnrollment();
    }
  }

  Future<void> _fetchStudentsAndEnrollment() async {
    if (_selectedSubjectName == null || _selectedDeptId == null) return;

    setState(() => _isLoading = true);

    // 1. Get All Students in the selected Department
    final students = await DatabaseHelper.instance.readStudentsByDept(_selectedDeptId!);
    
    // 2. Find ALL Lecture IDs that match this Subject Name
    // (e.g. Find ID for Mon Java, Wed Java, Fri Java)
    final matchingLectureIds = _allElectiveRows
        .where((e) => e['subject'] == _selectedSubjectName)
        .map((e) => e['id'] as int)
        .toList();

    // 3. Get currently enrolled IDs for ANY of these lectures
    // We just need to check the first one, assuming they are synced. 
    // But to be safe, we check all and merge them.
    Set<int> enrolledSet = {};
    for (var id in matchingLectureIds) {
      final list = await DatabaseHelper.instance.getEnrolledStudentIds(id);
      enrolledSet.addAll(list);
    }

    setState(() {
      _students = students;
      _enrolledStudentIds = enrolledSet;
      
      // Pre-fill the UI checkboxes
      _tempSelectedIds = _students
          .where((s) => _enrolledStudentIds.contains(s.id))
          .map((s) => s.id!)
          .toSet();
      
      _isLoading = false;
    });
  }

  // --- SAVE LOGIC (THE FIX) ---
  Future<void> _saveChanges() async {
    if (_selectedSubjectName == null) return;

    setState(() => _isLoading = true);

    List<int> toAdd = [];
    List<int> toRemove = [];

    // Calculate changes
    for (var student in _students) {
      bool isSelected = _tempSelectedIds.contains(student.id);
      bool wasEnrolled = _enrolledStudentIds.contains(student.id);

      if (isSelected && !wasEnrolled) {
        toAdd.add(student.id!);
      } else if (!isSelected && wasEnrolled) {
        toRemove.add(student.id!);
      }
    }

    // --- MAGIC HAPPENS HERE ---
    // Instead of updating just one ID, we find ALL lectures with this name
    final matchingLectureIds = _allElectiveRows
        .where((e) => e['subject'] == _selectedSubjectName)
        .map((e) => e['id'] as int)
        .toList();

    int updatedCount = 0;
    for (var lectureId in matchingLectureIds) {
      await DatabaseHelper.instance.updateBatchEnrollment(lectureId, toAdd, toRemove);
      updatedCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Updated $updatedCount batches of '$_selectedSubjectName'!"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      // Refresh to ensure sync
      await _fetchStudentsAndEnrollment();
    }
  }

  // --- SHORTCUT ---
  void _selectRangeDialog() {
    final TextEditingController startCtrl = TextEditingController();
    final TextEditingController endCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select by Roll No Range"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter numeric part (e.g. 1 to 32)"),
            TextField(controller: startCtrl, decoration: const InputDecoration(labelText: "Start"), keyboardType: TextInputType.number),
            TextField(controller: endCtrl, decoration: const InputDecoration(labelText: "End"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              int? start = int.tryParse(startCtrl.text);
              int? end = int.tryParse(endCtrl.text);
              if (start != null && end != null) {
                setState(() {
                  for (var s in _students) {
                    String rollDigits = s.rollNumber.replaceAll(RegExp(r'[^0-9]'), ''); 
                    if (rollDigits.isNotEmpty) {
                       int rollNum = int.parse(rollDigits);
                       // Handle cases like 92000163001 vs just 1
                       // If roll number > 1000, maybe check last 3 digits? 
                       // For now, simple direct check
                       if (rollNum >= start && rollNum <= end) {
                         _tempSelectedIds.add(s.id!);
                       } else {
                         // Optional: Handle 3 digit matching for long enrollment numbers
                         if (rollNum > 1000) {
                           int last3 = rollNum % 1000;
                           if (last3 >= start && last3 <= end) _tempSelectedIds.add(s.id!);
                         }
                       }
                    }
                  }
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text("Select"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Electives")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveChanges, 
        icon: const Icon(Icons.save),
        label: const Text("Save to All Batches"),
      ),
      body: Column(
        children: [
          // --- FILTERS ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.shade50,
            child: Column(
              children: [
                // 1. Subject Name Dropdown (Unique List)
                DropdownButtonFormField<String>(
                  value: _selectedSubjectName,
                  decoration: const InputDecoration(labelText: "Select Subject (All Batches)", filled: true, fillColor: Colors.white),
                  items: _uniqueSubjects.map((name) => DropdownMenuItem(
                    value: name,
                    child: Text(name), // Shows "Java" only once
                  )).toList(),
                  onChanged: (val) {
                    setState(() => _selectedSubjectName = val);
                    _fetchStudentsAndEnrollment();
                  },
                ),
                const SizedBox(height: 10),
                
                // 2. Department Dropdown
                DropdownButtonFormField<int>(
                  value: _selectedDeptId,
                  decoration: const InputDecoration(labelText: "Select Students From", filled: true, fillColor: Colors.white),
                  items: _departments.map((d) => DropdownMenuItem(
                    value: d.id,
                    child: Text(d.name),
                  )).toList(),
                  onChanged: (val) {
                    setState(() => _selectedDeptId = val);
                    _fetchStudentsAndEnrollment();
                  },
                ),
              ],
            ),
          ),

          // --- TOOLS ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${_students.length} Students", style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    OutlinedButton(onPressed: _selectRangeDialog, child: const Text("Range")),
                    const SizedBox(width: 8),
                    TextButton(onPressed: () => setState(() => _tempSelectedIds.addAll(_students.map((s) => s.id!))), child: const Text("All")),
                    TextButton(onPressed: () => setState(() => _tempSelectedIds.clear()), child: const Text("None")),
                  ],
                )
              ],
            ),
          ),

          // --- LIST ---
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _students.isEmpty 
                ? const Center(child: Text("No students found"))
                : ListView.builder(
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final isChecked = _tempSelectedIds.contains(student.id);

                      return CheckboxListTile(
                        title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Roll No: ${student.rollNumber}"),
                        value: isChecked,
                        activeColor: Colors.deepPurple,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _tempSelectedIds.add(student.id!);
                            } else {
                              _tempSelectedIds.remove(student.id!);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}