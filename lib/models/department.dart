class Department {
  final int? id;
  final String name;

  Department({this.id, required this.name});

  // Convert a Department object into a Map for SQLite insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  // Convert a Map from SQLite into a Department object
  factory Department.fromMap(Map<String, dynamic> map) {
    return Department(
      id: map['id'] as int?,
      name: map['name'] as String,
    );
  }

  @override
  String toString() {
    return 'Department(id: $id, name: $name)';
  }
}