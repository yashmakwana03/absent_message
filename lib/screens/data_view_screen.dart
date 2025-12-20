import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/student.dart';
import 'student_input_screen.dart'; // <--- NEW IMPORT

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
    
    // Extract unique department names for tabs
    final depts = data.map((s) => s['departmentName'] as String).toSet().toList();
    depts.sort();

    if (mounted) {
      setState(() {
        _allStudents = data;
        _filteredStudents = data;
        _deptNames = depts;
        
        // Initialize TabController based on department count
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
      builder: (context) => AlertDialog(
        title: const Text('Edit Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rollController,
              decoration: const InputDecoration(labelText: 'Roll Number', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Student Name', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
                if (mounted) {
                  Navigator.pop(context);
                  _refreshData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully!')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Duplicate Roll Number?')));
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
    _refreshData();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Student deleted")));
  }

  Future<void> _deleteAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ FACTORY RESET"),
        content: const Text(
          "This will wipe everything:\n\n"
          "• All Students\n"
          "• All Departments\n\n"
          "Are you absolutely sure?",
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("DELETE EVERYTHING"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteAllData(); // Ensure this method clears tables in DB Helper
      _refreshData();
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All data has been wiped.")),
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
        title: const Text('Student Registry'), // Proper Title
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: "Wipe All Data",
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
          // Navigate to Add Student Screen and refresh when back
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
                ? const Center(child: Text("No data found. Tap + to add students."))
                : TabBarView(
                    controller: _tabController,
                    children: _deptNames.map((dept) {
                      // Filter list for this tab + search query
                      final tabStudents = _filteredStudents.where((s) => s['departmentName'] == dept).toList();
                      
                      // Sort by Roll Number
                      tabStudents.sort((a, b) {
                        try {
                          return int.parse(a['rollNumber'].toString()).compareTo(int.parse(b['rollNumber'].toString()));
                        } catch(e) { return 0; }
                      });

                      if (tabStudents.isEmpty) {
                        return Center(child: Text("No students found in $dept matching '$_searchQuery'"));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: tabStudents.length,
                        itemBuilder: (context, index) {
                          final s = tabStudents[index];
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: primaryColor.withOpacity(0.1),
                                child: Text(
                                  s['rollNumber'].toString(),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                                ),
                              ),
                              title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                              
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _editStudent(s);
                                  if (value == 'delete') _deleteStudent(s['id']);
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 10), Text("Edit")]),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 10), Text("Delete", style: TextStyle(color: Colors.red))]),
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