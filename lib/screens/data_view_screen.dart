import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/student.dart';

class DataViewScreen extends StatefulWidget {
  const DataViewScreen({super.key});

  @override
  State<DataViewScreen> createState() => _DataViewScreenState();
}

class _DataViewScreenState extends State<DataViewScreen> {
  Future<List<Map<String, dynamic>>>? _studentsFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _studentsFuture = DatabaseHelper.instance.readAllStudentsWithDeptName();
    });
  }

  // --- 1. Logic to Edit Student (NOW CONNECTED) ---
  Future<void> _editStudent(Map<String, dynamic> studentData) async {
    final TextEditingController nameController = 
        TextEditingController(text: studentData['name']);
    final TextEditingController rollController = 
        TextEditingController(text: studentData['rollNumber'].toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rollController,
              decoration: const InputDecoration(labelText: 'Roll Number'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Student Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              // 1. Create updated student object
              final updatedStudent = Student(
                id: studentData['id'], // Keep the same ID
                deptId: studentData['deptId'], // Keep the same Department
                rollNumber: rollController.text,
                name: nameController.text,
              );

              try {
                // 2. Update in Database
                await DatabaseHelper.instance.updateStudent(updatedStudent);
                
                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  _refreshData(); // Refresh list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Student updated successfully!')),
                  );
                }
              } catch (e) {
                // Handle duplicate roll number error
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error: Roll Number might already exist in this department.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // --- 2. Logic to Delete Single Student ---
  Future<void> _deleteStudent(int studentId, String studentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Delete student: $studentName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      await DatabaseHelper.instance.deleteStudent(studentId);
      _refreshData();
    }
  }

  Future<void> _showDeleteAllDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WARNING'),
        content: const Text('Delete ALL data? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE ALL', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      await DatabaseHelper.instance.deleteAllData();
      _refreshData();
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupStudentsByDepartment(List<Map<String, dynamic>> students) {
    final Map<String, List<Map<String, dynamic>>> groupedData = {};
    for (var student in students) {
      final deptName = student['departmentName'] as String;
      if (!groupedData.containsKey(deptName)) groupedData[deptName] = [];
      groupedData[deptName]!.add(student);
    }
    groupedData.values.forEach((list) {
      try {
        list.sort((a, b) => int.parse(a['rollNumber'].toString())
            .compareTo(int.parse(b['rollNumber'].toString())));
      } catch (e) { /* Ignore non-numeric sort errors */ }
    });
    return groupedData;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Student Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _showDeleteAllDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _studentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No students found. Add some!'));
          }

          final students = snapshot.data!;
          final groupedData = _groupStudentsByDepartment(students);
          final departmentNames = groupedData.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: departmentNames.length,
            itemBuilder: (context, index) {
              final deptName = departmentNames[index];
              final studentsInDept = groupedData[deptName]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                    child: Text(
                      deptName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  ...studentsInDept.map((student) {
                    final rollNo = student['rollNumber'].toString();
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: primaryColor.withOpacity(0.1),
                          child: Text(
                            rollNo,
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(student['name']),
                        subtitle: Text('Roll No: $rollNo'),
                        
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // --- EDIT BUTTON (NOW WORKING) ---
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.grey),
                              onPressed: () => _editStudent(student), // Calls the dialog
                            ),
                            // --- DELETE BUTTON ---
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.grey),
                              onPressed: () => _deleteStudent(
                                student['id'],
                                student['name'],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
              );
            },
          );
        },
      ),
    );
  }
}