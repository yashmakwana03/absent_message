import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/department.dart';
import '../models/student.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Getter to provide the database instance, initializing it if null (Singleton Pattern)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attendance_app.db');
    return _database!;
  }

  // Initialize the database file and create tables
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // --- DATABASE CREATION: Creates Department and Student tables ---
Future _createDB(Database db, int version) async {
    // 1. Department Table (No change)
    await db.execute('''
      CREATE TABLE Department (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    // 2. Student Table (UPDATED)
    await db.execute('''
      CREATE TABLE Student (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rollNumber TEXT NOT NULL,  -- Removed 'UNIQUE' from here
        name TEXT NOT NULL,
        deptId INTEGER NOT NULL,
        FOREIGN KEY (deptId) REFERENCES Department (id) 
          ON DELETE CASCADE,
        UNIQUE(rollNumber, deptId) -- NEW: Unique combination of Roll No + Dept
      )
    ''');

    // 3. TimeTable Table (No change)
    await db.execute('''
      CREATE TABLE TimeTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day TEXT NOT NULL,
        timeSlot TEXT NOT NULL,
        subject TEXT NOT NULL,
        faculty TEXT NOT NULL
      )
    ''');
  }

  // --- TimeTable CRUD Operations ---

  Future<int> createLecture(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('TimeTable', row);
  }

  Future<List<Map<String, dynamic>>> getLecturesByDay(String day) async {
    final db = await instance.database;
    return await db.query(
      'TimeTable',
      where: 'day = ?',
      whereArgs: [day],
      orderBy: 'timeSlot ASC', // Sort by time
    );
  }

  Future<int> deleteLecture(int id) async {
    final db = await instance.database;
    return await db.delete('TimeTable', where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD Operations ---

  // INSERT Department
  Future<int> createDepartment(Department department) async {
    final db = await instance.database;
    return await db.insert(
      'Department',
      department.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // INSERT Student
  Future<int> createStudent(Student student) async {
    final db = await instance.database;
    return await db.insert(
      'Student',
      student.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  // QUERY ALL Students with Department Name
  Future<List<Map<String, dynamic>>> readAllStudentsWithDeptName() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        S.id, 
        S.rollNumber, 
        S.name, 
        S.deptId,  -- <--- MAKE SURE THIS IS ADDED
        D.name AS departmentName
      FROM 
        Student S
      INNER JOIN 
        Department D 
      ON 
        S.deptId = D.id
      ORDER BY 
        D.name, S.rollNumber ASC
    ''');
  }

  Future<int> updateStudent(Student student) async {
    final db = await instance.database;
    return await db.update(
      'Student',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  // DELETE Student
  Future<int> deleteStudent(int id) async {
    final db = await instance.database;
    return await db.delete(
      'Student',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // DELETE ALL Student and Department Data
  Future<int> deleteAllData() async {
    final db = await instance.database;
    // Delete all rows from Student table
    int studentsDeleted = await db.delete('Student');
    // Delete all rows from Department table
    int departmentsDeleted = await db.delete('Department');
    return studentsDeleted + departmentsDeleted;
  }

  // QUERY ALL Departments
  Future<List<Department>> readAllDepartments() async {
    final db = await instance.database;
    final result = await db.query('Department');
    
    // Convert List<Map> to List<Department>
    return result.map((json) => Department.fromMap(json)).toList();
  }

  

  // QUERY Students by Department ID
  Future<List<Student>> readStudentsByDept(int deptId) async {
    final db = await instance.database;
    final result = await db.query(
      'Student',
      where: 'deptId = ?',
      whereArgs: [deptId],
      orderBy: 'rollNumber ASC',
    );
    
    // Convert List<Map> to List<Student>
    return result.map((json) => Student.fromMap(json)).toList();
  }
}