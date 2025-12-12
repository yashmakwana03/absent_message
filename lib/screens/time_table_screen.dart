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
        onPressed: () => _showAddLectureDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddLectureDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddLectureDialog(
        initialDay: _days[_tabController.index],
        onSave: () => setState(() {}), // Trigger rebuild to refresh list
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
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.class_, size: 20),
                ),
                title: Text(lecture['subject']),
                subtitle: Text("${lecture['faculty']} (${lecture['timeSlot']})"),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Theme.of(context).primaryColor),
                  onPressed: () async {
                    await DatabaseHelper.instance.deleteLecture(lecture['id']);
                    setState(() {}); // Refresh list
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- ADD DIALOG (Adapted from your code) ---
class AddLectureDialog extends StatefulWidget {
  final String initialDay;
  final VoidCallback onSave;

  const AddLectureDialog({super.key, required this.initialDay, required this.onSave});

  @override
  State<AddLectureDialog> createState() => _AddLectureDialogState();
}

class _AddLectureDialogState extends State<AddLectureDialog> {
  final _subjectController = TextEditingController();
  final _facultyController = TextEditingController();
  String? _selectedDay;
  String? _selectedTime;

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  final List<String> _timeSlots = [
    '08:00-08:55', '08:55-09:45', 
    '10:00-10:50', '10:50-11:40', 
    '12:30-01:20', '01:20-02:10'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDay;
  }

  Future<void> _save() async {
    if (_subjectController.text.isEmpty || _selectedTime == null) return;

    await DatabaseHelper.instance.createLecture({
      'day': _selectedDay,
      'timeSlot': _selectedTime,
      'subject': _subjectController.text,
      'faculty': _facultyController.text,
    });

    widget.onSave();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Lecture'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Subject Name'),
            ),
            TextField(
              controller: _facultyController,
              decoration: const InputDecoration(labelText: 'Faculty Name'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              value: _selectedDay,
              items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (val) => setState(() => _selectedDay = val as String?),
              decoration: const InputDecoration(labelText: 'Day'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              value: _selectedTime,
              items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _selectedTime = val as String?),
              decoration: const InputDecoration(labelText: 'Time Slot'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}