import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class TimeTableScreen extends StatefulWidget {
  const TimeTableScreen({super.key});

  @override
  State<TimeTableScreen> createState() => _TimeTableScreenState();
}

class _TimeTableScreenState extends State<TimeTableScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Table'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _days.map((day) => Tab(text: day)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _days.map((day) => _DayScheduleView(day: day)).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        // Add New Lecture
        onPressed: () => _showLectureDialog(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  // Unified function to show dialog for ADD or EDIT
  void _showLectureDialog(BuildContext context, Map<String, dynamic>? existingLecture) {
    showDialog(
      context: context,
      builder: (context) => LectureDialog(
        initialDay: _days[_tabController.index],
        existingLecture: existingLecture, // Pass null for Add, data for Edit
        onSave: () => setState(() {}), // Refresh UI
      ),
    ).then((_) => setState(() {}));
  }
}

class _DayScheduleView extends StatefulWidget {
  final String day;
  const _DayScheduleView({required this.day});

  @override
  State<_DayScheduleView> createState() => _DayScheduleViewState();
}

class _DayScheduleViewState extends State<_DayScheduleView> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getLecturesByDay(widget.day),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final lectures = snapshot.data!;

        if (lectures.isEmpty) {
          return const Center(child: Text("No lectures added for this day."));
        }

        return ListView.builder(
          itemCount: lectures.length,
          itemBuilder: (context, index) {
            final lecture = lectures[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(Icons.class_, size: 20, color: Theme.of(context).primaryColor),
                ),
                title: Text(lecture['subject'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${lecture['faculty']} (${lecture['timeSlot']})"),
                
                // You can still tap the whole card to edit if you want
                onTap: () {
                  context.findAncestorStateOfType<_TimeTableScreenState>()
                      ?._showLectureDialog(context, lecture);
                },

                // --- CHANGED: Now shows Edit AND Delete icons ---
                trailing: Row(
                  mainAxisSize: MainAxisSize.min, // Important: Keeps the icons close together
                  children: [
                    // 1. Edit Button (Pencil)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey),
                      tooltip: 'Edit Lecture',
                      onPressed: () {
                        context.findAncestorStateOfType<_TimeTableScreenState>()
                            ?._showLectureDialog(context, lecture);
                      },
                    ),
                    // 2. Delete Button (Trash)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      tooltip: 'Delete Lecture',
                      onPressed: () async {
                        await DatabaseHelper.instance.deleteLecture(lecture['id']);
                        setState(() {}); 
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- UNIFIED DIALOG (Handles both ADD and EDIT) ---
class LectureDialog extends StatefulWidget {
  final String initialDay;
  final Map<String, dynamic>? existingLecture; // If null -> Add Mode, Else -> Edit Mode
  final VoidCallback onSave;

  const LectureDialog({
    super.key, 
    required this.initialDay, 
    this.existingLecture, 
    required this.onSave
  });

  @override
  State<LectureDialog> createState() => _LectureDialogState();
}

class _LectureDialogState extends State<LectureDialog> {
  final _subjectController = TextEditingController();
  final _facultyController = TextEditingController();
  final _timeController = TextEditingController(); // Changed to Controller for custom input
  String? _selectedDay;

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  @override
  void initState() {
    super.initState();
    
    if (widget.existingLecture != null) {
      // --- EDIT MODE: Pre-fill data ---
      _subjectController.text = widget.existingLecture!['subject'];
      _facultyController.text = widget.existingLecture!['faculty'];
      _timeController.text = widget.existingLecture!['timeSlot'];
      _selectedDay = widget.existingLecture!['day'];
    } else {
      // --- ADD MODE: Defaults ---
      _selectedDay = widget.initialDay;
    }
  }

  Future<void> _save() async {
    if (_subjectController.text.isEmpty || _timeController.text.isEmpty) return;

    final data = {
      'day': _selectedDay,
      'timeSlot': _timeController.text, // Save custom text
      'subject': _subjectController.text,
      'faculty': _facultyController.text,
    };

    if (widget.existingLecture == null) {
      // CREATE
      await DatabaseHelper.instance.createLecture(data);
    } else {
      // UPDATE (We need to add an update function to DatabaseHelper first, see below)
      // For now, since update isn't in your helper, we do a trick: Delete & Re-create
      // Ideally, add an update method to your DB helper. 
      // Assuming you might not have 'updateLecture', here is the workaround:
      
      // Option A: If you added updateLecture(id, map) to helper:
      // await DatabaseHelper.instance.updateLecture(widget.existingLecture!['id'], data);
      
      // Option B: Delete old and Create new (Fastest fix without changing DB helper)
      await DatabaseHelper.instance.deleteLecture(widget.existingLecture!['id']);
      await DatabaseHelper.instance.createLecture(data);
    }

    widget.onSave();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    bool isEdit = widget.existingLecture != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Lecture' : 'Add Lecture'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Subject Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _facultyController,
              decoration: const InputDecoration(labelText: 'Faculty Name'),
            ),
            const SizedBox(height: 10),
            
            // --- Day Dropdown ---
            DropdownButtonFormField(
              value: _selectedDay,
              items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (val) => setState(() => _selectedDay = val as String?),
              decoration: const InputDecoration(labelText: 'Day'),
            ),
            const SizedBox(height: 10),
            
            // --- Custom Time Input (TextField) ---
            TextField(
              controller: _timeController,
              decoration: const InputDecoration(
                labelText: 'Time Slot',
                hintText: 'e.g. 10:30 - 11:30', // Hint for user
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: Text(isEdit ? 'Update' : 'Save')),
      ],
    );
  }
}