import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Backup & Restore"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.settings_backup_restore, size: 80, color: Colors.grey),
              const SizedBox(height: 40),
              
              // --- BACKUP BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await DatabaseHelper.instance.exportDatabase();
                  },
                  icon: const Icon(Icons.upload),
                  label: const Text("Create Backup"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Saves a copy of your data to share or keep safe.",
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),

              // --- RESTORE BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Confirm before restoring
                    bool confirm = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Restore Data?"),
                        content: const Text(
                          "This will OVERWRITE all current data with the backup file. This cannot be undone.",
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true), 
                            child: const Text("Restore", style: TextStyle(color: Colors.red))
                          ),
                        ],
                      ),
                    ) ?? false;

                    if (confirm) {
                      bool success = await DatabaseHelper.instance.importDatabase();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? "Data Restored Successfully!" : "Restore Failed or Canceled"),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.download),
                  label: const Text("Restore Backup"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Select a previously saved .db file to restore.",
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}