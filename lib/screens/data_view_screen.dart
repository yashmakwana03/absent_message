import 'package:flutter/material.dart';
import '../database/database_helper.dart';

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

  // --- 1. Logic to Delete Single Student ---
  Future<void> _deleteStudent(int studentId, String studentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete the student: $studentName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            // Black text for cancel
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            // Red text for delete
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).primaryColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      await DatabaseHelper.instance.deleteStudent(studentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$studentName deleted successfully.')),
        );
      }
      _refreshData();
    }
  }

  // --- 2. Logic to Delete ALL Data (Added Back) ---
  Future<void> _showDeleteAllDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WARNING: Delete All Data'),
        content: const Text(
            'Are you sure you really want to delete ALL students AND departments? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            // Red text for danger
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE ALL'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      await DatabaseHelper.instance.deleteAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data deleted successfully.')),
        );
      }
      _refreshData();
    }
  }

  // --- 3. Grouping Logic ---
  Map<String, List<Map<String, dynamic>>> _groupStudentsByDepartment(List<Map<String, dynamic>> students) {
    final Map<String, List<Map<String, dynamic>>> groupedData = {};
    for (var student in students) {
      final deptName = student['departmentName'] as String;
      if (!groupedData.containsKey(deptName)) {
        groupedData[deptName] = [];
      }
      groupedData[deptName]!.add(student);
    }
    groupedData.values.forEach((list) {
      list.sort((a, b) => int.parse(a['rollNumber'].toString())
          .compareTo(int.parse(b['rollNumber'].toString())));
    });
    return groupedData;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor; // Your Red Color

    return Scaffold(
      appBar: AppBar(
        title: const Text('View and Manage Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
          // --- 4. The Delete All Button is Added Here ---
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _showDeleteAllDialog,
            tooltip: 'Delete All Data',
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
            return const Center(
              child: Text('No student data found. Please add students first.'),
            );
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
                  // Department Header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                    child: Text(
                      deptName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryColor, // Use Red Theme
                      ),
                    ),
                  ),
                  // List of Students
                  ...studentsInDept.map((student) {
                    final rollNo = student['rollNumber'].toString();
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: CircleAvatar(
                          // Use Red background for avatar
                          backgroundColor: primaryColor.withOpacity(0.1), 
                          radius: 28,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: FittedBox(
                              child: Text(
                                rollNo,
                                style: TextStyle(
                                  color: primaryColor, // Red Text
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        title: Text(student['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text('Roll No: $rollNo'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          onPressed: () => _deleteStudent(
                            student['id'],
                            student['name'],
                          ),
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