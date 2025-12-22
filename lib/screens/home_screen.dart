import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 

import '../database/database_helper.dart'; 
import 'department_setup_screen.dart';
import 'student_input_screen.dart';
import 'data_view_screen.dart';
import 'time_table_screen.dart';
import 'report_generator_v3.dart';
import 'backup_screen.dart';
import 'daily_report_screen.dart';
import 'search_screen.dart';
import 'about_me_screen.dart';
import 'manage_enrollment_screen.dart';
import 'custom_report_screen.dart';
import 'attendance_log_screen.dart'; // ✅ Imported New Screen

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // --- FACTORY RESET LOGIC ---
  Future<void> _factoryReset(BuildContext context) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ FACTORY RESET", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("This will permanently delete ALL data:\n\n• Students\n• Subjects\n• Attendance Logs\n\nAre you absolutely sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("DELETE EVERYTHING"),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await DatabaseHelper.instance.deleteAllData(); 
      final db = await DatabaseHelper.instance.database;
      // Double check cleanup
      await db.delete('AttendanceLog');
      await db.delete('Lecture');
      await db.delete('SubjectEnrollment');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("App Reset Successfully. Start Fresh!")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.deepPurple; 
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Attendance CR'), 
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutMeScreen()));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. HEADER ---
            _buildHeader(),
            const SizedBox(height: 24),

            // --- 2. MAIN ACTION (Take Attendance) ---
            _buildMainActionCard(context),
            const SizedBox(height: 30),

            // --- 3. THE MENU GRID ---
            const Text(
              "Menu", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
            ),
            const SizedBox(height: 16),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85, 
              children: [
                // ROW 1: SETUP (Orange)
                _buildGridItem(context, "1. Depts", Icons.domain, Colors.orange, destination: const DepartmentSetupScreen()),
                _buildGridItem(context, "2. Students", Icons.group_add, Colors.orange, destination: const StudentInputScreen()),
                _buildGridItem(context, "3. Time Table", Icons.calendar_month, Colors.orange, destination: const TimeTableScreen()),
                
                // ROW 2: MANAGEMENT (Blue)
                _buildGridItem(context, "4. Electives", Icons.how_to_reg, Colors.blue, destination: const ManageEnrollmentScreen()),
                _buildGridItem(context, "Directory", Icons.list_alt, Colors.blue, destination: const DataViewScreen()),
                _buildGridItem(context, "View Logs", Icons.history_edu, Colors.blue, destination: const AttendanceLogScreen()), // ✅ New Log Screen

                // ROW 3: REPORTS (Teal)
                _buildGridItem(context, "Analytics", Icons.analytics, Colors.teal, destination: const SearchScreen()),
                _buildGridItem(context, "Export", Icons.print, Colors.teal, destination: const CustomReportScreen()),
                _buildGridItem(context, "Backup", Icons.settings_backup_restore, Colors.teal, destination: const BackupScreen()),
                
                // ROW 4: DANGER (Red)
                _buildGridItem(
                  context, 
                  "Reset App", 
                  Icons.delete_forever, 
                  Colors.red, 
                  onAction: () => _factoryReset(context) // ✅ Triggers Function
                ),
              ],
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildHeader() {
    String dateStr = DateFormat('EEEE, d MMMM').format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Dashboard",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black87),
        ),
        Text(
          dateStr,
          style: TextStyle(fontSize: 15, color: Colors.grey[600], fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMainActionCard(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.deepPurple.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.deepPurple,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportGeneratorScreenV3())),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.edit_note, size: 36, color: Colors.white),
              ),
              const SizedBox(width: 20),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Take Attendance", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 4),
                  Text("Mark absent & Share report", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Updated to handle both Page Navigation (destination) AND Functions (onAction)
  Widget _buildGridItem(BuildContext context, String title, IconData icon, Color color, {Widget? destination, VoidCallback? onAction}) {
    return Card(
      elevation: 0, 
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          if (onAction != null) {
            onAction(); // Run function (Factory Reset)
          } else if (destination != null) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => destination)); // Go to Page
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title, 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}