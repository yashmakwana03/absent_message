import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Define Theme Colors
    final primaryColor = Colors.deepPurple;
    final secondaryColor = Colors.indigo;
    final backgroundColor = Colors.deepPurple.shade50;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Backup & Restore"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER ICON ---
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      // ✅ Fixed Deprecation
                      color: primaryColor.withValues(alpha: 0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Icon(
                  Icons.cloud_sync_outlined,
                  size: 60,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // --- BACKUP SECTION ---
            _buildSectionCard(
              context,
              title: "Backup Data",
              icon: Icons.upload_file,
              color: secondaryColor,
              children: [
                const Text(
                  "Export your attendance data to keep it safe. You can share it to WhatsApp, Google Drive, or save it locally.",
                  style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 20),
                
                // Button 1: Share
                FilledButton.icon(
                  onPressed: () async {
                    await DatabaseHelper.instance.shareDatabase();
                  },
                  icon: const Icon(Icons.share),
                  label: const Text("Share Backup File"),
                  style: FilledButton.styleFrom(
                    backgroundColor: secondaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),

                // Button 2: Save Locally
                OutlinedButton.icon(
                  onPressed: () async {
                    // Note: If this only asks for path once, check your DatabaseHelper logic.
                    // It might be saving the path to SharedPreferences.
                    String? path = await DatabaseHelper.instance.saveDatabaseLocally();
                    if (context.mounted && path != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Saved to: $path"),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text("Save to Device Folder"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: secondaryColor,
                    side: BorderSide(color: secondaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --- RESTORE SECTION ---
            _buildSectionCard(
              context,
              title: "Restore Data",
              icon: Icons.settings_backup_restore,
              color: Colors.red.shade700, 
              isDangerZone: true,
              children: [
                const Text(
                  "Import a backup file to restore your data.\n⚠️ This will completely REPLACE your current data.",
                  style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 20),

                // Button: Restore
                FilledButton.icon(
                  onPressed: () => _handleRestore(context),
                  icon: const Icon(Icons.download),
                  label: const Text("Restore from File"),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700, 
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER: RESTORE LOGIC ---
  Future<void> _handleRestore(BuildContext context) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Restore Data?"),
        content: const Text(
          "This action will DELETE all current data and replace it with the backup file.\n\nAre you sure?",
          style: TextStyle(color: Colors.black87),
        ),
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Yes, Restore"),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      bool success = await DatabaseHelper.instance.importDatabase();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "Restored Successfully!" : "Restore Failed or Canceled"),
            backgroundColor: success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- HELPER: CARD BUILDER ---
  Widget _buildSectionCard(BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    bool isDangerZone = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDangerZone ? BorderSide(color: Colors.red.shade100, width: 1.5) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    // ✅ Fixed Deprecation
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ],
        ),
      ),
    );
  }
}