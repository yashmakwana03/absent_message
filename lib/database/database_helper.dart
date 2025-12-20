import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/department.dart';
import '../models/student.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Getter to provide the database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attendance_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, 
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // --- UPGRADE LOGIC (For existing users) ---
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Ensure Lecture table exists (Renaming TimeTable concept to Lecture)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Lecture (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          day TEXT NOT NULL,
          timeSlot TEXT NOT NULL,
          subject TEXT NOT NULL,
          faculty TEXT NOT NULL
        )
      ''');
      
      // Create AttendanceLog table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS AttendanceLog (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          lectureId INTEGER NOT NULL,
          deptId INTEGER NOT NULL,
          absentees TEXT,
          FOREIGN KEY (lectureId) REFERENCES Lecture (id) ON DELETE CASCADE,
          FOREIGN KEY (deptId) REFERENCES Department (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  // --- DATABASE CREATION (For new installs) ---
  Future _createDB(Database db, int version) async {
    // 1. Department Table
    await db.execute('''
      CREATE TABLE Department (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    // 2. Student Table
    await db.execute('''
      CREATE TABLE Student (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rollNumber TEXT NOT NULL,
        name TEXT NOT NULL,
        deptId INTEGER NOT NULL,
        FOREIGN KEY (deptId) REFERENCES Department (id) ON DELETE CASCADE,
        UNIQUE(rollNumber, deptId)
      )
    ''');

    // 3. Lecture Table (CHANGED NAME FROM 'TimeTable' TO 'Lecture')
    await db.execute('''
      CREATE TABLE Lecture (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day TEXT NOT NULL,
        timeSlot TEXT NOT NULL,
        subject TEXT NOT NULL,
        faculty TEXT NOT NULL
      )
    ''');

    // 4. Attendance Log Table
    await db.execute('''
      CREATE TABLE AttendanceLog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        lectureId INTEGER NOT NULL,
        deptId INTEGER NOT NULL,
        absentees TEXT,
        FOREIGN KEY (lectureId) REFERENCES Lecture (id) ON DELETE CASCADE,
        FOREIGN KEY (deptId) REFERENCES Department (id) ON DELETE CASCADE
      )
    ''');
  }

  // --- ADD THESE METHODS TO database_helper.dart ---

  // Update an existing department
  Future<int> updateDepartment(Department department) async {
    final db = await instance.database;
    return await db.update(
      'Department',
      department.toMap(),
      where: 'id = ?',
      whereArgs: [department.id],
    );
  }

  // Delete a department (and optionally cascading students)
  Future<int> deleteDepartment(int id) async {
    final db = await instance.database;
    
    // Optional: Delete students in this department first to keep data clean
    await db.delete(
      'Student',
      where: 'deptId = ?',
      whereArgs: [id],
    );

    return await db.delete(
      'Department',
      where: 'id = ?',
      whereArgs: [id],
    );
  }


  // --- LOGGING METHODS ---

  // 1. Create a Log Entry
  Future<int> createAttendanceLog(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('AttendanceLog', row);
  }

  // 2. Fetch Logs
  Future<List<Map<String, dynamic>>> getAttendanceLogs({int? lectureId, String? date}) async {
    final db = await instance.database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (lectureId != null) {
      whereClause += 'L.lectureId = ?';
      whereArgs.add(lectureId);
    }
    if (date != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'L.date = ?';
      whereArgs.add(date);
    }

    String finalQuery = '''
      SELECT 
        L.id, 
        L.date, 
        L.absentees,
        Lect.subject, 
        Lect.faculty, 
        Lect.timeSlot,
        D.name as deptName
      FROM AttendanceLog L
      INNER JOIN Lecture Lect ON L.lectureId = Lect.id
      INNER JOIN Department D ON L.deptId = D.id
      ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
      ORDER BY L.date DESC, Lect.timeSlot ASC
    ''';

    return await db.rawQuery(finalQuery, whereArgs);
  }

  // 3. Get distinct subjects
  Future<List<Map<String, dynamic>>> getDistinctSubjects() async {
    final db = await instance.database;
    // Now this works because the table 'Lecture' actually exists
    return await db.rawQuery('SELECT DISTINCT id, subject FROM Lecture');
  }

  // --- Lecture CRUD Operations (UPDATED TO USE 'Lecture' TABLE) ---

  Future<int> createLecture(Map<String, dynamic> row) async {
    final db = await instance.database;
    // Changed 'TimeTable' to 'Lecture'
    return await db.insert('Lecture', row); 
  }

  Future<List<Map<String, dynamic>>> getLecturesByDay(String day) async {
    final db = await instance.database;
    return await db.query(
      'Lecture', // Changed 'TimeTable' to 'Lecture'
      where: 'day = ?',
      whereArgs: [day],
      orderBy: 'id ASC', 
    );
  }

  Future<int> deleteLecture(int id) async {
    final db = await instance.database;
    // Changed 'TimeTable' to 'Lecture'
    return await db.delete('Lecture', where: 'id = ?', whereArgs: [id]);
  }

  // --- Department & Student CRUD Operations (Unchanged) ---

  Future<int> createDepartment(Department department) async {
    final db = await instance.database;
    return await db.insert('Department', department.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> createStudent(Student student) async {
    final db = await instance.database;
    return await db.insert('Student', student.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> readAllStudentsWithDeptName() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT S.id, S.rollNumber, S.name, S.deptId, D.name AS departmentName
      FROM Student S
      INNER JOIN Department D ON S.deptId = D.id
      ORDER BY D.name, S.rollNumber ASC
    ''');
  }

  Future<int> updateStudent(Student student) async {
    final db = await instance.database;
    return await db.update('Student', student.toMap(), where: 'id = ?', whereArgs: [student.id]);
  }

  Future<int> deleteStudent(int id) async {
    final db = await instance.database;
    return await db.delete('Student', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllData() async {
    final db = await instance.database;
    int studentsDeleted = await db.delete('Student');
    int departmentsDeleted = await db.delete('Department');
    return studentsDeleted + departmentsDeleted;
  }

  Future<List<Department>> readAllDepartments() async {
    final db = await instance.database;
    final result = await db.query('Department');
    return result.map((json) => Department.fromMap(json)).toList();
  }

  Future<List<Student>> readStudentsByDept(int deptId) async {
    final db = await instance.database;
    final result = await db.query('Student', where: 'deptId = ?', whereArgs: [deptId], orderBy: 'rollNumber ASC');
    return result.map((json) => Student.fromMap(json)).toList();
  }

  // ... inside DatabaseHelper class ...
// ... inside DatabaseHelper class ...

  // --- BACKUP & RESTORE ---

  // Option A: Share Database (WhatsApp, Drive, Email)
  Future<void> shareDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'attendance_app.db');
    final file = File(path);

    if (await file.exists()) {
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Attendance Backup ${DateTime.now()}',
      );
    }
  }

  // Option B: Save Database Locally (Folder Picker)
  Future<String?> saveDatabaseLocally() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'attendance_app.db');
    final file = File(path);

    if (await file.exists()) {
      try {
        // Pick a folder
        String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

        if (selectedDirectory != null) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'attendance_backup_$timestamp.db';
          final newPath = join(selectedDirectory, fileName);

          await file.copy(newPath);
          return newPath; // Return path on success
        }
      } catch (e) {
        print("Save Error: $e");
        return null;
      }
    }
    return null; // User canceled or file missing
  }

  // Import Database (Restore) - SAME AS BEFORE
  Future<bool> importDatabase() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        File sourceFile = File(result.files.single.path!);
        final dbPath = await getDatabasesPath();
        final path = join(dbPath, 'attendance_app.db');

        if (_database != null && _database!.isOpen) {
          await _database!.close();
          _database = null;
        }

        await sourceFile.copy(path);
        _database = await _initDB('attendance_app.db');
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // --- CUSTOM REPORT QUERY ---  

  Future<List<Map<String, dynamic>>> getCustomReportLogs(String startDate, String endDate, String? subject) async {
    final db = await database;
    
    // Base query joining Log, Lecture, and Department
    String query = '''
      SELECT 
        Log.date, 
        Log.absentees, 
        Lecture.subject, 
        Lecture.faculty, 
        Lecture.timeSlot,
        Department.name as deptName 
      FROM AttendanceLog as Log
      JOIN Lecture ON Log.lectureId = Lecture.id
      JOIN Department ON Log.deptId = Department.id
      WHERE Log.date BETWEEN ? AND ?
    ''';

    List<dynamic> args = [startDate, endDate];

    if (subject != null && subject != 'All') {
      query += ' AND Lecture.subject = ?';
      args.add(subject);
    }

    query += ' ORDER BY Log.date DESC'; // Newest first

    return await db.rawQuery(query, args);
  }

  // Helper to get unique subjects for the dropdown
  Future<List<String>> getAllSubjects() async {
    final db = await database;
    final result = await db.rawQuery('SELECT DISTINCT subject FROM Lecture');
    return result.map((row) => row['subject'] as String).toList();
  }

  //handle a list of specific dates 
  // Inside DatabaseHelper class

  Future<List<Map<String, dynamic>>> getLogsForSpecificDates(List<String> dates, String? subject) async {
    final db = await database;

    // Create a string of placeholders like "?, ?, ?" based on how many dates are selected
    String placeholders = List.filled(dates.length, '?').join(',');

    String query = '''
      SELECT 
        Log.date, 
        Log.absentees, 
        Lecture.subject, 
        Lecture.faculty, 
        Lecture.timeSlot,
        Department.name as deptName 
      FROM AttendanceLog as Log
      JOIN Lecture ON Log.lectureId = Lecture.id
      JOIN Department ON Log.deptId = Department.id
      WHERE Log.date IN ($placeholders)
    ''';

    List<dynamic> args = [...dates];

    if (subject != null && subject != 'All') {
      query += ' AND Lecture.subject = ?';
      args.add(subject);
    }

    query += ' ORDER BY Log.date DESC';

    return await db.rawQuery(query, args);
  }

  


}