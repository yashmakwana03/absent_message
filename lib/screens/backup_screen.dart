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
              
              // --- BACKUP SECTION ---
              const Text("Backup Data", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              // Button 1: SHARE (WhatsApp, Drive, etc.)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Uses the new shareDatabase function
                    await DatabaseHelper.instance.shareDatabase();
                  },
                  icon: const Icon(Icons.share),
                  label: const Text("Share Backup File"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              
              const SizedBox(height: 10),

              // Button 2: SAVE LOCALLY (Folder Picker)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Uses the new saveDatabaseLocally function
                    String? path = await DatabaseHelper.instance.saveDatabaseLocally();
                    
                    if (context.mounted && path != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Saved to: $path"),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.folder),
                  label: const Text("Save to Device Folder"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 20),

              // --- RESTORE SECTION ---
              const Text("Restore Data", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    bool confirm = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Restore Data?"),
                        content: const Text("This will OVERWRITE all current data. Cannot be undone."),
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
                            content: Text(success ? "Restored Successfully!" : "Failed or Canceled"),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.download),
                  label: const Text("Restore from File"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}