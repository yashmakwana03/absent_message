//  Register Students - View, Edit, Delete

import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/student.dart';
import 'student_input_screen.dart'; 

class DataViewScreen extends StatefulWidget {
  const DataViewScreen({super.key});

  @override
  State<DataViewScreen> createState() => _DataViewScreenState();
}

class _DataViewScreenState extends State<DataViewScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  List<String> _deptNames = [];
  
  bool _isLoading = true;
  String _searchQuery = "";
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.readAllStudentsWithDeptName();
    
    final depts = data.map((s) => s['departmentName'] as String).toSet().toList();
    depts.sort();

    if (mounted) {
      setState(() {
        _allStudents = data;
        _filteredStudents = data;
        _deptNames = depts;
        
        _tabController?.dispose();
        if (depts.isNotEmpty) {
          _tabController = TabController(length: depts.length, vsync: this);
        }
        
        _isLoading = false;
      });
    }
  }

  void _filterSearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredStudents = _allStudents;
      } else {
        _filteredStudents = _allStudents.where((s) {
          final name = s['name'].toString().toLowerCase();
          final roll = s['rollNumber'].toString();
          return name.contains(query.toLowerCase()) || roll.contains(query);
        }).toList();
      }
    });
  }

  // --- ACTIONS ---

  Future<void> _editStudent(Map<String, dynamic> studentData) async {
    final nameController = TextEditingController(text: studentData['name']);
    final rollController = TextEditingController(text: studentData['rollNumber'].toString());

    await showDialog(
      context: context,
      // Rename context to dialogCtx to avoid confusion with parent context
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Edit Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rollController,
              decoration: const InputDecoration(labelText: 'Roll Number', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Student Name', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final updatedStudent = Student(
                id: studentData['id'],
                deptId: studentData['deptId'],
                rollNumber: rollController.text,
                name: nameController.text,
              );
              try {
                await DatabaseHelper.instance.updateStudent(updatedStudent);
                
                // FIX: Check if dialog is still mounted before popping
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }

                // FIX: Check if parent widget is mounted before using scaffold/refresh
                if (mounted) {
                  _refreshData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully!')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Duplicate Roll Number?')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStudent(int id) async {
    await DatabaseHelper.instance.deleteStudent(id);
    // FIX: Check mounted before using context after await
    if (mounted) {
      _refreshData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Student deleted")));
    }
  }

  Future<void> _deleteAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Student Registry?"),
        content: const Text(
          "This will delete ALL Students and their Enrollments.\n\n"
          "Lectures and Attendance Logs will NOT be deleted.",
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("DELETE ALL"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('Student');
      await db.delete('SubjectEnrollment');
      
      if (mounted) {
        _refreshData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Student Registry Cleared.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.deepPurple;

    return Scaffold(
      backgroundColor: Colors.grey[50], 
      appBar: AppBar(
        title: const Text('Student Registry'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: "Clear Registry",
            onPressed: _deleteAllData,
          )
        ],
        bottom: _deptNames.isEmpty ? null : TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _deptNames.map((name) => Tab(text: name)).toList(),
        ),
      ),
      
      // --- ADD BUTTON ---
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        child: const Icon(Icons.person_add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => const StudentInputScreen())
          ).then((_) => _refreshData());
        },
      ),

      body: Column(
        children: [
          // --- SEARCH BAR ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            color: primaryColor,
            child: TextField(
              onChanged: _filterSearch,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: "Search name or roll no...",
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),

          // --- MAIN CONTENT ---
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _deptNames.isEmpty
                ? const Center(child: Text("No data found."))
                : TabBarView(
                    controller: _tabController,
                    children: _deptNames.map((dept) {
                      final tabStudents = _filteredStudents.where((s) => s['departmentName'] == dept).toList();
                      
                      // Sort Numerically
                      tabStudents.sort((a, b) {
                        String r1 = a['rollNumber'].toString();
                        String r2 = b['rollNumber'].toString();
                        try {
                          return int.parse(r1.replaceAll(RegExp(r'[^0-9]'), ''))
                              .compareTo(int.parse(r2.replaceAll(RegExp(r'[^0-9]'), '')));
                        } catch(e) { 
                          return r1.compareTo(r2); 
                        }
                      });

                      if (tabStudents.isEmpty) {
                        return Center(child: Text("No students found in $dept matching '$_searchQuery'"));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 80), // Added bottom padding for FAB
                        itemCount: tabStudents.length,
                        itemBuilder: (context, index) {
                          final s = tabStudents[index];
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                // FIX: Use withValues(alpha: ...) instead of withOpacity
                                backgroundColor: primaryColor.withValues(alpha: 0.1),
                                child: Text(
                                  s['rollNumber'].toString(),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                                ),
                              ),
                              title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                              
                              // --- DIRECT BUTTONS ROW ---
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey),
                                    onPressed: () => _editStudent(s),
                                    tooltip: "Edit",
                                    constraints: const BoxConstraints(), // Compact
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                                    onPressed: () => _deleteStudent(s['id']),
                                    tooltip: "Delete",
                                    constraints: const BoxConstraints(), // Compact
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}