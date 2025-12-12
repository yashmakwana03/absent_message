import 'package:flutter/material.dart';
import 'department_setup_screen.dart';
import 'student_input_screen.dart';
import 'data_view_screen.dart';
import 'time_table_screen.dart';
//import 'report_generator_screen.dart';
import 'report_generator_v3.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance App Dashboard'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _buildButton(
              context, 
              'Setup Departments', 
              const DepartmentSetupScreen(),
              Icons.business,
            ),
            const SizedBox(height: 20),
            _buildButton(
              context, 
              'Add Students', 
              const StudentInputScreen(),
              Icons.person_add,
            ),
            const SizedBox(height: 20),
            _buildButton(
              context, 
              'View All Data', 
              const DataViewScreen(),
              Icons.list_alt,
            ),
            const SizedBox(height: 20),
            _buildButton(
              context, 
              'Manage Time Table', 
              const TimeTableScreen(), // Link to Time Table
              Icons.schedule,
            ),
            const SizedBox(height: 20),
            _buildButton(
              context, 
              'Generate Daily Report', 
              const ReportGeneratorScreenV3(), // Link to Report Generator
              Icons.message,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String title, Widget destination, IconData icon, {bool disabled = false}) {
    return SizedBox(
      width: 250,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(title),
        onPressed: disabled ? null : () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}