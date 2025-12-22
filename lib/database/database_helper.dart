import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/department.dart';
import '../models/student.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attendance_manager_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // Version 2 for schema updates
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Departments
    await db.execute('''
      CREATE TABLE Department (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    // 2. Students
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

    // 3. Lectures (Time Table)
    await db.execute('''
      CREATE TABLE Lecture (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day TEXT NOT NULL,
        timeSlot TEXT NOT NULL,
        subject TEXT NOT NULL,
        faculty TEXT NOT NULL,
        deptId INTEGER NOT NULL,
        isElective INTEGER DEFAULT 0,
        sortOrder INTEGER DEFAULT 1, 
        FOREIGN KEY (deptId) REFERENCES Department (id) ON DELETE CASCADE
      )
    ''');

    // 4. Attendance Logs
    await db.execute('''
      CREATE TABLE AttendanceLog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        lectureId INTEGER NOT NULL,
        deptId INTEGER NOT NULL,
        absentees TEXT NOT NULL,
        FOREIGN KEY (lectureId) REFERENCES Lecture (id) ON DELETE CASCADE
      )
    ''');

    // 5. Subject Enrollment (For Electives)
    await db.execute('''
      CREATE TABLE SubjectEnrollment (
        lectureId INTEGER NOT NULL,
        studentId INTEGER NOT NULL,
        PRIMARY KEY (lectureId, studentId),
        FOREIGN KEY (lectureId) REFERENCES Lecture (id) ON DELETE CASCADE,
        FOREIGN KEY (studentId) REFERENCES Student (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE Lecture ADD COLUMN isElective INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE Lecture ADD COLUMN sortOrder INTEGER DEFAULT 1',
      );

      await db.execute('''
        CREATE TABLE SubjectEnrollment (
          lectureId INTEGER NOT NULL,
          studentId INTEGER NOT NULL,
          PRIMARY KEY (lectureId, studentId),
          FOREIGN KEY (lectureId) REFERENCES Lecture (id) ON DELETE CASCADE,
          FOREIGN KEY (studentId) REFERENCES Student (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  // --- DEPARTMENT METHODS ---
  Future<int> createDepartment(Department dept) async {
    final db = await database;
    return await db.insert('Department', dept.toMap());
  }

  Future<List<Department>> readAllDepartments() async {
    final db = await database;
    final result = await db.query('Department');
    return result.map((json) => Department.fromMap(json)).toList();
  }

  Future<int> updateDepartment(Department dept) async {
    final db = await database;
    return await db.update(
      'Department',
      dept.toMap(),
      where: 'id = ?',
      whereArgs: [dept.id],
    );
  }

  Future<int> deleteDepartment(int id) async {
    final db = await database;
    return await db.delete('Department', where: 'id = ?', whereArgs: [id]);
  }

  // --- STUDENT METHODS ---
  Future<int> createStudent(Student student) async {
    final db = await database;
    return await db.insert('Student', student.toMap());
  }

  Future<List<Student>> readStudentsByDept(int deptId) async {
    final db = await database;
    final result = await db.query(
      'Student',
      where: 'deptId = ?',
      whereArgs: [deptId],
      orderBy: 'rollNumber ASC',
    );
    return result.map((json) => Student.fromMap(json)).toList();
  }

  Future<List<Map<String, dynamic>>> readAllStudentsWithDeptName() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT s.*, d.name as departmentName 
      FROM Student s
      JOIN Department d ON s.deptId = d.id
      ORDER BY s.deptId, s.rollNumber
    ''');
  }

  Future<int> updateStudent(Student student) async {
    final db = await database;
    return await db.update(
      'Student',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  Future<int> deleteStudent(int id) async {
    final db = await database;
    return await db.delete('Student', where: 'id = ?', whereArgs: [id]);
  }

  // --- LECTURE & TIMETABLE METHODS ---
  Future<int> createLecture(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('Lecture', data);
  }

  Future<List<Map<String, dynamic>>> getLecturesByDay(String day) async {
    final db = await database;
    // Sort by sortOrder so lectures appear in correct sequence
    return await db.query(
      'Lecture',
      where: 'day = ?',
      whereArgs: [day],
      orderBy: 'sortOrder ASC',
    );
  }

  Future<int> deleteLecture(int id) async {
    final db = await database;
    return await db.delete('Lecture', where: 'id = ?', whereArgs: [id]);
  }

  // --- ENROLLMENT METHODS (New for V3) ---
  Future<List<Map<String, dynamic>>> getElectiveLectures() async {
    final db = await database;
    return await db.query('Lecture', where: 'isElective = 1');
  }

  Future<List<int>> getEnrolledStudentIds(int lectureId) async {
    final db = await database;
    final result = await db.query(
      'SubjectEnrollment',
      columns: ['studentId'],
      where: 'lectureId = ?',
      whereArgs: [lectureId],
    );
    return result.map((row) => row['studentId'] as int).toList();
  }

  Future<List<Map<String, dynamic>>> getStudentsForSubject(
    int lectureId,
    int deptId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT s.* FROM Student s
      JOIN SubjectEnrollment se ON s.id = se.studentId
      WHERE se.lectureId = ? AND s.deptId = ?
      ORDER BY s.rollNumber
    ''',
      [lectureId, deptId],
    );
  }

  Future<void> updateBatchEnrollment(
    int lectureId,
    List<int> toAdd,
    List<int> toRemove,
  ) async {
    final db = await database;
    Batch batch = db.batch();

    for (int sid in toAdd) {
      batch.insert('SubjectEnrollment', {
        'lectureId': lectureId,
        'studentId': sid,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (int sid in toRemove) {
      batch.delete(
        'SubjectEnrollment',
        where: 'lectureId = ? AND studentId = ?',
        whereArgs: [lectureId, sid],
      );
    }
    await batch.commit(noResult: true);
  }

  // --- ATTENDANCE LOG METHODS ---
  Future<int> createAttendanceLog(Map<String, dynamic> data) async {
    final db = await database;
    // Check if log exists for this specific lecture AND department
    final existing = await db.query(
      'AttendanceLog',
      where: 'date = ? AND lectureId = ? AND deptId = ?',
      whereArgs: [data['date'], data['lectureId'], data['deptId']],
    );

    if (existing.isNotEmpty) {
      return await db.update(
        'AttendanceLog',
        data,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      return await db.insert('AttendanceLog', data);
    }
  }

  Future<List<Map<String, dynamic>>> getAttendanceLogs({String? date}) async {
    final db = await database;
    String query = '''
      SELECT l.*, lec.subject, lec.timeSlot, d.name as deptName
      FROM AttendanceLog l
      JOIN Lecture lec ON l.lectureId = lec.id
      JOIN Department d ON l.deptId = d.id
    ''';

    if (date != null) {
      query += " WHERE l.date = '$date'";
    }
    query += " ORDER BY l.date DESC, lec.timeSlot ASC";

    return await db.rawQuery(query);
  }

  Future<List<Map<String, dynamic>>> getLogsForSpecificDates(
    List<String> dates,
    String subject,
  ) async {
    final db = await database;
    String dateList = dates.map((d) => "'$d'").join(',');

    String sql =
        '''
      SELECT log.date, log.absentees, lec.subject, dept.name as deptName 
      FROM AttendanceLog log
      JOIN Lecture lec ON log.lectureId = lec.id
      JOIN Department dept ON log.deptId = dept.id
      WHERE log.date IN ($dateList)
    ''';

    if (subject != 'All') {
      sql += " AND lec.subject = '$subject'";
    }

    sql += " ORDER BY log.date ASC";
    return await db.rawQuery(sql);
  }

  Future<List<String>> getAllSubjects() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT subject FROM Lecture ORDER BY subject',
    );
    return result.map((e) => e['subject'] as String).toList();
  }

  // --- BACKUP & RESTORE ---
  Future<void> shareDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'attendance_manager_v2.db');
    await Share.shareXFiles([XFile(path)], text: 'Attendance Backup');
  }

  Future<String?> saveDatabaseLocally() async {
    try {
      final dbPath = await getDatabasesPath();
      final sourcePath = join(dbPath, 'attendance_manager_v2.db');

      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) return null;

      final destinationPath = join(
        directory.path,
        'Attendance_Backup_${DateTime.now().millisecondsSinceEpoch}.db',
      );
      await File(sourcePath).copy(destinationPath);
      return destinationPath;
    } catch (e) {
      return null;
    }
  }

  Future<bool> importDatabase() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        File file = File(result.files.single.path!);
        final dbPath = await getDatabasesPath();
        final path = join(dbPath, 'attendance_manager_v2.db');

        await _database?.close();
        await file.copy(path);
        _database = await _initDB('attendance_manager_v2.db');
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('AttendanceLog');
    await db.delete('SubjectEnrollment');
    await db.delete('Lecture');
    await db.delete('Student');
    await db.delete('Department');
  }
}
