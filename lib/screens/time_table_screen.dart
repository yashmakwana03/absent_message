import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class TimeTableScreen extends StatefulWidget {
  const TimeTableScreen({super.key});

  @override
  State<TimeTableScreen> createState() => _TimeTableScreenState();
}

class _TimeTableScreenState extends State<TimeTableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- FUNCTION TO CONFIRM DELETE ALL ---
  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Time Table?"),
        content: const Text(
            "This will delete ALL lectures from the database. This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog first
              
              await DatabaseHelper.instance.deleteAllLectures(); // Async work
              
              // ✅ FIXED: Check mounted before using context again
              if (!mounted) return;

              setState(() {}); // Refresh UI
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Time table cleared!")),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete All"),
          ),
        ],
      ),
    );
  }

  void _showLectureDialog(
    BuildContext context,
    Map<String, dynamic>? existingLecture,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LectureDialog(
        initialDay: _days[_tabController.index],
        existingLecture: existingLecture,
        onSave: () => setState(() {}),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Table'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: "Clear All Data",
            onPressed: _confirmDeleteAll,
          ),
        ],
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
        onPressed: () => _showLectureDialog(context, null),
        child: const Icon(Icons.add),
      ),
    );
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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final lectures = snapshot.data!;

        if (lectures.isEmpty) {
          return const Center(child: Text("No lectures added for this day."));
        }

        return ListView.builder(
          itemCount: lectures.length,
          itemBuilder: (context, index) {
            final lecture = lectures[index];
            bool isElective = lecture['isElective'] == 1;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              shape: isElective
                  ? RoundedRectangleBorder(
                      side: const BorderSide(color: Colors.orange, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isElective
                      ? Colors.orange.shade100
                      : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    "${lecture['sortOrder'] ?? index + 1}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isElective
                          ? Colors.deepOrange
                          : Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                title: Text(
                  lecture['subject'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "${lecture['faculty']} (${lecture['timeSlot']})",
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey),
                      onPressed: () {
                        context
                            .findAncestorStateOfType<_TimeTableScreenState>()
                            ?._showLectureDialog(context, lecture);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      onPressed: () async {
                        await DatabaseHelper.instance.deleteLecture(
                          lecture['id'],
                        );
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

// --- LECTURE DIALOG ---
class LectureDialog extends StatefulWidget {
  final String initialDay;
  final Map<String, dynamic>? existingLecture;
  final VoidCallback onSave;

  const LectureDialog({
    super.key,
    required this.initialDay,
    this.existingLecture,
    required this.onSave,
  });

  @override
  State<LectureDialog> createState() => _LectureDialogState();
}

class _LectureDialogState extends State<LectureDialog> {
  final _subjectController = TextEditingController();
  final _facultyController = TextEditingController();
  final _timeController = TextEditingController();
  final _orderController = TextEditingController();

  String? _selectedDay;
  bool _isElective = false;

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    if (widget.existingLecture != null) {
      _subjectController.text = widget.existingLecture!['subject'];
      _facultyController.text = widget.existingLecture!['faculty'];
      _timeController.text = widget.existingLecture!['timeSlot'];
      _orderController.text = (widget.existingLecture!['sortOrder'] ?? '1').toString();
      _selectedDay = widget.existingLecture!['day'];
      _isElective = widget.existingLecture!['isElective'] == 1;
    } else {
      _selectedDay = widget.initialDay;
      _orderController.text = '1';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Day')),
      );
      return;
    }

    final data = {
      'day': _selectedDay,
      'timeSlot': _timeController.text,
      'subject': _subjectController.text,
      'faculty': _facultyController.text,
      'isElective': _isElective ? 1 : 0,
      'sortOrder': int.parse(_orderController.text),
    };

    if (widget.existingLecture == null) {
      await DatabaseHelper.instance.createLecture(data);
    } else {
      await DatabaseHelper.instance.deleteLecture(
        widget.existingLecture!['id'],
      );
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 70,
                    child: TextFormField(
                      controller: _orderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'No.',
                        hintText: '1',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return '*';
                        if (int.tryParse(value) == null) return 'Err';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        hintText: 'e.g. .NET',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _facultyController,
                decoration: const InputDecoration(
                  labelText: 'Faculty Name',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text("Is this an Elective?"),
                subtitle: const Text("Check this for combined batches"),
                value: _isElective,
                activeColor: Colors.deepPurple,
                onChanged: (val) => setState(() => _isElective = val ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField(
                      initialValue: _selectedDay, // Fixed deprecated initialValue usage if needed, but value is standard here
                      isExpanded: true,
                      items: _days
                          .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(d, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedDay = val),
                      decoration: const InputDecoration(
                        labelText: 'Day',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _timeController,
                      decoration: const InputDecoration(
                        labelText: 'Time',
                        hintText: '10:30',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 15,
                        ),
                      ),
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(isEdit ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}