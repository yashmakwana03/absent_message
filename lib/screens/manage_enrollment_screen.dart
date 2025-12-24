import 'package:flutter/material.dart';
import '../database/database_helper.dart'; 
import '../models/department.dart';
import '../models/student.dart';

class ManageEnrollmentScreen extends StatefulWidget {
  const ManageEnrollmentScreen({super.key});

  @override
  State<ManageEnrollmentScreen> createState() => _ManageEnrollmentScreenState();
}

class _ManageEnrollmentScreenState extends State<ManageEnrollmentScreen> {
  // Selection States
  String? _selectedSubjectName;
  int? _selectedDeptId;

  // Data Lists
  List<Map<String, dynamic>> _allElectiveRows = [];
  List<String> _uniqueSubjects = [];
  List<Department> _departments = [];
  List<Student> _students = [];
  
  // Tracking Enrollment
  Set<int> _enrolledStudentIds = {};
  Set<int> _tempSelectedIds = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    final electives = await DatabaseHelper.instance.getElectiveLectures();
    
    final uniqueNames = electives.map((e) => e['subject'] as String).toSet().toList();
    uniqueNames.sort();

    final depts = await DatabaseHelper.instance.readAllDepartments();
    
    setState(() {
      _allElectiveRows = electives;
      _uniqueSubjects = uniqueNames;
      _departments = depts;
      _isLoading = false;
      
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

    // 1. Get Students
    final students = await DatabaseHelper.instance.readStudentsByDept(_selectedDeptId!);
    
    // --- SORTING LOGIC: NUMERIC ---
    students.sort((a, b) {
      // Extract numbers from roll string (e.g. "25" from "25" or "92001" from "92001")
      int aNum = int.tryParse(a.rollNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      int bNum = int.tryParse(b.rollNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return aNum.compareTo(bNum);
    });

    // 2. Find matching lecture IDs
    final matchingLectureIds = _allElectiveRows
        .where((e) => e['subject'] == _selectedSubjectName)
        .map((e) => e['id'] as int)
        .toList();

    // 3. Get enrolled IDs
    Set<int> enrolledSet = {};
    for (var id in matchingLectureIds) {
      final list = await DatabaseHelper.instance.getEnrolledStudentIds(id);
      enrolledSet.addAll(list);
    }

    setState(() {
      _students = students;
      _enrolledStudentIds = enrolledSet;
      
      _tempSelectedIds = _students
          .where((s) => _enrolledStudentIds.contains(s.id))
          .map((s) => s.id!)
          .toSet();
      
      _isLoading = false;
    });
  }

  Future<void> _saveChanges() async {
    if (_selectedSubjectName == null) return;

    setState(() => _isLoading = true);

    List<int> toAdd = [];
    List<int> toRemove = [];

    for (var student in _students) {
      bool isSelected = _tempSelectedIds.contains(student.id);
      bool wasEnrolled = _enrolledStudentIds.contains(student.id);

      if (isSelected && !wasEnrolled) {
        toAdd.add(student.id!);
      } else if (!isSelected && wasEnrolled) {
        toRemove.add(student.id!);
      }
    }

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
        ),
      );
      await _fetchStudentsAndEnrollment();
    }
  }

  // --- SHORTCUT: COMMA LIST ---
  void _selectByListDialog() {
    final TextEditingController listCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select by List"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Enter numbers separated by comma.", style: TextStyle(fontSize: 13, color: Colors.grey)),
            const Text("Example: 1, 5, 12, 33", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: listCtrl,
              decoration: const InputDecoration(
                labelText: "Roll Numbers",
                border: OutlineInputBorder(),
                hintText: "1, 2, 5...",
              ),
              keyboardType: TextInputType.number,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              String text = listCtrl.text;
              if (text.isNotEmpty) {
                // Parse "1, 5, 10" -> Set {1, 5, 10}
                Set<int> targetRolls = text.split(',')
                    .map((e) => int.tryParse(e.trim()) ?? -1)
                    .where((e) => e != -1)
                    .toSet();
                
                setState(() {
                  for (var s in _students) {
                    // Get numeric part of student roll no
                    String rollDigits = s.rollNumber.replaceAll(RegExp(r'[^0-9]'), ''); 
                    if (rollDigits.isNotEmpty) {
                       int rollNum = int.parse(rollDigits);
                       
                       // Check exact match OR match last 3 digits (for long roll numbers)
                       int shortRoll = rollNum > 1000 ? rollNum % 1000 : rollNum;

                       if (targetRolls.contains(rollNum) || targetRolls.contains(shortRoll)) {
                         _tempSelectedIds.add(s.id!);
                       }
                    }
                  }
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text("Apply Selection"),
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
        label: const Text("Save Enrollment"),
      ),
      body: Column(
        children: [
          // --- FILTERS ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.shade50,
            child: Column(
              children: [
                // 1. Subject Name Dropdown (Fixed Deprecation Warning)
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Select Subject (All Batches)",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSubjectName,
                      isExpanded: true,
                      items: _uniqueSubjects.map((name) => DropdownMenuItem(
                        value: name,
                        child: Text(name),
                      )).toList(),
                      onChanged: (val) {
                        setState(() => _selectedSubjectName = val);
                        _fetchStudentsAndEnrollment();
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // 2. Department Dropdown (Fixed Deprecation Warning)
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Select Students From",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedDeptId,
                      isExpanded: true,
                      items: _departments.map((d) => DropdownMenuItem(
                        value: d.id,
                        child: Text(d.name),
                      )).toList(),
                      onChanged: (val) {
                        setState(() => _selectedDeptId = val);
                        _fetchStudentsAndEnrollment();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
            
          // --- TOOLS & BULK ACTIONS (Combined) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // 1. Student Count
                Text(
                  "${_students.length} Students",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                
                const Spacer(), // Pushes everything else to the right

                // 2. Select by List Button
                OutlinedButton.icon(
                  onPressed: _selectByListDialog,
                  icon: const Icon(Icons.list_alt, size: 16),
                  label: const Text("Select By List"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36), // Compact height
                  ),
                ),
                
                const SizedBox(width: 8),

                // 3. Select All (Compact Text Button)
                TextButton(
                  onPressed: () => setState(() =>
                      _tempSelectedIds.addAll(_students.map((s) => s.id!))),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36)),
                  child: const Text("All"),
                ),

                // 4. Clear All (Compact Text Button)
                TextButton(
                  onPressed: () => setState(() => _tempSelectedIds.clear()),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36)),
                  child: const Text("Clear"),
                ),
              ],
            ),
          ),

          // --- STUDENT LIST ---
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _students.isEmpty 
                ? const Center(child: Text("No students found"))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
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