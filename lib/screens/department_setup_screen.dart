import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/department.dart';
import 'student_input_screen.dart'; // We will create this next

class DepartmentSetupScreen extends StatefulWidget {
  const DepartmentSetupScreen({super.key});

  @override
  State<DepartmentSetupScreen> createState() => _DepartmentSetupScreenState();
}

class _DepartmentSetupScreenState extends State<DepartmentSetupScreen> {
  // Use a map to store the TextControllers for dynamic departments
  final Map<int, TextEditingController> _controllers = {};
  int _departmentCount = 1;

  @override
  void dispose() {
    // Dispose all controllers when the widget is removed
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  // --- Step 1: Save the Department Data ---
  Future<void> _saveDepartments() async {
    final List<Department> departments = [];
    bool hasError = false;

    // Validate and create Department objects
    _controllers.forEach((index, controller) {
      final name = controller.text.trim();
      if (name.isEmpty) {
        hasError = true;
      } else {
        departments.add(Department(name: name));
      }
    });

    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for all departments.')),
      );
      return;
    }

    final dbHelper = DatabaseHelper.instance;
    for (var dept in departments) {
      await dbHelper.createDepartment(dept);
    }

    // Navigate to the next screen after saving
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const StudentInputScreen()),
      );
    }
  }

  // --- Step 2: Build the UI to dynamically add department fields ---
  Widget _buildDepartmentFields() {
    // Ensure we have a controller for every field
    while (_controllers.length < _departmentCount) {
      _controllers[_controllers.length + 1] = TextEditingController();
    }
    // Remove extra controllers if the count was reduced
    while (_controllers.length > _departmentCount) {
      _controllers.remove(_controllers.length);
    }

    return Column(
      children: List.generate(_departmentCount, (index) {
        final key = index + 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: TextFormField(
            controller: _controllers[key],
            decoration: InputDecoration(
              labelText: 'Department Name $key',
              border: const OutlineInputBorder(),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Departments'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Input for the number of departments
            TextFormField(
              initialValue: _departmentCount.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'How many departments?',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                int? newCount = int.tryParse(value);
                if (newCount != null && newCount > 0) {
                  setState(() {
                    _departmentCount = newCount;
                  });
                }
              },
            ),
            const SizedBox(height: 20),
            
            // Dynamic Department Name Inputs
            _buildDepartmentFields(),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveDepartments,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('Save & Continue to Student Input'),
            ),
          ],
        ),
      ),
    );
  }
}