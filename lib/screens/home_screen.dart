import 'package:absent_message/screens/about_me_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 

import '../database/database_helper.dart'; 
import 'department_setup_screen.dart';
import 'student_input_screen.dart';
import 'data_view_screen.dart';
import 'time_table_screen.dart';
import 'report_generator_v3.dart';
import 'backup_screen.dart';
import 'daily_report_screen.dart'; // ✅ Now Used
import 'search_screen.dart'; // ✅ Now Used in top row
import 'manage_enrollment_screen.dart';
import 'custom_report_screen.dart';
import 'attendance_log_screen.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("App Reset Successfully.")));
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
          // ✅ Feedback / Developer Icon
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'About Me',
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

            // --- 2. PRIMARY ACTION (Big Card) ---
            _buildMainActionCard(context),
            const SizedBox(height: 16),

            // --- 3. SECONDARY ACTIONS (Row: Daily Report + Analytics) ---
            Row(
              children: [
                Expanded(
                  child: _buildSmallActionCard(
                    context, 
                    "Daily Report", 
                    Icons.assignment_ind, 
                    Colors.teal, 
                    const DailyReportScreen(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSmallActionCard(
                    context, 
                    "Analytics", 
                    Icons.analytics, 
                    Colors.indigo, 
                    const SearchScreen(),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 30),

            // --- 4. MENU GRID ---
            const Text(
              "Management & Tools", 
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
                // ROW 1: Setup
                _buildGridItem(context, "1. Depts", Icons.domain, Colors.orange, destination: const DepartmentSetupScreen()),
                _buildGridItem(context, "2. Students", Icons.group_add, Colors.orange, destination: const StudentInputScreen()),
                _buildGridItem(context, "3. Time Table", Icons.calendar_month, Colors.orange, destination: const TimeTableScreen()),
                
                // ROW 2: Data & Logs
                _buildGridItem(context, "4. Electives", Icons.how_to_reg, Colors.blue, destination: const ManageEnrollmentScreen()),
                _buildGridItem(context, "Student Reg.", Icons.list_alt, Colors.blue, destination: const DataViewScreen()),
                _buildGridItem(context, "View Logs", Icons.history_edu, Colors.blue, destination: const AttendanceLogScreen()),

                // ROW 3: Tools
                _buildGridItem(context, "Share Data", Icons.share, Colors.brown, destination: const CustomReportScreen()),
                _buildGridItem(context, "Backup DB", Icons.settings_backup_restore, Colors.brown, destination: const BackupScreen()),
                _buildGridItem(
                  context, 
                  "Reset App", 
                  Icons.delete_forever, 
                  Colors.red, 
                  onAction: () => _factoryReset(context)
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader() {
    String dateStr = DateFormat('EEEE, d MMMM').format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Dashboard", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black87)),
        Text(dateStr, style: TextStyle(fontSize: 15, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      ],
    );
  }

  // Big Card for Taking Attendance
  Widget _buildMainActionCard(BuildContext context) {
    return Card(
      elevation: 6,
      shadowColor: Colors.deepPurple.withValues(alpha: 0.3),
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
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
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

  // Medium Cards for Reports/Analytics
  Widget _buildSmallActionCard(BuildContext context, String title, IconData icon, Color color, Widget destination) {
    return Card(
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination)),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 12),
              Text(
                title, 
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Small Grid Items for Menu
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
            onAction(); 
          } else if (destination != null) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => destination)); 
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title, 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}