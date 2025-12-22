import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/department.dart';
import 'student_input_screen.dart';

class DepartmentSetupScreen extends StatefulWidget {
  const DepartmentSetupScreen({super.key});

  @override
  State<DepartmentSetupScreen> createState() => _DepartmentSetupScreenState();
}

class _DepartmentSetupScreenState extends State<DepartmentSetupScreen> {
  // We use a List of Maps to track controllers and IDs together
  // Structure: { 'id': int? (null if new), 'controller': TextEditingController }
  List<Map<String, dynamic>> _deptFields = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingDepartments();
  }

  Future<void> _loadExistingDepartments() async {
    final existingDepts = await DatabaseHelper.instance.readAllDepartments();

    if (existingDepts.isNotEmpty) {
      setState(() {
        _deptFields = existingDepts
            .map(
              (dept) => {
                'id': dept.id,
                'controller': TextEditingController(text: dept.name),
              },
            )
            .toList();
        _isLoading = false;
      });
    } else {
      // If no data, start with 1 empty field
      _addNewField();
      setState(() => _isLoading = false);
    }
  }

  void _addNewField() {
    setState(() {
      _deptFields.add({
        'id': null, // New field, so no ID yet
        'controller': TextEditingController(),
      });
    });
  }

  // --- DELETE LOGIC (Show Below, No Redirect) ---
  Future<void> _deleteField(int index) async {
    final deptId = _deptFields[index]['id'] as int?;

    // If it's an existing department (has ID), confirm before deleting from DB
    if (deptId != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Delete Department?"),
          content: const Text(
            "This will remove the department from the database immediately. Students in this department might be affected.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await DatabaseHelper.instance.deleteDepartment(deptId);
        setState(() {
          _deptFields[index]['controller'].dispose();
          _deptFields.removeAt(index);
        });
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Department Deleted")));
      }
    } else {
      // If it's a new unsaved field, just remove it from UI
      setState(() {
        _deptFields[index]['controller'].dispose();
        _deptFields.removeAt(index);
      });
    }
  }

  // --- SAVE LOGIC ---
  Future<void> _saveDepartments() async {
    bool hasError = false;

    // 1. Loop through all fields
    for (var field in _deptFields) {
      final controller = field['controller'] as TextEditingController;
      final name = controller.text.trim();
      final id = field['id'] as int?;

      if (name.isEmpty) {
        hasError = true;
        continue;
      }

      if (id != null) {
        // Update Existing
        await DatabaseHelper.instance.updateDepartment(
          Department(id: id, name: name),
        );
      } else {
        // Create New
        await DatabaseHelper.instance.createDepartment(Department(name: name));
      }
    }

    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skipped empty fields. Others saved!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All Departments Saved Successfully!')),
      );
    }

    // Optional: Go to next screen if needed, or stay here
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const StudentInputScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.deepPurple;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Departments'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Manage Departments",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Add or edit department names below.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  // --- DYNAMIC FIELDS LIST ---
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _deptFields.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _deptFields[index]['controller'],
                                decoration: InputDecoration(
                                  labelText: 'Department Name ${index + 1}',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.business),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Delete Button
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteField(index),
                              tooltip: "Remove",
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  // --- ADD MORE BUTTON ---
                  OutlinedButton.icon(
                    onPressed: _addNewField,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Another Department"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- SAVE BUTTON ---
                  ElevatedButton(
                    onPressed: _saveDepartments,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save & Continue',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
