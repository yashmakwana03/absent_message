import 'dart:io';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

class CustomReportScreen extends StatefulWidget {
  const CustomReportScreen({super.key});

  @override
  State<CustomReportScreen> createState() => _CustomReportScreenState();
}

class _CustomReportScreenState extends State<CustomReportScreen> {
  // Filters
  final List<DateTime> _selectedDates = [];
  String _selectedSubject = 'All';
  List<String> _subjects = ['All'];
  
  // Data
  List<Map<String, dynamic>> _reportData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final subs = await DatabaseHelper.instance.getAllSubjects();
    if (mounted) {
      setState(() {
        _subjects = ['All', ...subs];
      });
    }
  }

  // --- 1. DATA GROUPING HELPER ---
  Map<String, Map<String, List<Map<String, dynamic>>>> _groupData() {
    Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};
    for (var row in _reportData) {
      String date = row['date'];
      String subject = row['subject'];

      if (!grouped.containsKey(date)) grouped[date] = {};
      if (!grouped[date]!.containsKey(subject)) grouped[date]![subject] = [];

      grouped[date]![subject]!.add(row);
    }
    return grouped;
  }

  // --- 2. DATE SELECTION ---
  Future<void> _pickDate() async {
    final config = CalendarDatePicker2WithActionButtonsConfig(
      calendarType: CalendarDatePicker2Type.multi,
      selectedDayHighlightColor: Colors.deepPurple,
    );

    final values = await showCalendarDatePicker2Dialog(
      context: context,
      config: config,
      dialogSize: const Size(325, 400),
      borderRadius: BorderRadius.circular(15),
      value: _selectedDates, 
      dialogBackgroundColor: Colors.white,
    );

    if (values != null) {
      setState(() {
        _selectedDates.clear();
        _selectedDates.addAll(values.whereType<DateTime>());
        _selectedDates.sort((a, b) => b.compareTo(a)); 
      });
    }
  }

  void _removeDate(DateTime date) {
    setState(() {
      _selectedDates.removeWhere((d) => d.year == date.year && d.month == date.month && d.day == date.day);
    });
  }

  Future<void> _generateReport() async {
    if (_selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add at least one date")));
      return;
    }

    setState(() => _isLoading = true);

    List<String> formattedDates = _selectedDates.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();
    final data = await DatabaseHelper.instance.getLogsForSpecificDates(formattedDates, _selectedSubject);

    if (mounted) {
      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    }
  }

  // --- 3. WHATSAPP TEXT GENERATOR ---
  String _generateTextReport() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln("*Attendance Report ($_selectedSubject)*");

    Map<String, Map<String, List<Map<String, dynamic>>>> grouped = _groupData();

    grouped.forEach((date, subjectsMap) {
      String formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.parse(date));
      buffer.writeln("\n*$formattedDate*");

      subjectsMap.forEach((subject, rows) {
        buffer.writeln("\n${subject.toUpperCase()} (Absentees)");
        for (var row in rows) {
           String dept = row['deptName'];
           String absentees = row['absentees'];
           buffer.writeln("- $dept : ${absentees.isEmpty ? 'None' : absentees}");
        }
      });
    });
    return buffer.toString();
  }

  // --- 4. HTML FILE GENERATOR ---
  String _generateHtmlReport() {
    Map<String, Map<String, List<Map<String, dynamic>>>> groupedBySubj = {};
    for (var row in _reportData) {
      String subj = row['subject'];
      String date = row['date']; 
      if (!groupedBySubj.containsKey(subj)) groupedBySubj[subj] = {};
      if (!groupedBySubj[subj]!.containsKey(date)) groupedBySubj[subj]![date] = [];
      groupedBySubj[subj]![date]!.add(row);
    }

    StringBuffer html = StringBuffer();
    
    html.writeln('''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Attendance Report</title>
<script src="https://cdn.tailwindcss.com"></script>
<link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700&display=swap" rel="stylesheet">
<style> 
    body { font-family: 'Outfit', sans-serif; background-color: #f8fafc; } 
    .card-hover:hover { transform: translateY(-2px); box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1); }
    .feedback-message { transition: all 0.3s ease; opacity: 0; transform: translateY(5px); }
    .feedback-message.show { opacity: 1; transform: translateY(0); }
</style>
</head>
<body class="bg-slate-50 min-h-screen p-4 md:p-8">
<div class="max-w-4xl mx-auto">
  <div class="text-center mb-10 p-6 bg-white rounded-2xl shadow-sm border border-slate-100">
    <h1 class="text-3xl font-bold text-slate-800 mb-2">Attendance Report</h1>
    <div class="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-indigo-50 text-indigo-700 font-medium text-sm">
      Subject: <span class="font-bold">$_selectedSubject</span>
    </div>
  </div>
  <div class="flex flex-col gap-8">
''');

    groupedBySubj.forEach((subject, datesMap) {
      String sectionColor = subject.length % 2 == 0 ? "blue" : "purple";
      html.writeln('<section class="relative">');
      html.writeln('''
        <div class="flex items-center gap-3 mb-5">
            <div class="h-8 w-1.5 bg-gradient-to-b from-$sectionColor-500 to-$sectionColor-700 rounded-full"></div>
            <h2 class="text-2xl font-bold text-slate-800">$subject</h2>
        </div>
        <div class="grid gap-6">
      ''');

      datesMap.forEach((date, logs) {
        DateTime dt = DateTime.parse(date);
        String dayNum = DateFormat('dd').format(dt);
        String month = DateFormat('MMM').format(dt).toUpperCase();
        String weekDay = DateFormat('EEEE').format(dt);

        html.writeln('''
        <div class="data-card bg-white p-5 rounded-2xl shadow-sm border border-slate-100 card-hover transition-all duration-300">
            <div class="flex items-center gap-4 border-b border-slate-100 pb-4 mb-4">
                <div class="flex flex-col items-center justify-center bg-$sectionColor-50 text-$sectionColor-700 px-4 py-2 rounded-xl">
                    <span class="text-2xl font-bold leading-none">$dayNum</span>
                    <span class="text-xs font-bold tracking-wider">$month</span>
                </div>
                <div>
                    <h3 class="font-semibold text-slate-700">$weekDay</h3>
                    <p class="text-xs text-slate-400">$date</p>
                </div>
            </div>
            <div class="space-y-4">
        ''');

        for (var log in logs) {
           String absentees = log['absentees'];
           List<String> nums = absentees.split(',').where((e) => e.isNotEmpty).toList();
           
           // --- FIX 1: ADDED COMMENT TO CATCH BLOCK ---
           try { 
             nums.sort((a,b) => int.parse(a).compareTo(int.parse(b))); 
           } catch(e) {
             // Ignore sort error for non-numeric rolls
           }
           
           String sortedAbsentees = nums.join(', ');
           String dept = log['deptName'];
           
           bool hasAbsentees = nums.isNotEmpty;
           String statusColor = hasAbsentees ? "rose" : "emerald"; 
           String statusLabel = hasAbsentees ? "Absentees" : "Status";
           String displayContent = hasAbsentees ? sortedAbsentees : "All Present ✨";
           String badgeText = hasAbsentees ? "Total: ${nums.length}" : "100%";
           String copyButtonDisplay = hasAbsentees ? "block" : "hidden"; 

           html.writeln('''
            <div class="number-container group">
                <div class="flex justify-between items-center mb-2">
                    <div class="flex items-center gap-2">
                        <span class="px-2.5 py-0.5 rounded-md bg-slate-100 text-slate-700 text-xs font-bold uppercase tracking-wide">$dept</span>
                        <span class="text-xs font-semibold text-$statusColor-600">$statusLabel</span>
                    </div>
                    <span class="text-xs font-bold text-$statusColor-700 bg-$statusColor-50 px-2 py-0.5 rounded-full">$badgeText</span>
                </div>
                
                <div class="relative flex items-center">
                    <div class="w-full bg-$statusColor-50 p-3 rounded-xl border border-$statusColor-100 text-$statusColor-900 font-mono text-sm leading-relaxed tracking-tight">
                        <span class="number-string">$displayContent</span>
                    </div>
                    
                    <button class="$copyButtonDisplay copy-btn absolute right-2 p-2 bg-white rounded-lg shadow-sm border border-slate-200 text-slate-500 hover:text-indigo-600 hover:border-indigo-200 hover:bg-indigo-50 transition-all duration-200">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path></svg>
                    </button>
                </div>
                <div class="feedback-message text-right text-xs font-medium text-indigo-600 mt-1 h-0 overflow-hidden"></div>
            </div>
           ''');
        }
        html.writeln('</div></div>');
      });
      html.writeln('</div></section>');
    });

    html.writeln('''
</div></div>
<script>
document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('.copy-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const container = e.currentTarget.closest('.number-container');
            const nums = container.querySelector('.number-string').textContent;
            const feedback = container.querySelector('.feedback-message');
            navigator.clipboard.writeText(nums).then(() => {
                feedback.textContent = 'Copied!';
                feedback.style.height = '20px';
                feedback.classList.add('show');
                setTimeout(() => { feedback.classList.remove('show'); feedback.style.height = '0'; }, 2000);
            });
        });
    });
});
</script>
</body></html>
''');
    return html.toString();
  }

  void _copyText() {
    if (_reportData.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _generateTextReport()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Text Copied!")));
  }


  Future<void> _shareHtml() async {
    if (_reportData.isEmpty) return;
    try {
      final htmlContent = _generateHtmlReport();
      final directory = await getTemporaryDirectory();
      String safeSubject = _selectedSubject.replaceAll(' ', '_');
      String fileName = "Attendance_${safeSubject}_${_selectedDates.length}Days.html";
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(htmlContent);
      await Share.shareXFiles([XFile(file.path)], text: 'Attendance Report');
    } catch (e) {
      // --- FIX 2: ADDED MOUNTED CHECK ---
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- 5. MAIN UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.deepPurple;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Export Reports"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- TOP CONTROLS ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.shade50,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedSubject, 
                  decoration: const InputDecoration(
                    labelText: "Select Subject",
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setState(() => _selectedSubject = val!),
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Date Range", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            "${_selectedDates.length} Dates Selected",
                            style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: primaryColor)),
                      ),
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: const Text("Pick Dates"),
                      onPressed: _pickDate,
                    )
                  ],
                ),
                
                if (_selectedDates.isNotEmpty)
                  Container(
                    height: 40,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _selectedDates.map((date) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(
                            DateFormat('dd/MM').format(date),
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                          ),
                          // Use withValues instead of withOpacity
                          backgroundColor: primaryColor.withValues(alpha: 0.8), 
                          deleteIconColor: Colors.white70,
                          onDeleted: () => _removeDate(date),
                          padding: const EdgeInsets.all(0),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide.none,
                        ),
                      )).toList(),
                    ),
                  ),

                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _generateReport,
                    child: const Text("Generate Report", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          
          // --- PREVIEW AREA ---
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _reportData.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.description_outlined, size: 80, color: Colors.grey.shade200),
                        const SizedBox(height: 16),
                        Text(
                          "No Data to Show",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Select dates & click Generate",
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  )
                : _buildGroupedList(), 
          ),

          // --- BOTTOM ACTIONS ---
          if (_reportData.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: Row(
                children: [
                   Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text("Copy Text"),
                      onPressed: _copyText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.deepPurple, // ✅ Changed to Deep Purple
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), // Matches your other cards
                        ),
                        elevation: 2, // Adds a subtle shadow for depth
                      ),
                      icon: const Icon(Icons.html, size: 18),
                      label: const Text("Share HTML"),
                      onPressed: _shareHtml,
                    ),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }

  // --- 6. PREVIEW LIST BUILDER ---
  Widget _buildGroupedList() {
    Map<String, Map<String, List<Map<String, dynamic>>>> grouped = _groupData();
    List<String> sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        String dateKey = sortedDates[index];
        Map<String, List<Map<String, dynamic>>> subjectsMap = grouped[dateKey]!;
        DateTime dt = DateTime.parse(dateKey);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade100)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('EEEE, dd MMM yyyy').format(dt),
                      style: const TextStyle(
                        color: Colors.deepPurple, 
                        fontWeight: FontWeight.bold,
                        fontSize: 14
                      ),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.deepPurple, size: 16),
                  ],
                ),
              ),

              // Content Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: subjectsMap.entries.map((entry) {
                    String subject = entry.key;
                    List<Map<String, dynamic>> rows = entry.value;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Subject Name
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                            child: Text(
                              subject,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          
                          // Dept Rows
                          ...rows.map((row) {
                            String dept = row['deptName'];
                            String absentees = row['absentees'];
                            bool hasAbsentees = absentees.trim().isNotEmpty;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      dept,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    hasAbsentees ? absentees : "All Present",
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: hasAbsentees ? Colors.black87 : Colors.green,
                                      fontFamily: hasAbsentees ? 'monospace' : null, 
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}