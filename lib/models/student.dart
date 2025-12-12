class Student {
  final int? id;
  final String rollNumber;
  final String name;
  final int deptId; // Foreign Key to Department table

  Student({
    this.id,
    required this.rollNumber,
    required this.name,
    required this.deptId,
  });

  // Convert a Student object into a Map for SQLite insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rollNumber': rollNumber,
      'name': name,
      'deptId': deptId,
    };
  }

  // Convert a Map from SQLite into a Student object
  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      rollNumber: map['rollNumber'] as String,
      name: map['name'] as String,
      deptId: map['deptId'] as int,
    );
  }
}