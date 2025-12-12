import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/department.dart';
import '../models/student.dart';

class StudentInputScreen extends StatefulWidget {
  const StudentInputScreen({super.key});

  @override
  State<StudentInputScreen> createState() => _StudentInputScreenState();
}

class _StudentInputScreenState extends State<StudentInputScreen> {
  List<Department> _departments = [];
  Department? _selectedDepartment;
  bool _isLoading = true;

  final TextEditingController _rollNoController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _shortcutController = TextEditingController();

  // --- Step 1: Load departments when the screen starts ---
  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    final depts = await DatabaseHelper.instance.readAllDepartments();
    setState(() {
      _departments = depts;
      _selectedDepartment = depts.isNotEmpty ? depts.first : null;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _rollNoController.dispose();
    _nameController.dispose();
    _shortcutController.dispose();
    super.dispose();
  }

  // --- Step 2: Handle saving a single student ---
  Future<void> _saveSingleStudent() async {
    if (_selectedDepartment == null) {
      _showSnackbar('Please set up departments first.', true);
      return;
    }

    final rollNo = _rollNoController.text.trim();
    final name = _nameController.text.trim();

    if (rollNo.isEmpty || name.isEmpty) {
      _showSnackbar('Roll Number and Name cannot be empty.', true);
      return;
    }

    final newStudent = Student(
      rollNumber: rollNo,
      name: name,
      deptId: _selectedDepartment!.id!,
    );

    try {
      await DatabaseHelper.instance.createStudent(newStudent);
      _rollNoController.clear();
      _nameController.clear();
      _showSnackbar('Student $name added successfully!', false);
    } catch (e) {
      _showSnackbar('Failed to add student. Roll number might already exist.', true);
    }
  }

 // --- Step 3: Handle saving students from the shortcut dictionary text ---
  Future<void> _saveStudentsFromShortcut() async {
    if (_selectedDepartment == null) {
      _showSnackbar('Please select a department.', true);
      return;
    }
    
    final text = _shortcutController.text.trim();
    if (text.isEmpty) {
      _showSnackbar('Shortcut box is empty.', true);
      return;
    }

    final lines = text.split('\n');
    int addedCount = 0;
    int failedCount = 0;

    for (var line in lines) {
      // 1. Clean the line: remove leading/trailing spaces, newlines, and quotes
      String cleanedLine = line.trim().replaceAll('"', '').replaceAll("'", '');
      
      if (cleanedLine.isEmpty) continue;

      // 2. Separate Roll Number and Name using common delimiters (:, comma, space)
      // The regex `[,:]` handles 'C001, John' or 'C001: John'
      // We will try to split by common delimiters
      final parts = cleanedLine.split(RegExp(r'[,:]')); 
      
      String rollNo = '';
      String name = '';

      if (parts.length >= 2) {
        rollNo = parts[0].trim();
        name = parts[1].trim();
      } else {
        // Fallback for space separation (e.g., "10 Yash")
        final spaceParts = cleanedLine.split(RegExp(r'\s+', multiLine: true));
        if (spaceParts.length >= 2) {
            rollNo = spaceParts[0].trim();
            // Join the rest of the parts back into the name
            name = spaceParts.sublist(1).join(' ').trim(); 
        }
      }

      // 3. Final Validation and Insertion
      if (rollNo.isNotEmpty && name.isNotEmpty) {
        final newStudent = Student(
          rollNumber: rollNo,
          name: name,
          deptId: _selectedDepartment!.id!,
        );
        
        try {
          await DatabaseHelper.instance.createStudent(newStudent);
          addedCount++;
        } catch (e) {
          // Failure likely due to duplicate Roll Number (UNIQUE constraint)
          failedCount++;
        }
      } else {
        failedCount++;
      }
    }

    _shortcutController.clear();
    
    String message = '$addedCount student(s) added successfully.';
    if (failedCount > 0) {
      message += ' ($failedCount failed/skipped - check for duplicates or formatting)';
    }

    _showSnackbar(message, failedCount > 0);
  }

  void _showSnackbar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_departments.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Students')),
        body: const Center(
          child: Text('No departments found. Please go back and set them up.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Student Data'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // --- Department Selector ---
            _buildDepartmentSelector(),
            const SizedBox(height: 20),
            
            // --- Single Student Input ---
            _buildSingleStudentInput(),
            const Divider(height: 40),

            // --- Shortcut/Bulk Input ---
            _buildShortcutInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentSelector() {
    return DropdownButtonFormField<Department>(
      decoration: const InputDecoration(
        labelText: 'Select Department',
        border: OutlineInputBorder(),
      ),
      value: _selectedDepartment,
      items: _departments.map((dept) {
        return DropdownMenuItem(
          value: dept,
          child: Text(dept.name),
        );
      }).toList(),
      onChanged: (Department? newValue) {
        setState(() {
          _selectedDepartment = newValue;
        });
      },
    );
  }

  Widget _buildSingleStudentInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Add Single Student', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextFormField(
          controller: _rollNoController,
          decoration: const InputDecoration(
            labelText: 'Roll Number',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Student Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _saveSingleStudent,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          child: const Text('Add Student'),
        ),
      ],
    );
  }

  Widget _buildShortcutInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Bulk/Shortcut Input (Roll No:Name)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text('Enter one entry per line (e.g., "C001,John Smith" or "C002:Alice Doe")'),
        const SizedBox(height: 10),
        TextFormField(
          controller: _shortcutController,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'C001, John Smith\nC002: Alice Doe\n...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _saveStudentsFromShortcut,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          child: const Text('Add Students (Bulk)'),
        ),
      ],
    );
  }
}