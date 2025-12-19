import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 

import 'department_setup_screen.dart';
import 'student_input_screen.dart';
import 'data_view_screen.dart';
import 'time_table_screen.dart';
import 'report_generator_v3.dart';
import 'attendance_history_screen.dart';
import 'backup_screen.dart';
import 'daily_report_screen.dart';
import 'search_screen.dart';
import 'about_me_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // --- COLOR THEME: DEEP PURPLE ---
    const primaryColor = Colors.deepPurple; 
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Standard Light Grey Background
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white, // White text
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About Developer',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutMeScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            _buildHeader(context),
            const SizedBox(height: 20),

            // --- MAIN CARD (Take Attendance) ---
            Text(
              "Quick Actions", 
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold, 
                color: Colors.grey[800]
              )
            ),
            const SizedBox(height: 10),
            
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportGeneratorScreenV3())),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.shade50, // Very light purple
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_note, size: 32, color: primaryColor),
                      ),
                      const SizedBox(width: 20),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Take Attendance", 
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                          ),
                          SizedBox(height: 4),
                          Text("Mark Absent & Share", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // --- SECONDARY ROW ---
            Row(
              children: [
                Expanded(
                  child: _buildSimpleCard(
                    context, 
                    title: "Dashboard", 
                    icon: Icons.dashboard, 
                    destination: const DailyReportScreen(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSimpleCard(
                    context, 
                    title: "Search Student", 
                    icon: Icons.search, 
                    destination: const SearchScreen(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // --- GRID SECTION ---
            Text(
              "Management", 
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold, 
                color: Colors.grey[800]
              )
            ),
            const SizedBox(height: 10),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
              children: [
                _buildGridIcon(context, "Departments", Icons.business, const DepartmentSetupScreen()),
                _buildGridIcon(context, "Students", Icons.people, const StudentInputScreen()),
                _buildGridIcon(context, "Time Table", Icons.schedule, const TimeTableScreen()),
                _buildGridIcon(context, "All Data", Icons.list_alt, const DataViewScreen()),
                _buildGridIcon(context, "History", Icons.history, const AttendanceHistoryScreen()),
                _buildGridIcon(context, "Backup", Icons.settings_backup_restore, const BackupScreen()),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader(BuildContext context) {
    String dateStr = DateFormat('EEEE, d MMMM').format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Welcome,",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        Text(
          dateStr,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // Medium Card (White with Deep Purple Icon)
  Widget _buildSimpleCard(BuildContext context, {required String title, required IconData icon, required Widget destination}) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: Colors.deepPurple),
              const SizedBox(height: 8),
              Text(
                title, 
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Small Grid Item (Square)
  Widget _buildGridIcon(BuildContext context, String title, IconData icon, Widget destination) {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination)),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: Colors.deepPurple), // Deep Purple Icon
            const SizedBox(height: 8),
            Text(
              title, 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}