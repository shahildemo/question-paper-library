import 'semester_model.dart';

class Year {
  final String id;
  final String name;
  final String facultyId;
  final List<Semester> semesters;

  Year({
    required this.id,
    required this.name,
    required this.facultyId,
    required this.semesters,
  });

  factory Year.fromJson(Map<String, dynamic> json) {
    return Year(
      id: json['id'] as String,
      name: json['name'] as String,
      facultyId: json['facultyId'] as String,
      semesters: (json['semesters'] as List<dynamic>)
          .map((semester) => Semester.fromJson(semester as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'facultyId': facultyId,
      'semesters': semesters.map((semester) => semester.toJson()).toList(),
    };
  }
}
